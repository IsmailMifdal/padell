import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Centre de recherche géographique (position du joueur ou repli).
class GeoCenter {
  const GeoCenter({
    required this.lat,
    required this.lng,
    required this.isReal,
  });

  final double lat;
  final double lng;

  /// true = position réelle de l'appareil ; false = repli (position refusée).
  final bool isReal;

  /// Repli : centre de Casablanca (là où se trouvent les clubs de démo).
  static const fallback = GeoCenter(lat: 33.5899, lng: -7.6039, isReal: false);
}

/// Position courante avec gestion des permissions. Repli silencieux si la
/// géolocalisation est refusée ou indisponible, pour ne jamais bloquer l'UI.
final geoCenterProvider = FutureProvider<GeoCenter>((ref) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return GeoCenter.fallback;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return GeoCenter.fallback;
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
    ).timeout(const Duration(seconds: 8));
    return GeoCenter(lat: pos.latitude, lng: pos.longitude, isReal: true);
  } catch (_) {
    return GeoCenter.fallback;
  }
});
