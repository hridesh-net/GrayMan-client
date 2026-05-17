import * as Location from 'expo-location';
import { APIConfig } from '../api/config';

let cachedPlace = null;
let cachedAt = 0;
const CACHE_MS = 10 * 60 * 1000;

export const locationService = {
  async requestPermission() {
    const { status } = await Location.requestForegroundPermissionsAsync();
    return status === 'granted';
  },

  async current() {
    try {
      const { status } = await Location.getForegroundPermissionsAsync();
      if (status !== 'granted') {
        return { lat: APIConfig.defaultLat, lng: APIConfig.defaultLng };
      }
      const pos = await Location.getCurrentPositionAsync({
        accuracy: Location.Accuracy.Balanced,
      });
      return { lat: pos.coords.latitude, lng: pos.coords.longitude };
    } catch {
      return { lat: APIConfig.defaultLat, lng: APIConfig.defaultLng };
    }
  },

  /** Real GPS only — no Mumbai fallback (for profile sync). */
  async currentPlaceStrict() {
    const now = Date.now();
    if (cachedPlace && now - cachedAt < CACHE_MS) return cachedPlace;

    const { status } = await Location.getForegroundPermissionsAsync();
    if (status !== 'granted') return null;

    try {
      const pos = await Location.getCurrentPositionAsync({
        accuracy: Location.Accuracy.Balanced,
      });
      const { latitude: lat, longitude: lng } = pos.coords;
      const [geo] = await Location.reverseGeocodeAsync({ latitude: lat, longitude: lng });
      const city = geo?.city || geo?.subregion || geo?.region;
      const shortLabel = [geo?.city, geo?.region].filter(Boolean).join(', ') || city;
      cachedPlace = { lat, lng, city, shortLabel: shortLabel || city };
      cachedAt = now;
      return cachedPlace;
    } catch {
      return null;
    }
  },
};
