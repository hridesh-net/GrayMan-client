import { APIConfig } from '../api/config';

const GRADIENTS = [
  '#ee6c4d', '#118AB2', '#C9184A', '#C1440E', '#7B2D8B',
  '#2D6A4F', '#E85D04', '#5C4D7D',
];

/** Mirrors iOS WorkerDTO TradeStyle.forTrade — explore card visuals. */
function tradeStyle(trade = '') {
  const lower = trade.toLowerCase();
  if (lower.includes('electric')) return { emoji: '⚡', gradientStartHex: '#0c1829' };
  if (lower.includes('plumb')) return { emoji: '🔧', gradientStartHex: '#081420' };
  if (lower.includes('hvac') || lower.includes('ac ')) return { emoji: '❄️', gradientStartHex: '#061a0e' };
  if (lower.includes('interior') || lower.includes('decorator')) return { emoji: '🎨', gradientStartHex: '#1e0f05' };
  if (lower.includes('weld')) return { emoji: '🔥', gradientStartHex: '#1a0800' };
  if (lower.includes('nurse')) return { emoji: '🏥', gradientStartHex: '#0e0718' };
  if (lower.includes('carpenter')) return { emoji: '🪚', gradientStartHex: '#1a0f00' };
  if (lower.includes('paint')) return { emoji: '🎨', gradientStartHex: '#0a0a1e' };
  if (lower.includes('mason')) return { emoji: '🧱', gradientStartHex: '#1f1208' };
  if (lower.includes('cook')) return { emoji: '🍳', gradientStartHex: '#1c0a00' };
  if (lower.includes('driver')) return { emoji: '🚗', gradientStartHex: '#0a0a0a' };
  if (lower.includes('guard') || lower.includes('security')) return { emoji: '🛡️', gradientStartHex: '#0a0a14' };
  if (lower.includes('tailor')) return { emoji: '🧵', gradientStartHex: '#160a14' };
  if (lower.includes('garden')) return { emoji: '🌿', gradientStartHex: '#0a1c0a' };
  if (lower.includes('appliance') || lower.includes('repair')) return { emoji: '🔌', gradientStartHex: '#0a141a' };
  if (lower.includes('mechanic')) return { emoji: '🔩', gradientStartHex: '#0a0a0a' };
  return { emoji: '🛠️', gradientStartHex: '#161616' };
}

function hashId(id) {
  let h = 0;
  for (let i = 0; i < (id || '').length; i++) h = (h * 31 + id.charCodeAt(i)) | 0;
  return Math.abs(h);
}

function haversineKm(lat1, lng1, lat2, lng2) {
  if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) return null;
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function initials(name) {
  return (name || '?')
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map(w => w[0]?.toUpperCase() ?? '')
    .join('');
}

/**
 * Map API WorkerDTO → UI worker object (mirrors iOS Worker(dto:)).
 */
export function workerFromDTO(dto, userLat, userLng) {
  const dist = haversineKm(userLat, userLng, dto.lat, dto.lng);
  const vouch = dto.vouch_score ?? 0;
  const years = dto.extracted_years;
  const tradeLine = years
    ? `${dto.trade} · ${years} yrs exp`
    : dto.trade;
  const style = tradeStyle(dto.trade || dto.extracted_trade || '');

  return {
    id: dto.id,
    name: dto.name,
    phone: dto.phone,
    trade: tradeLine,
    tradeRaw: dto.trade,
    bio: dto.bio,
    location: dto.city || '—',
    city: dto.city,
    lat: dto.lat,
    lng: dto.lng,
    rating: (vouch / 20).toFixed(1),
    jobs: Math.max(1, Math.round(vouch / 2)),
    vouchScore: vouch,
    vouched: vouch,
    tags: dto.skill_tags || [],
    verifiedTagIndices: new Set(dto.verified_tag_indices || []),
    emoji: style.emoji,
    gradientStartHex: style.gradientStartHex,
    gradientEndHex: GRADIENTS[hashId(dto.id) % GRADIENTS.length],
    initials: initials(dto.name),
    distance: dist != null ? dist.toFixed(1) : '—',
    avatarUrl: dto.avatar_url,
    reelUrl: dto.reel_url,
    reelHlsUrl: dto.reel_hls_url,
    playbackUrl: dto.playback_url,
    isVerified: dto.is_verified ?? false,
    analysisStatus: dto.analysis_status,
    extractedTrade: dto.extracted_trade,
    extractedYears: dto.extracted_years,
    extractedSkills: dto.extracted_skills || [],
    extractedBio: dto.extracted_bio,
    reelVerification: dto.reel_verification,
    isActive: dto.is_active,
    _dto: dto,
  };
}

export function workerUpdatePayload(fields) {
  const p = {};
  if (fields.name != null) p.name = fields.name;
  if (fields.trade != null) p.trade = fields.trade;
  if (fields.bio != null) p.bio = fields.bio;
  if (fields.skillTags != null) p.skill_tags = fields.skillTags;
  if (fields.city != null) p.city = fields.city;
  if (fields.lat != null) p.lat = fields.lat;
  if (fields.lng != null) p.lng = fields.lng;
  return p;
}

export async function withLocation(mapper) {
  const { locationService } = await import('../services/locationService');
  const { lat, lng } = await locationService.current();
  return mapper(lat, lng);
}
