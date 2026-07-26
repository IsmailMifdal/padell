import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'palette.dart';

/// État réseau de l'appareil.
///
/// Nuance importante : `connectivity_plus` dit si une interface est active
/// (Wi-Fi, données mobiles), pas si Internet est réellement joignable — un
/// Wi-Fi de club sans passerelle est « connecté » mais inutilisable. On s'en
/// sert donc pour le cas franc (mode avion, aucune interface) et on laisse les
/// erreurs Dio gérer le reste, via `isNetworkError`.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();

  bool online(List<ConnectivityResult> r) =>
      r.isNotEmpty && !r.every((e) => e == ConnectivityResult.none);

  yield online(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(online);
});

/// Bandeau discret affiché tant que l'appareil est hors ligne.
///
/// Il s'insère au-dessus du contenu au lieu de le masquer : l'utilisateur
/// garde accès à ce qui est déjà chargé.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(connectivityProvider).valueOrNull ?? true;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: online
          ? const SizedBox.shrink()
          : Material(
              color: AppColors.ink,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.wifi_off_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Hors ligne — les données affichées peuvent dater',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
