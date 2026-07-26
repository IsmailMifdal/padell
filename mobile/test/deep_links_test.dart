import 'package:flutter_test/flutter_test.dart';
import 'package:padel_mobile/core/deep_links.dart';

/// Un lien partagé sur WhatsApp doit ouvrir le bon écran — sinon la boucle
/// d'invitation ne fonctionne pas. Ces tests verrouillent la traduction
/// URL → route interne, y compris les formes tordues.
void main() {
  String? route(String url) => DeepLinks.routeFor(Uri.parse(url));

  group('routeFor — schéma privé padel://', () {
    test('ouvre un match', () {
      expect(route('padel://match/abc-123'), '/matches/abc-123');
    });

    test('ouvre un club', () {
      expect(route('padel://club/xyz-9'), '/clubs/xyz-9');
    });

    test('accepte aussi le pluriel', () {
      expect(route('padel://matches/abc'), '/matches/abc');
      expect(route('padel://clubs/abc'), '/clubs/abc');
    });
  });

  group('routeFor — liens web partageables', () {
    test('ouvre un match depuis une URL https', () {
      expect(route('https://padel.ma/match/abc-123'), '/matches/abc-123');
    });

    test('ouvre un club depuis une URL https', () {
      expect(route('https://padel.ma/club/xyz'), '/clubs/xyz');
    });

    test('ignore les paramètres de tracking ajoutés par les messageries', () {
      // WhatsApp/Messenger ajoutent souvent ?fbclid=… au lien partagé
      expect(route('https://padel.ma/match/abc?utm_source=whatsapp'), '/matches/abc');
    });
  });

  group('routeFor — liens non reconnus', () {
    test('renvoie null plutôt que d’ouvrir un écran au hasard', () {
      expect(route('https://padel.ma/'), isNull);
      expect(route('https://padel.ma/inconnu/123'), isNull);
      expect(route('padel://match'), isNull); // identifiant manquant
      expect(route('https://exemple.com/match/1/extra'), '/matches/1');
    });
  });

  group('mémorisation avant connexion', () {
    test('retient un lien de match ouvert par un visiteur non connecté', () {
      DeepLinks.takePending(); // repart d'un état propre
      DeepLinks.remember('/matches/abc');
      expect(DeepLinks.takePending(), '/matches/abc');
    });

    test('ne rejoue la destination qu’une seule fois', () {
      DeepLinks.remember('/clubs/xyz');
      expect(DeepLinks.takePending(), '/clubs/xyz');
      expect(DeepLinks.takePending(), isNull);
    });

    test('ne mémorise pas les écrans d’authentification', () {
      // Sinon on renverrait l'utilisateur sur /login juste après sa connexion
      DeepLinks.takePending();
      DeepLinks.remember('/login');
      DeepLinks.remember('/welcome');
      expect(DeepLinks.takePending(), isNull);
    });
  });

  test('matchUrl produit un lien absolu partageable', () {
    final url = DeepLinks.matchUrl('abc-123');
    expect(url, startsWith('http'));
    expect(url, contains('abc-123'));
    // Le lien produit doit être relu correctement par notre propre routeur
    expect(DeepLinks.routeFor(Uri.parse(url)), '/matches/abc-123');
  });
}
