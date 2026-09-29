import 'package:flutter_test/flutter_test.dart';
import 'package:lowca_mieszkan_android/main.dart';

void main() {
  group('analiza formy własności', () {
    test('wysoko ocenia jednoznaczne prawo spółdzielcze własnościowe', () {
      final result = analyzeOffer(
        'Spółdzielcze własnościowe prawo do lokalu, bez księgi wieczystej.',
      );
      expect(result.score, greaterThanOrEqualTo(90));
      expect(result.classification, contains('Spółdzielcze'));
    });

    test('odrzuca TBS i prawo lokatorskie', () {
      final result = analyzeOffer('Lokal TBS, cesja partycypacji.');
      expect(result.score, lessThan(10));
      expect(result.warnings, isNotEmpty);
    });
  });

  group('linki wyszukiwania', () {
    test('tworzy pięć linków z poprawnymi domenami', () {
      final criteria = SearchCriteria();
      final links = buildPortalLinks(criteria);
      expect(links, hasLength(5));
      expect(Uri.parse(links[0].directUrl).host, contains('olx.pl'));
      expect(Uri.parse(links[1].directUrl).host, contains('otodom.pl'));
      expect(links.every((link) => Uri.parse(link.preciseUrl).host.isNotEmpty), isTrue);
    });

    test('usuwa parametry śledzące i zachowuje parametr oferty', () {
      final result = normalizeOfferUrl(
        'https://www.otodom.pl/pl/oferta/abc?utm_source=x&id=7#gallery',
      );
      expect(result, contains('id=7'));
      expect(result, isNot(contains('utm_source')));
      expect(result, isNot(contains('#gallery')));
    });
  });

  test('eksport CSV zawiera nagłówki i link', () {
    final now = DateTime(2026, 9, 1).toIso8601String();
    final offer = Offer(
      id: '1',
      title: 'Testowa oferta',
      portal: 'olx',
      city: 'Gdańsk',
      district: 'Wrzeszcz',
      ownership: 'Do sprawdzenia',
      description: '',
      image: portalImage('olx'),
      url: 'https://www.olx.pl/d/oferta/test',
      status: 'NOWA',
      price: 500000,
      area: 50,
      rooms: 2,
      favorite: false,
      phone: '',
      notes: '',
      addedAt: now,
      updatedAt: now,
    );
    final csv = offersToCsv([offer]);
    expect(csv, contains('Tytuł'));
    expect(csv, contains('https://www.olx.pl/d/oferta/test'));
  });
}
