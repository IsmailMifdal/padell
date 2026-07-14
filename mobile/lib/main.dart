import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/config.dart';
import 'core/i18n.dart';
import 'core/theme.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Formats de dates localisés
  await initializeDateFormatting('fr');
  await initializeDateFormatting('ar');
  await initializeDateFormatting('en');

  const app = ProviderScope(child: PadelApp());
  // Crash reporting (actif seulement si --dart-define=SENTRY_DSN fourni)
  if (AppConfig.sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) => options
        ..dsn = AppConfig.sentryDsn
        ..tracesSampleRate = 0.1,
      appRunner: () => runApp(app),
    );
  } else {
    runApp(app);
  }
}

class PadelApp extends ConsumerWidget {
  const PadelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      title: 'Padel',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
      // i18n : fr par défaut, ar (RTL automatique), en
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
