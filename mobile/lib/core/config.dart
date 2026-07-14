/// Configuration de l'application.
class AppConfig {
  /// URL de l'API (préfixe /v1 inclus).
  ///
  /// - Émulateur Android : `10.0.2.2` route vers le `localhost` de la machine hôte.
  /// - iOS simulator / web : utiliser `localhost`.
  /// Surchargeable au build : `--dart-define=API_URL=https://api.padel.ma/v1`.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:3001/v1',
  );

  /// Client OAuth Google (Web) — active le bouton « Continuer avec Google ».
  /// `--dart-define=GOOGLE_WEB_CLIENT_ID=xxx.apps.googleusercontent.com`
  static const String googleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  /// DSN Sentry — active le crash reporting.
  /// `--dart-define=SENTRY_DSN=https://...`
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');
}
