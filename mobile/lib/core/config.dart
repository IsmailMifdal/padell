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
}
