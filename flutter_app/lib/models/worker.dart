import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/design_system/app_colors.dart';
import 'worker_dto.dart';

class Worker {
  const Worker({
    required this.id,
    required this.initials,
    required this.name,
    required this.trade,
    required this.phone,
    this.bio,
    required this.location,
    required this.distanceKm,
    required this.vouched,
    required this.vouchScore,
    required this.jobs,
    required this.rating,
    required this.tags,
    required this.verifiedTagIndices,
    required this.emoji,
    required this.gradientStartHex,
    required this.gradientEndHex,
    required this.isVerified,
    this.avatarURL,
    this.reelPlaybackURL,
    this.reelThumbnailURL,
    this.reelDurationSeconds,
  });

  final String id;
  final String initials;
  final String name;
  final String trade;
  final String phone;
  final String? bio;
  final String location;
  final double distanceKm;
  final int vouched;
  final int vouchScore;
  final int jobs;
  final String rating;
  final List<String> tags;
  final Set<int> verifiedTagIndices;
  final String emoji;
  final String gradientStartHex;
  final String gradientEndHex;
  final bool isVerified;
  final String? avatarURL;
  final String? reelPlaybackURL;
  final String? reelThumbnailURL;
  final double? reelDurationSeconds;

  String get category => trade;
  Color get gradientStart => AppColors.fromHex(gradientStartHex);
  Color get gradientEnd => AppColors.fromHex(gradientEndHex);

  static const radiusSteps = [5, 10, 15, 20, 30, 40, 50, 60, 75, 100];

  static const allCategories = [
    'All', 'Electrician', 'Plumber', 'Carpenter', 'Painter', 'Mason', 'Welder',
    'Mechanic', 'Driver', 'Cook', 'Nurse', 'Tailor', 'AC Technician',
    'Interior Decorator', 'Appliance Repair', 'Gardener', 'Security Guard', 'Other',
  ];

  factory Worker.fromDto(WorkerDto dto, {required double userLat, required double userLng}) {
    final style = TradeStyle.forTrade(dto.trade);
    final parts = dto.name.trim().split(RegExp(r'\s+'));
    final initials = parts.map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();
    final distance = (dto.lat != null && dto.lng != null)
        ? haversineKm(userLat, userLng, dto.lat!, dto.lng!)
        : 0.0;
    final cityLabel = dto.city ?? 'Mumbai';
    final location = (dto.lat != null && dto.lng != null)
        ? '$cityLabel · ${distance.toStringAsFixed(1)} km'
        : cityLabel;
    final derivedJobs = math.max(12, dto.vouchScore * 6);
    final r = math.min(5.0, 4.0 + (dto.vouchScore / 100.0));

    return Worker(
      id: dto.id,
      initials: initials,
      name: dto.name,
      trade: dto.trade,
      phone: dto.phone,
      bio: dto.bio,
      location: location,
      distanceKm: distance,
      vouched: dto.vouchScore,
      vouchScore: dto.vouchScore,
      jobs: derivedJobs,
      rating: r.toStringAsFixed(1),
      tags: dto.skillTags,
      verifiedTagIndices: dto.verifiedTagIndices.toSet(),
      emoji: style.emoji,
      gradientStartHex: style.startHex,
      gradientEndHex: style.endHex,
      isVerified: dto.isVerified ?? false,
      avatarURL: dto.avatarURL,
      reelPlaybackURL: dto.reelHlsURL ?? dto.reelURL,
      reelThumbnailURL: dto.reelThumbnailURL,
      reelDurationSeconds: dto.reelDurationSeconds,
    );
  }
}

class TradeStyle {
  const TradeStyle(this.emoji, this.startHex, this.endHex);
  final String emoji;
  final String startHex;
  final String endHex;

  static TradeStyle forTrade(String trade) {
    final lower = trade.toLowerCase();
    if (lower.contains('electric')) return const TradeStyle('⚡', '#0c1829', '#1a3355');
    if (lower.contains('plumb')) return const TradeStyle('🔧', '#081420', '#102840');
    if (lower.contains('hvac') || lower.contains('ac ')) return const TradeStyle('❄️', '#061a0e', '#0c3018');
    if (lower.contains('interior') || lower.contains('decorator')) return const TradeStyle('🎨', '#1e0f05', '#3d2210');
    if (lower.contains('weld')) return const TradeStyle('🔥', '#1a0800', '#361400');
    if (lower.contains('nurse')) return const TradeStyle('🏥', '#0e0718', '#1c1030');
    if (lower.contains('carpenter')) return const TradeStyle('🪚', '#1a0f00', '#33200a');
    if (lower.contains('paint')) return const TradeStyle('🎨', '#0a0a1e', '#16163a');
    if (lower.contains('mason')) return const TradeStyle('🧱', '#1f1208', '#3a2412');
    if (lower.contains('cook')) return const TradeStyle('🍳', '#1c0a00', '#3a1c08');
    if (lower.contains('driver')) return const TradeStyle('🚗', '#0a0a0a', '#1c1c1c');
    if (lower.contains('guard') || lower.contains('security')) return const TradeStyle('🛡️', '#0a0a14', '#1c1c30');
    if (lower.contains('tailor')) return const TradeStyle('🧵', '#160a14', '#2e1830');
    if (lower.contains('garden')) return const TradeStyle('🌿', '#0a1c0a', '#163018');
    if (lower.contains('appliance') || lower.contains('repair')) return const TradeStyle('🔌', '#0a141a', '#162a36');
    if (lower.contains('mechanic')) return const TradeStyle('🔩', '#0a0a0a', '#262626');
    return const TradeStyle('🛠️', '#161616', '#2d2d2d');
  }
}

double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final phi1 = lat1 * math.pi / 180;
  final phi2 = lat2 * math.pi / 180;
  final dphi = (lat2 - lat1) * math.pi / 180;
  final dlam = (lng2 - lng1) * math.pi / 180;
  final a = math.sin(dphi / 2) * math.sin(dphi / 2) +
      math.cos(phi1) * math.cos(phi2) * math.sin(dlam / 2) * math.sin(dlam / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}
