import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/deep_links.dart';
import 'core/notifications_service.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/otp_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/auth/role_gate_screen.dart';
import 'features/booking/club_detail_screen.dart';
import 'features/booking/club_loader_screen.dart';
import 'features/booking/home_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/matching/create_match_screen.dart';
import 'features/matching/match_detail_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/owner/create_club_screen.dart';
import 'features/owner/owner_repository.dart';
import 'features/owner/owner_screen.dart';
import 'features/profile/edit_profile_screen.dart';
import 'features/profile/stats_screen.dart';
import 'shared/models.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Pont entre l'état Riverpod et go_router : rafraîchit la navigation
  // à chaque changement d'authentification.
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      // Pendant la restauration de session, on ne redirige pas.
      if (auth.stage == AuthStage.unknown) return null;

      final loggingIn = state.matchedLocation == '/welcome' ||
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/otp' ||
          state.matchedLocation == '/forgot';

      if (!auth.isAuthenticated) {
        // Un lien partagé ouvert par quelqu'un de non connecté ne doit pas
        // être perdu : on le met de côté et on l'ouvre après la connexion.
        // C'est précisément le cas d'usage « un ami m'invite à un match ».
        DeepLinks.remember(state.matchedLocation);
        return loggingIn ? null : '/welcome';
      }

      if (loggingIn) return DeepLinks.takePending() ?? '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Consumer(
          builder: (context, ref, __) {
            final mode = ref.watch(
              authControllerProvider.select((s) => s.mode),
            );
            return mode == AppMode.owner
                ? const OwnerScreen()
                : const HomeScreen();
          },
        ),
      ),
      GoRoute(path: '/welcome', builder: (_, __) => const RoleGateScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/otp', builder: (_, __) => const OtpScreen()),
      GoRoute(path: '/forgot', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/profile/edit',
        builder: (_, __) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/stats',
        builder: (_, __) => const StatsScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(path: '/owner', builder: (_, __) => const OwnerScreen()),
      GoRoute(
        path: '/owner/create',
        builder: (_, __) => const CreateClubScreen(),
      ),
      GoRoute(
        path: '/owner/club',
        builder: (context, state) =>
            OwnerClubScreen(club: state.extra as OwnerClub),
      ),
      GoRoute(
        path: '/clubs/:id',
        builder: (context, state) {
          // Depuis la liste, l'objet Club voyage dans `extra` (affichage
          // immédiat). Depuis un lien profond ou une notification, il n'y a
          // que l'id : on le charge alors avant d'afficher la fiche.
          final club = state.extra;
          if (club is Club) return ClubDetailScreen(club: club);
          return ClubLoaderScreen(clubId: state.pathParameters['id']!);
        },
      ),
      // '/matches/create' avant '/matches/:id' pour éviter la capture
      GoRoute(
        path: '/matches/create',
        builder: (_, __) => const CreateMatchScreen(),
      ),
      GoRoute(
        path: '/matches/:id',
        builder: (context, state) =>
            MatchDetailScreen(matchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/matches/:id/chat',
        builder: (context, state) =>
            ChatScreen(matchId: state.pathParameters['id']!),
      ),
    ],
  );

  // Écoute des liens entrants (padel://… et https://padel.ma/…) et des
  // notifications : les deux ont besoin du routeur pour ouvrir un écran.
  DeepLinks.init(router);
  NotificationsService.init(router);
  ref.onDispose(DeepLinks.dispose);

  return router;
});
