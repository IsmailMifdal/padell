import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/auth_controller.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/otp_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/booking/club_detail_screen.dart';
import 'features/booking/home_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/matching/create_match_screen.dart';
import 'features/matching/match_detail_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/owner/owner_repository.dart';
import 'features/owner/owner_screen.dart';
import 'features/profile/edit_profile_screen.dart';
import 'shared/models.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Pont entre l'état Riverpod et go_router : rafraîchit la navigation
  // à chaque changement d'authentification.
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      // Pendant la restauration de session, on ne redirige pas.
      if (auth.stage == AuthStage.unknown) return null;

      final loggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/otp' ||
          state.matchedLocation == '/forgot';

      if (!auth.isAuthenticated) return loggingIn ? null : '/login';
      if (loggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/otp', builder: (_, __) => const OtpScreen()),
      GoRoute(path: '/forgot', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/profile/edit',
        builder: (_, __) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(path: '/owner', builder: (_, __) => const OwnerScreen()),
      GoRoute(
        path: '/owner/club',
        builder: (context, state) =>
            OwnerClubScreen(club: state.extra as OwnerClub),
      ),
      GoRoute(
        path: '/clubs/:id',
        builder: (context, state) {
          final club = state.extra as Club;
          return ClubDetailScreen(club: club);
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
});
