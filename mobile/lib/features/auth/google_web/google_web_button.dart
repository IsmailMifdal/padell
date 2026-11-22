/// Bouton « Se connecter avec Google » rendu par Google Identity Services.
///
/// Sur le web, `GoogleSignIn.signIn()` est déprécié et ne fournit pas d'`idToken` :
/// seul le bouton officiel (`renderButton`) en renvoie un. Ce fichier choisit
/// l'implémentation web ou un widget vide sur les autres plateformes.
library;

export 'google_web_button_stub.dart'
    if (dart.library.js_interop) 'google_web_button_web.dart';
