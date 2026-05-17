import { request, requestVoid, uploadToS3 } from './apiClient';
import { workerFromDTO } from '../models/worker';
import { locationService } from '../services/locationService';

let hasSyncedLocationThisSession = false;

async function coords() {
  return locationService.current();
}

export const workerService = {
  async syncSelfLocationIfNeeded() {
    if (hasSyncedLocationThisSession) return;
    const place = await locationService.currentPlaceStrict();
    if (!place) return;
    try {
      await workerService.updateSelf({
        city: place.city || place.shortLabel,
        lat: place.lat,
        lng: place.lng,
      });
      hasSyncedLocationThisSession = true;
    } catch { /* silent */ }
  },

  async fetchExplore({ trade, radiusKm = 5, page = 1, limit = 30 } = {}) {
    const { lat, lng } = await coords();
    const query = { lat, lng, radius_km: radiusKm, page, limit };
    if (trade && trade !== 'All') query.trade = trade;
    const dtos = await request('GET', '/explore', { query, authenticated: false });
    return (dtos || []).map(d => workerFromDTO(d, lat, lng));
  },

  async fetchSelf() {
    const { lat, lng } = await coords();
    const dto = await request('GET', '/workers/me');
    return workerFromDTO(dto, lat, lng);
  },

  async fetchWorker(id) {
    const { lat, lng } = await coords();
    const dto = await request('GET', `/workers/${id}`, { authenticated: false });
    return workerFromDTO(dto, lat, lng);
  },

  async updateSelf(fields) {
    const { lat, lng } = await coords();
    const dto = await request('PUT', '/workers/me', { body: fields });
    return workerFromDTO(dto, lat, lng);
  },

  // Auth
  sendOTP(phone) {
    return request('POST', '/auth/otp/send', { body: { phone }, authenticated: false });
  },

  verifyOTP(phone, code) {
    return request('POST', '/auth/otp/verify', {
      body: { phone, code },
      authenticated: false,
    });
  },

  // Vouches
  giveVouch(toWorkerId, skillIndices, voiceNoteUrl = null) {
    return request('POST', '/vouches', {
      body: {
        to_worker_id: toWorkerId,
        skill_indices: skillIndices,
        voice_note_url: voiceNoteUrl,
      },
    });
  },

  fetchReceivedVouches(workerId) {
    return request('GET', `/vouches/received/${workerId}`, { authenticated: false });
  },

  // Interactions
  like(workerId) {
    return requestVoid('POST', `/likes/${workerId}`);
  },
  unlike(workerId) {
    return requestVoid('DELETE', `/likes/${workerId}`);
  },
  save(workerId) {
    return requestVoid('POST', `/saves/${workerId}`);
  },
  unsave(workerId) {
    return requestVoid('DELETE', `/saves/${workerId}`);
  },
  fetchInteractionCounts(workerId) {
    return request('GET', `/${workerId}/counts`, { authenticated: false });
  },
  fetchMyActionState(workerId) {
    return request('GET', `/${workerId}/state`);
  },
  sendMessage(toWorkerId, body) {
    return request('POST', '/messages', { body: { to_worker_id: toWorkerId, body } });
  },

  // Reels
  fetchAnalysisStatus() {
    return request('GET', '/reels/analysis');
  },
  initMultipartUpload(partCount, contentType = 'video/mp4') {
    return request('POST', '/reels/upload/init', {
      body: { part_count: partCount, content_type: contentType },
    });
  },
  completeMultipartUpload(key, uploadId, parts, transcript = null) {
    const body = { key, upload_id: uploadId, parts };
    if (transcript?.trim()) body.transcript = transcript.trim();
    return request('POST', '/reels/upload/complete', { body });
  },
  abortMultipartUpload(key, uploadId) {
    return requestVoid('POST', '/reels/upload/abort', {
      body: { key, upload_id: uploadId },
    });
  },

  // Work history
  fetchWorkHistory(workerId) {
    return request('GET', `/workers/${workerId}/history`, { authenticated: false });
  },
  createWorkHistory(entry) {
    return request('POST', '/workers/me/history', { body: entry });
  },
  updateWorkHistory(id, entry) {
    return request('PUT', `/workers/me/history/${id}`, { body: entry });
  },
  deleteWorkHistory(id) {
    return requestVoid('DELETE', `/workers/me/history/${id}`);
  },

  // Showcase
  fetchShowcase(workerId, kind = null) {
    const query = kind ? { kind } : {};
    return request('GET', `/workers/${workerId}/showcase`, { query, authenticated: false });
  },
  createShowcaseItem(body) {
    return request('POST', '/workers/me/showcase', { body });
  },
  initShowcaseMultipart(kind, contentType, partCount) {
    return request('POST', '/showcase/upload/init', {
      body: { kind, content_type: contentType, part_count: partCount },
    });
  },
  completeShowcaseMultipart(key, uploadId, parts) {
    return requestVoid('POST', '/showcase/upload/complete', {
      body: { key, upload_id: uploadId, parts },
    });
  },

  // Voice guide
  voiceGuideToken(lang) {
    return request('POST', '/voice-guide/token', { body: { lang } });
  },
  voiceGuideTranslate(text, lang) {
    return request('POST', '/voice-guide/translate', { body: { text, lang } });
  },

  // Hires
  createHire(workerId, message = null) {
    return request('POST', '/hires', { body: { worker_id: workerId, message } });
  },
  fetchHires(direction = 'both') {
    return request('GET', '/hires', { query: { direction } });
  },
  transitionHire(id, status) {
    return request('POST', `/hires/${id}/${status}`);
  },
  async hasCompletedHire(workerId) {
    try {
      const hires = await workerService.fetchHires('outgoing');
      return (hires || []).some(h => h.worker_id === workerId && h.status === 'completed');
    } catch {
      return false;
    }
  },

  // Notifications
  fetchNotifications(onlyUndecided = false, limit = 50) {
    const query = { limit };
    if (onlyUndecided) query.only_undecided = 'true';
    return request('GET', '/notifications', { query });
  },
  markNotificationRead(id) {
    return request('POST', `/notifications/${id}/read`);
  },
  acceptNotification(id) {
    return request('POST', `/notifications/${id}/accept`);
  },
  rejectNotification(id) {
    return request('POST', `/notifications/${id}/reject`);
  },

  // Interview results
  fetchInterviewResults(page = 1, pageSize = 20) {
    return request('GET', '/interview/results', { query: { page, page_size: pageSize } });
  },

  uploadToS3,
};
