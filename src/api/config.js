/**
 * API configuration — mirrors iOS APIConfig.
 * Change BASE_URL to your machine's LAN IP for device testing.
 */
export const APIConfig = {
  // baseURL: 'http://192.168.1.38:8000/api/v1',
  baseURL: 'http://192.168.1.26:8000/api/v1',
  defaultLat: 19.0760,
  defaultLng: 72.8777,
};

export function wsURL(path, query = {}) {
  const base = APIConfig.baseURL.replace(/\/api\/v1\/?$/, '');
  const scheme = APIConfig.baseURL.startsWith('https') ? 'wss' : 'ws';
  const hostPath = APIConfig.baseURL.replace(/^https?:\/\//, '').replace(/\/api\/v1\/?$/, '');
  const params = new URLSearchParams(query).toString();
  const qs = params ? `?${params}` : '';
  return `${scheme}://${hostPath}/api/v1${path}${qs}`;
}
