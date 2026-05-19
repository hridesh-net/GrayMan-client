import * as FileSystem from 'expo-file-system/legacy';
import { workerService } from '../api/workerService';

const PART_SIZE = 5 * 1024 * 1024; // 5 MB — matches iOS ReelUploader
const MAX_PARALLEL = 3;

/** MIME for camera capture (Android → mp4, iOS Expo → often .mov). */
function contentTypeForUri(uri) {
  const path = uri.split('?')[0].toLowerCase();
  if (path.endsWith('.mov')) return 'video/quicktime';
  return 'video/mp4';
}

/**
 * Multipart reel upload — mirrors iOS ReelUploader (disk-backed parts, not whole-file RAM).
 * @param {string} fileUri - local video file URI (front-camera capture)
 * @param {string|null} transcript
 * @param {(pct: number) => void} onProgress
 */
export async function uploadReel(fileUri, transcript = null, onProgress = () => {}) {
  const info = await FileSystem.getInfoAsync(fileUri);
  if (!info.exists) throw new Error('Recorded reel file not found');

  const fileSize = info.size ?? 0;
  if (fileSize <= 0) throw new Error('Recorded reel file is empty');

  const contentType = contentTypeForUri(fileUri);
  const partCount = Math.max(1, Math.ceil(fileSize / PART_SIZE));

  const init = await workerService.initMultipartUpload(partCount, contentType);
  const { key, upload_id: uploadId, part_urls: partUrls } = init;

  try {
    const completed = [];
    let done = 0;

    for (let batch = 0; batch < partCount; batch += MAX_PARALLEL) {
      const tasks = [];
      for (let i = batch; i < Math.min(batch + MAX_PARALLEL, partCount); i++) {
        const partNumber = i + 1;
        const start = i * PART_SIZE;
        const length = Math.min(PART_SIZE, fileSize - start);
        const presigned = partUrls.find(p => p.part_number === partNumber) || partUrls[i];
        tasks.push(
          uploadPartFromDisk(fileUri, start, length, presigned.url, contentType).then(etag => {
            completed.push({ part_number: partNumber, etag });
            done += 1;
            onProgress(Math.round((done / partCount) * 100));
          }),
        );
      }
      await Promise.all(tasks);
    }

    completed.sort((a, b) => a.part_number - b.part_number);
    return await workerService.completeMultipartUpload(key, uploadId, completed, transcript);
  } catch (e) {
    await workerService.abortMultipartUpload(key, uploadId).catch(() => {});
    throw e;
  }
}

/**
 * Read one byte range from disk, stage to a temp file, PUT via native uploadAsync
 * (avoids loading the entire reel into JS heap).
 */
async function uploadPartFromDisk(fileUri, position, length, url, contentType) {
  if (!FileSystem.cacheDirectory) {
    throw new Error('No cache directory available for upload staging');
  }

  const base64 = await FileSystem.readAsStringAsync(fileUri, {
    encoding: FileSystem.EncodingType.Base64,
    position,
    length,
  });

  const partUri = `${FileSystem.cacheDirectory}reel-part-${position}-${length}.bin`;
  await FileSystem.writeAsStringAsync(partUri, base64, {
    encoding: FileSystem.EncodingType.Base64,
  });

  try {
    const res = await FileSystem.uploadAsync(url, partUri, {
      httpMethod: 'PUT',
      uploadType: FileSystem.FileSystemUploadType.BINARY_CONTENT,
      headers: { 'Content-Type': contentType },
    });
    if (res.status < 200 || res.status >= 300) {
      throw new Error(`S3 part upload failed: ${res.status}`);
    }
    const headers = res.headers || {};
    const etag = headers.ETag || headers.etag || headers['Etag'];
    if (!etag) throw new Error('S3 did not return ETag header');
    return etag;
  } finally {
    await FileSystem.deleteAsync(partUri, { idempotent: true }).catch(() => {});
  }
}
