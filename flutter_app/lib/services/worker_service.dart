import '../core/location/location_service.dart';
import '../core/networking/api_client.dart';
import '../core/networking/token_store.dart';
import '../models/worker.dart';
import '../models/worker_dto.dart';

/// Mirrors WorkerService.swift.
class WorkerService {
  WorkerService._();
  static final WorkerService instance = WorkerService._();

  bool _hasSyncedLocationThisSession = false;

  Future<void> syncSelfLocationIfNeeded() async {
    if (_hasSyncedLocationThisSession) return;
    if (TokenStore.instance.token == null) return;
    final place = await LocationService.instance.currentPlaceStrict();
    if (place == null) return;
    try {
      await updateSelf(WorkerUpdateRequest(
        city: place.city ?? place.shortLabel,
        lat: place.lat,
        lng: place.lng,
      ));
      _hasSyncedLocationThisSession = true;
    } catch (_) {}
  }

  Future<List<Worker>> fetchExplore({
    String? trade,
    double radiusKm = 5,
    int page = 1,
    int limit = 30,
  }) async {
    final loc = await LocationService.instance.current();
    final query = <String, String>{
      'lat': '${loc.lat}',
      'lng': '${loc.lng}',
      'radius_km': '$radiusKm',
      'page': '$page',
      'limit': '$limit',
      'has_reel': 'true',
    };
    if (trade != null && trade != 'All') query['trade'] = trade;

    final list = await ApiClient.instance.request<List<dynamic>>(
      HttpMethod.get,
      '/explore',
      query: query,
      authenticated: false,
      decode: decodeList,
    );
    return list
        .map((e) => Worker.fromDto(WorkerDto.fromJson(e as Map<String, dynamic>), userLat: loc.lat, userLng: loc.lng))
        .toList();
  }

  Future<Worker> fetchSelf() async {
    final dto = await ApiClient.instance.request<Map<String, dynamic>>(
      HttpMethod.get,
      '/workers/me',
      decode: (j) => j as Map<String, dynamic>,
    );
    return Worker.fromDto(WorkerDto.fromJson(dto), userLat: 0, userLng: 0);
  }

  Future<Worker> fetchWorker(String id) async {
    final fix = LocationService.instance.lastKnown ?? (lat: 0.0, lng: 0.0);
    final dto = await ApiClient.instance.request<Map<String, dynamic>>(
      HttpMethod.get,
      '/workers/$id',
      authenticated: false,
      decode: (j) => j as Map<String, dynamic>,
    );
    return Worker.fromDto(WorkerDto.fromJson(dto), userLat: fix.lat, userLng: fix.lng);
  }

  Future<Worker> updateSelf(WorkerUpdateRequest update) async {
    final dto = await ApiClient.instance.request<Map<String, dynamic>>(
      HttpMethod.put,
      '/workers/me',
      body: update.toJson(),
      decode: (j) => j as Map<String, dynamic>,
    );
    return Worker.fromDto(WorkerDto.fromJson(dto), userLat: 0, userLng: 0);
  }

  Future<void> giveVouch(String toWorkerID, List<int> skillIndices, {String? voiceNoteURL}) async {
    await ApiClient.instance.request<Map<String, dynamic>>(
      HttpMethod.post,
      '/vouches',
      body: VouchCreateRequest(toWorkerID: toWorkerID, skillIndices: skillIndices, voiceNoteURL: voiceNoteURL).toJson(),
      decode: (j) => (j as Map<String, dynamic>?) ?? {},
    );
  }

  Future<void> like(String workerID) => ApiClient.instance.requestVoid(HttpMethod.post, '/likes/$workerID');
  Future<void> unlike(String workerID) => ApiClient.instance.requestVoid(HttpMethod.delete, '/likes/$workerID');
  Future<void> save(String workerID) => ApiClient.instance.requestVoid(HttpMethod.post, '/saves/$workerID');
  Future<void> unsave(String workerID) => ApiClient.instance.requestVoid(HttpMethod.delete, '/saves/$workerID');

  Future<InteractionCountsDto> fetchInteractionCounts(String workerID) async {
    final j = await ApiClient.instance.request<Map<String, dynamic>>(
      HttpMethod.get,
      '/$workerID/counts',
      authenticated: false,
      decode: (json) => json as Map<String, dynamic>,
    );
    return InteractionCountsDto.fromJson(j);
  }

