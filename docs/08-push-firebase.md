# Notifications push — état et branchement Firebase

## Ce qui fonctionne déjà, sans rien configurer

| Élément | État |
|---|---|
| Notifications **locales** (rappel 2 h avant une réservation) | ✅ actif |
| Annulation du rappel quand la réservation est annulée | ✅ actif |
| Ouverture du bon écran au tap sur une notification | ✅ actif |
| Liens profonds `padel://match/<id>`, `padel://club/<id>` | ✅ actif |
| Lien partagé rejoué **après** connexion | ✅ actif |
| Génération des notifications côté serveur | ✅ actif (déjà en base) |
| Envoi **push distant** vers l'appareil | ⛔ nécessite Firebase |

Autrement dit : tout le circuit est en place **sauf** le jeton d'appareil, que
seul Firebase Cloud Messaging (FCM) peut fournir.

## Pourquoi `firebase_messaging` n'est pas encore dans `pubspec.yaml`

Le plugin Gradle `com.google.gms.google-services` **fait échouer la
compilation Android** si `google-services.json` est absent :

```
File google-services.json is missing. The Google Services Plugin cannot function without it.
```

Ajouter la dépendance maintenant casserait la génération de l'APK, qui
fonctionne aujourd'hui. Le point de branchement est donc prêt, mais la
dépendance est ajoutée seulement quand le fichier de configuration existe.

## Branchement, une fois le projet Firebase créé

### 1. Créer le projet et récupérer les fichiers

1. <https://console.firebase.google.com> → **Ajouter un projet**
2. Ajouter une application **Android** : `applicationId` = celui de
   `android/app/build.gradle` → télécharger **`google-services.json`** →
   le déposer dans `mobile/android/app/`
3. (iOS) Ajouter une application **iOS** → **`GoogleService-Info.plist`** →
   le déposer dans `mobile/ios/Runner/`
4. Générer une **clé de compte de service** (Paramètres → Comptes de service)
   et la fournir au backend :
   `FIREBASE_SERVICE_ACCOUNT_BASE64=<json encodé en base64>`

### 2. Ajouter les dépendances

```bash
cd mobile
flutter pub add firebase_core firebase_messaging
```

### 3. Fournir la source de jeton

Un seul fichier à modifier : `lib/core/push_service.dart`. Remplacer
l'implémentation de repli par une source FCM :

```dart
class FcmPushTokenSource implements PushTokenSource {
  @override
  Future<String?> getToken() async {
    await Firebase.initializeApp();
    await FirebaseMessaging.instance.requestPermission();
    return FirebaseMessaging.instance.getToken();
  }
}

// puis :
final pushTokenSourceProvider =
    Provider<PushTokenSource>((ref) => FcmPushTokenSource());
```

Rien d'autre ne change : `PushService.registerCurrentDevice()` est déjà
appelé après chaque connexion et poste le jeton sur `PUT /notifications/device`.

### 4. Ouvrir le bon écran quand un push est touché

Les notifications envoyées par le serveur doivent porter une donnée `deepLink`
de la forme `padel://match/<id>`. Côté app :

```dart
FirebaseMessaging.onMessageOpenedApp.listen((message) {
  final link = message.data['deepLink'];
  if (link != null) {
    final route = DeepLinks.routeFor(Uri.parse(link));
    if (route != null) router.go(route);
  }
});
```

## Vérifier que ça marche

1. Se connecter dans l'app → le log doit afficher `PushService : appareil enregistré (android)`
2. Vérifier en base : `SELECT * FROM device_tokens WHERE user_id = '<id>';`
3. Déclencher un événement (rejoindre un match) → la notification doit arriver
   même app fermée

Tant que Firebase n'est pas configuré, le log affiche
`aucun fournisseur de jeton configuré` : c'est le comportement de repli
attendu, l'app fonctionne normalement.

## Liens web partageables (optionnel mais recommandé)

Le manifeste Android déclare déjà `https://padel.ma` avec `autoVerify`. Pour
que le lien ouvre l'app plutôt que le navigateur, publier sur le domaine :

`https://padel.ma/.well-known/assetlinks.json`

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "<applicationId>",
    "sha256_cert_fingerprints": ["<empreinte SHA-256 de la clé de signature>"]
  }
}]
```

Sans ce fichier, le lien s'ouvre dans le navigateur — jamais une erreur.
