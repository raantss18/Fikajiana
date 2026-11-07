import 'package:fikajiana/comprendre/decimale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('une fraction qui tombe juste en décimal', () {
    test('74×10^{-4}+85×10^8 (vu sur le Pad 7)', () {
      // 0,0074 + 8 500 000 000, calculé à la main.
      expect(
        decimaleExacte(r'\frac{42500000000037}{5000}'),
        r'8\,500\,000\,000.0074',
      );
    });

    test('petites valeurs et signe', () {
      expect(decimaleExacte(r'\frac{1}{4}'), '0.25');
      expect(decimaleExacte(r'-\frac{3}{8}'), '-0.375');
      expect(decimaleExacte(r'\frac{37}{10000}'), '0.0037');
    });

    test('1/3 ne tombe pas juste : il reste en fraction', () {
      expect(decimaleExacte(r'\frac{1}{3}'), isNull);
      expect(decimaleExacte(r'\frac{7}{12}'), isNull);
      expect(decimaleExacte(r'\sqrt{2}'), isNull);
    });
  });

  group('ce qui est écrit en décimal', () {
    test('virgule, point ou puissance négative de 10', () {
      expect(ecritEnDecimal('0,5+1'), isTrue);
      expect(ecritEnDecimal('2.5x'), isTrue);
      expect(ecritEnDecimal('1{,}5'), isTrue);
      expect(ecritEnDecimal(r'7 4 \times 1 0 ^ { - 4 } + 8 5'), isTrue);
    });

    test('des fractions restent des fractions', () {
      expect(ecritEnDecimal(r'\frac{1}{2}+\frac{1}{3}='), isFalse);
      expect(ecritEnDecimal('10^{3}+1'), isFalse);
      expect(ecritEnDecimal('pgcd(12;18)'), isFalse);
    });
  });
}
