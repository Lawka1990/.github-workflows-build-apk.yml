import 'package:flutter_test/flutter_test.dart';
import 'package:grunwald_navigator/utils/search_text.dart';

void main() {
  test('wyszukiwanie ignoruje polskie znaki i wielkość liter', () {
    expect(SearchText.normalize('  Chorągiew GOŃCZA  '), 'choragiew goncza');
    expect(SearchText.normalize('Łucznictwo'), 'lucznictwo');
  });
}
