import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../shared/widgets.dart';
import 'booking_providers.dart';
import 'club_detail_screen.dart';

/// Ouvre la fiche d'un club à partir de son seul identifiant.
///
/// Depuis la liste, on navigue avec l'objet `Club` déjà chargé (affichage
/// instantané). Mais un lien profond ou une notification n'apporte que l'id :
/// il faut alors récupérer la fiche avant d'afficher l'écran. Sans ce
/// chargeur, la route `/clubs/:id` lisait un `extra` nul et plantait.
class ClubLoaderScreen extends ConsumerWidget {
  const ClubLoaderScreen({super.key, required this.clubId});

  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final club = ref.watch(clubByIdProvider(clubId));
    return club.when(
      loading: () => const Scaffold(body: CenteredLoader()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorRetry(
          message: apiErrorMessage(e),
          onRetry: () => ref.invalidate(clubByIdProvider(clubId)),
        ),
      ),
      data: (data) => ClubDetailScreen(club: data),
    );
  }
}
