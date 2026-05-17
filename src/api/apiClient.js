import { APIConfig } from './config';
import { tokenStore } from './tokenStore';

export class APIError extends Error {
  constructor(type, message, status = 0, body = '') {
    super(message);
    this.name = 'APIError';
    this.type = type;
    this.status = status;
    this.body = body;
  }
}

function parseDate(str) {
  if (!str) return null;
  const d = new Date(str);
  return Number.isNaN(d.getTime()) ? null : d;
}

async function parseJSON(res) {
  const text = await res.text();
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    throw new APIError('decoding', `Invalid JSON: ${text.slice(0, 200)}`);
  }
}

/**
 * @template T
 * @param {'GET'|'POST'|'PUT'|'DELETE'} method
 * @param {string} path - e.g. "/workers/me"
 * @param {{ query?: Record<string,string|number>, body?: object, authenticated?: boolean }} opts
 * @returns {Promise<T>}
 */
export async function request(method, path, opts = {}) {
  const { query = {}, body = null, authenticated = true } = opts;
  const url = new URL(`${APIConfig.baseURL}${path}`);
  Object.entries(query).forEach(([k, v]) => {
    if (v !== undefined && v !== null) url.searchParams.set(k, String(v));
  });

  const headers = { Accept: 'application/json' };
  if (authenticated) {
    const token = tokenStore.token;
    if (!token) throw new APIError('noToken', 'You must sign in first.');
    headers.Authorization = `Bearer ${token}`;
  }
  if (body) headers['Content-Type'] = 'application/json';

  const init = { method, headers };
  if (body) init.body = JSON.stringify(body);

  let lastErr;
  const attempts = method === 'GET' ? 2 : 1;
  for (let i = 0; i < attempts; i++) {
    try {
      const res = await fetch(url.toString(), init);
      if (res.status === 401) {
        await tokenStore.clear();
        throw new APIError('unauthorized', 'Your session has expired. Please sign in again.');
      }
      if (!res.ok) {
        const errBody = await res.text();
        throw new APIError('server', `Server returned ${res.status}`, res.status, errBody);
      }
      if (res.status === 204) return null;
      return await parseJSON(res);
    } catch (e) {
      if (e instanceof APIError) throw e;
      lastErr = e;
      if (i < attempts - 1) {
        await new Promise(r => setTimeout(r, 600));
        continue;
      }
    }
  }
  throw new APIError('transport', lastErr?.message || 'Network error');
}

export async function requestVoid(method, path, opts = {}) {
  await request(method, path, opts);
}

/** PUT bytes to S3 presigned URL */
export async function uploadToS3(presignedUrl, data, contentType) {
  const res = await fetch(presignedUrl, {
    method: 'PUT',
    headers: { 'Content-Type': contentType },
    body: data,
  });
  if (!res.ok) {
    throw new APIError('server', `S3 upload failed: ${res.status}`, res.status);
  }
}

export { parseDate };
