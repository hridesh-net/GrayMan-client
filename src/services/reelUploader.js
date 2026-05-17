import * as FileSystem from 'expo-file-system/legacy';
import { workerService } from '../api/workerService';

const PART_SIZE = 5 * 1024 * 1024; // 5 MB
const MAX_PARALLEL = 3;

/** MIME for camera capture (Android → mp4, iOS Expo → often .mov). */
function contentTypeForUri(uri) {
  const path = uri.split('?')[0].toLowerCase();
  if (path.endsWith('.mov')) return 'video/quicktime';
  return 'video/mp4';
}

/**
 * Multipart reel upload — mirrors iOS ReelUploader.
 * @param {string} fileUri - local video file URI (front-camera capture)
 * @param {string|null} transcript
 * @param {(pct: number) => void} onProgress
 */
export async function uploadReel(fileUri, transcript = null, onProgress = () => {}) {
  const info = await FileSystem.getInfoAsync(fileUri);
  if (!info.exists) throw new Error('Recorded reel file not found');

  const contentType = contentTypeForUri(fileUri);
  const base64 = await FileSystem.readAsStringAsync(fileUri, {
    encoding: FileSystem.EncodingType.Base64,
  });
  const binary = base64ToUint8Array(base64);
  const partCount = Math.max(1, Math.ceil(binary.length / PART_SIZE));

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
        const chunk = binary.slice(start, Math.min(start + PART_SIZE, binary.length));
        const presigned = partUrls.find(p => p.part_number === partNumber) || partUrls[i];
        tasks.push(
          uploadPart(presigned.url, chunk, contentType).then(etag => {
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

function base64ToUint8Array(b64) {
  const raw = atob(b64);
  const arr = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) arr[i] = raw.charCodeAt(i);
  return arr;
}

async function uploadPart(url, chunk, contentType) {
  const res = await fetch(url, {
    method: 'PUT',
    headers: { 'Content-Type': contentType },
    body: chunk,
  });
  if (!res.ok) {
    throw new Error(`S3 part upload failed: ${res.status}`);
  }
  const etag = res.headers.get('ETag') || res.headers.get('etag');
  if (!etag) throw new Error('S3 did not return ETag header');
  return etag;
}
