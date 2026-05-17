class WorkerDto {
  WorkerDto.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        phone = j['phone'] as String? ?? '',
        name = j['name'] as String? ?? '',
        trade = j['trade'] as String? ?? 'Other',
        bio = j['bio'] as String?,
        skillTags = (j['skill_tags'] as List<dynamic>?)?.cast<String>() ?? [],
        verifiedTagIndices = (j['verified_tag_indices'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [],
        city = j['city'] as String?,
        lat = (j['lat'] as num?)?.toDouble(),
        lng = (j['lng'] as num?)?.toDouble(),
        avatarURL = j['avatar_url'] as String?,
        reelURL = j['reel_url'] as String?,
        reelHlsURL = j['reel_hls_url'] as String?,
        reelThumbnailURL = j['reel_thumbnail_url'] as String?,
        reelDurationSeconds = (j['reel_duration_seconds'] as num?)?.toDouble(),
        vouchScore = j['vouch_score'] as int? ?? 0,
        isVerified = j['is_verified'] as bool?;

  final String id;
  final String phone;
  final String name;
  final String trade;
  final String? bio;
  final List<String> skillTags;
  final List<int> verifiedTagIndices;
  final String? city;
  final double? lat;
  final double? lng;
  final String? avatarURL;
  final String? reelURL;
  final String? reelHlsURL;
  final String? reelThumbnailURL;
  final double? reelDurationSeconds;
  final int vouchScore;
  final bool? isVerified;
}

class WorkerUpdateRequest {
  WorkerUpdateRequest({
    this.name,
    this.trade,
    this.bio,
    this.skillTags,
    this.verifiedTagIndices,
    this.city,
    this.lat,
    this.lng,
    this.avatarURL,
  });

  final String? name;
  final String? trade;
  final String? bio;
  final List<String>? skillTags;
  final List<int>? verifiedTagIndices;
  final String? city;
  final double? lat;
  final double? lng;
  final String? avatarURL;

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{};
    if (name != null) m['name'] = name;
    if (trade != null) m['trade'] = trade;
    if (bio != null) m['bio'] = bio;
    if (skillTags != null) m['skill_tags'] = skillTags;
    if (verifiedTagIndices != null) m['verified_tag_indices'] = verifiedTagIndices;
    if (city != null) m['city'] = city;
    if (lat != null) m['lat'] = lat;
    if (lng != null) m['lng'] = lng;
    if (avatarURL != null) m['avatar_url'] = avatarURL;
    return m;
  }
}

class TokenResponse {
  TokenResponse.fromJson(Map<String, dynamic> j)
      : accessToken = j['access_token'] as String,
        workerID = j['worker_id'] as String,
        isNewWorker = j['is_new_worker'] as bool? ?? false;

  final String accessToken;
  final String workerID;
  final bool isNewWorker;
}

class VouchCreateRequest {
  VouchCreateRequest({required this.toWorkerID, required this.skillIndices, this.voiceNoteURL});
  final String toWorkerID;
  final List<int> skillIndices;
  final String? voiceNoteURL;

  Map<String, dynamic> toJson() => {
        'to_worker_id': toWorkerID,
        'skill_indices': skillIndices,
        if (voiceNoteURL != null) 'voice_note_url': voiceNoteURL,
      };
}

class InteractionCountsDto {
  InteractionCountsDto.fromJson(Map<String, dynamic> j)
      : likes = j['likes'] as int? ?? 0,
        saves = j['saves'] as int? ?? 0,
        messages = j['messages'] as int? ?? 0;
  final int likes;
  final int saves;
  final int messages;
}

class WorkerActionStateDto {
  WorkerActionStateDto.fromJson(Map<String, dynamic> j)
      : hasLiked = j['has_liked'] as bool? ?? false,
        hasSaved = j['has_saved'] as bool? ?? false,
        hasVouched = j['has_vouched'] as bool? ?? false;
  final bool hasLiked;
  final bool hasSaved;
  final bool hasVouched;
}

class PostDto {
  PostDto.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        author = PostAuthorDto.fromJson(j['author'] as Map<String, dynamic>),
        body = j['body'] as String? ?? '',
        imageURL = j['image_url'] as String?,
        createdAt = DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now();

  final String id;
  final PostAuthorDto author;
  final String body;
  final String? imageURL;
  final DateTime createdAt;
}

class PostAuthorDto {
  PostAuthorDto.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        name = j['name'] as String? ?? '',
        trade = j['trade'] as String? ?? '',
        avatarURL = j['avatar_url'] as String?,
        isVerified = j['is_verified'] as bool? ?? false;

  final String id;
  final String name;
  final String trade;
  final String? avatarURL;
  final bool isVerified;
}

class PostCreateRequest {
  PostCreateRequest({required this.body, this.imageURL, this.lat, this.lng});
  final String body;
  final String? imageURL;
  final double? lat;
  final double? lng;

  Map<String, dynamic> toJson() => {
        'body': body,
        if (imageURL != null) 'image_url': imageURL,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };
}

class NotificationDto {
  NotificationDto.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        kind = j['kind'] as String? ?? '',
        status = j['status'] as String? ?? 'unread',
        createdAt = DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now();

  final String id;
  final String kind;
  final String status;
  final DateTime createdAt;
}

class NotificationListResponse {
  NotificationListResponse.fromJson(Map<String, dynamic> j)
      : notifications = (j['notifications'] as List<dynamic>?)
                ?.map((e) => NotificationDto.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        unreadCount = j['unread_count'] as int? ?? 0;

  final List<NotificationDto> notifications;
  final int unreadCount;
}

class InterviewScores {
  InterviewScores.fromJson(Map<String, dynamic> j)
      : confidence = j['confidence'] as int? ?? 0,
        clarity = j['clarity'] as int? ?? 0,
        tradeCompetence = j['trade_competence'] as int? ?? 0,
        summary = j['summary'] as String? ?? '';

  final int confidence;
  final int clarity;
  final int tradeCompetence;
  final String summary;
}

class MultipartInitResponse {
  MultipartInitResponse.fromJson(Map<String, dynamic> j)
      : key = j['key'] as String,
        uploadID = j['upload_id'] as String,
        partURLs = (j['part_urls'] as List<dynamic>)
            .map((e) => MultipartPartUrl.fromJson(e as Map<String, dynamic>))
            .toList();

  final String key;
  final String uploadID;
  final List<MultipartPartUrl> partURLs;
}

class MultipartPartUrl {
  MultipartPartUrl.fromJson(Map<String, dynamic> j)
      : partNumber = j['part_number'] as int,
        url = j['url'] as String;
  final int partNumber;
  final String url;
}

class ShowcaseItemDto {
  ShowcaseItemDto.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        kind = j['kind'] as String? ?? 'photo',
        title = j['title'] as String? ?? '',
        mediaURL = j['media_url'] as String? ?? '',
        thumbnailURL = j['thumbnail_url'] as String?;

  final String id;
  final String kind;
  final String title;
  final String mediaURL;
  final String? thumbnailURL;
}

class WorkHistoryDto {
  WorkHistoryDto.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        role = j['role'] as String? ?? '',
        client = j['client'] as String?,
        periodLabel = j['period_label'] as String? ?? '';

  final String id;
  final String role;
  final String? client;
  final String periodLabel;
}
