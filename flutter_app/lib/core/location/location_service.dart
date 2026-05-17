import 'dart:convert';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../networking/api_config.dart';

class Place {
  const Place({
    required this.lat,
    required this.lng,
    this.locality,
    this.city,
    this.admin,
    this.shortLabel,
  });

  final double lat;
  final double lng;
  final String? locality;
  final String? city;
  final String? admin;
  final String? shortLabel;
}

/// Mirrors LocationService.swift — cached GPS + geocoding with Mumbai fallback.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  static const _locKey = 'grayman.location.last.v2';
  static const _placeKey = 'grayman.location.place.v2';

  ({double lat, double lng})? _memory;
  Place? _placeMemory;
  DateTime? _cacheTime;

  Future<bool> requestPermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always || perm == LocationPermission.whileInUse;
  }

  Future<({double lat, double lng})> current() async {
    if (_memory != null && _cacheTime != null && DateTime.now().difference(_cacheTime!) < const Duration(minutes: 10)) {
      return _memory!;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 15)),
      );
      _memory = (lat: pos.latitude, lng: pos.longitude);
      _cacheTime = DateTime.now();
      await _persist(_memory!);
      return _memory!;
    } catch (_) {
      final persisted = await _loadPersisted();
      if (persisted != null) return persisted;
      return (lat: ApiConfig.defaultLat, lng: ApiConfig.defaultLng);
    }
  }

  Future<Place?> currentPlaceStrict() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 15)),
      );
      return _geocode(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<Place?> currentPlace() async {
    final c = await current();
    if (_placeMemory != null) return _placeMemory;
    return _geocode(c.lat, c.lng);
  }

  ({double lat, double lng})? get lastKnown => _memory;

  Future<Place?> _geocode(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isEmpty) return null;
      final p = marks.first;
      final locality = p.subLocality ?? p.thoroughfare;
      final city = p.locality ?? p.subAdministrativeArea;
      final short = [locality, city].whereType<String>().where((s) => s.isNotEmpty).join(', ');
      final place = Place(lat: lat, lng: lng, locality: locality, city: city, admin: p.administrativeArea, shortLabel: short.isEmpty ? city : short);
      _placeMemory = place;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_placeKey, jsonEncode({'lat': lat, 'lng': lng, 'short': short}));
      return place;
    } catch (_) {
      return null;
    }
  }

  Future<void> _persist(({double lat, double lng}) fix) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_locKey, jsonEncode({'lat': fix.lat, 'lng': fix.lng}));
  }

  Future<({double lat, double lng})?> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_locKey);
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return (lat: (j['lat'] as num).toDouble(), lng: (j['lng'] as num).toDouble());
  }
}