  Future<WorkerActionStateDto> fetchMyActionState(String workerID) async {
    final j = await ApiClient.instance.request<Map<String, dynamic>>(
      HttpMethod.get,
      '/$workerID/state',
      decode: (json) => json as Map<String, dynamic>,
    );
    return WorkerActionStateDto.fromJson(j);
  }

  Future<void> sendMessage(String toWorkerID, String body) async {
    await ApiClient.instance.requestVoid(
      HttpMethod.post,
      '/messages',
      body: {'to_worker_id': toWorkerID, 'body': body},
    );
  }

  Future<List<PostDto>> fetchFeed({int page = 1, int limit = 20}) async {
    final loc = await LocationService.instance.current();
    final list = await ApiClient.instance.request<List<dynamic>>(
      HttpMethod.get,
      '/posts/feed',
      query: {'lat': '${loc.lat}', 'lng': '${loc.lng}', 'page': '$page', 'limit': '$limit'},
      authenticated: false,
      decode: decodeList,
    );
    return list.map((e) => PostDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PostDto> createPost(PostCreateRequest req) async {
    final j = await ApiClient.instance.request<Map<String, dynamic>>(
      HttpMethod.post,
      '/posts',
      body: req.toJson(),
      decode: (json) => json as Map<String, dynamic>,
    );
    return PostDto.fromJson(j);
  }

  Future<NotificationListResponse> fetchNotifications({bool onlyUndecided = false, int limit = 50}) async {
    final query = <String, String>{'limit': '$limit'};
    if (onlyUndecided) query['only_undecided'] = 'true';
    final j = await ApiClient.instance.request<Map<String, dynamic>>(
      HttpMethod.get,
      '/notifications',
      query: query,
      decode: (json) => json as Map<String, dynamic>,
    );
    return NotificationListResponse.fromJson(j);
  }

  Future<void> markNotificationRead(String id) =>
      ApiClient.instance.requestVoid(HttpMethod.post, '/notifications/$id/read');

  Future<void> acceptNotification(String id) =>
      ApiClient.instance.requestVoid(HttpMethod.post, '/notifications/$id/accept');

  Future<void> rejectNotification(String id) =>
      ApiClient.instance.requestVoid(HttpMethod.post, '/notifications/$id/reject');

  Future<List<ShowcaseItemDto>> fetchShowcase(String workerId) async {
    final list = await ApiClient.instance.request<List<dynamic>>(
      HttpMethod.get,
      '/workers/$workerId/showcase',
      authenticated: false,
      decode: decodeList,
    );
    return list.map((e) => ShowcaseItemDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<WorkHistoryDto>> fetchWorkHistory(String workerId) async {
    final list = await ApiClient.instance.request<List<dynamic>>(
      HttpMethod.get,
      '/workers/$workerId/history',
      authenticated: false,
      decode: decodeList,
    );
    return list.map((e) => WorkHistoryDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<MultipartInitResponse> initReelMultipartUpload(int partCount, {String contentType = 'video/mp4'}) async {
    final j = await ApiClient.instance.request<Map<String, dynamic>>(
      HttpMethod.post,
      '/reels/upload/init',
      body: {'part_count': partCount, 'content_type': contentType},
      decode: (json) => json as Map<String, dynamic>,
    );
    return MultipartInitResponse.fromJson(j);
  }

  Future<void> completeReelMultipartUpload({
    required String key,
    required String uploadID,
    required List<Map<String, dynamic>> parts,
    String? transcript,
  }) async {
    final body = <String, dynamic>{
      'key': key,
      'upload_id': uploadID,
      'parts': parts,
    };
    final trimmed = transcript?.trim();
    if (trimmed != null && trimmed.isNotEmpty) body['transcript'] = trimmed;

    await ApiClient.instance.requestVoid(
      HttpMethod.post,
      '/reels/upload/complete',
      body: body,
    );
  }

  Future<void> abortMultipartUpload({required String key, required String uploadID}) async {
    await ApiClient.instance.requestVoid(
      HttpMethod.post,
      '/reels/upload/abort',
      body: {'key': key, 'upload_id': uploadID},
    );
  }
}
