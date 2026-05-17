/// API configuration — mirrors iOS APIConfig / src/api/config.js.
///
/// Must match the IP where `http://<ip>:8000/docs` works in your phone browser.
/// Physical device: Mac LAN IP + `/api/v1`. Emulator: `http://10.0.2.2:8000/api/v1`.
class ApiConfig {
  static const defaultBaseUrl = 'http://192.168.1.18:8000/api/v1';
  static const defaultLat = 19.0760;
  static const defaultLng = 72.8777;

  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    return defaultBaseUrl;
  }

  static String wsUrl(String path, Map<String, String> query) {
    final base = baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
    final scheme = baseUrl.startsWith('https') ? 'wss' : 'ws';
    final hostPath = baseUrl.replaceFirst(RegExp(r'^https?://'), '').replaceAll(RegExp(r'/api/v1/?$'), '');
    final qs = query.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
    return '$scheme://$hostPath/api/v1$path${qs.isEmpty ? '' : '?$qs'}';
  }
}
