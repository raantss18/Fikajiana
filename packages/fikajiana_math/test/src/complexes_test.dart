import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:test/test.dart';

/// Ce qui est lu et demandé à Giac, puis l'écriture de sa réponse (ADR 0058).
/// Les réponses de Giac copiées ici ont été obtenues avec Giac compilé pour
/// Linux au commit de l'app (19a710ae) ; les valeurs se vérifient contre SymPy
/// au banc (`tool/banc/references_feuille.py`, problème « complexes »).
void main() {
  group('formes demandées', () {
    test('lues à la main, au clavier, avec ou sans police', () {
      expect(
        formeDemandee(r'\mathrm{formeexp}(1+i)'),
        FormeComplexe.exponentielle,
      );
      expect(
        formeDemandee(r'\text{formetrigo}\left(1+i\right)='),
        FormeComplexe.trigonometrique,
      );
      expect(
        formeDemandee(r'\text{forme trigonométrique}(1+i)'),
        FormeComplexe.trigonometrique,
      );
      expect(formeDemandee('racines(3;8i)'), FormeComplexe.racines);
      expect(formeDemandee('expform(1+i)'), FormeComplexe.exponentielle);
    });

    test('rien d’autre', () {
      expect(formeDemandee('f(x)=x^2'), isNull);
      expect(formeDemandee(r'\left(1+i\right)'), isNull);
      expect(formeDemandee(r'\arg(1+i)'), isNull);
    });
  });

  group('ce que Giac calcule', () {
    test('forme exponentielle : module et argument simplifiés', () {
      final a = analyserLatex(r'\mathrm{formeexp}(1+i)');
      expect(a.type, TypeExpression.calcul);
      expect(a.demandeResultat, isTrue);
      expect(a.giac, '[simplify(abs((1+i))),simplify(arg((1+i)))]');
    });

    test('en degrés, l’argument revient en radians', () {
      expect(
        analyserLatex('formeexp(1+i)', degres: true).giac,
        '[simplify(abs((1+i))),simplify(arg((1+i))*pi/180)]',
      );
    });

    test('racines n-ièmes : n angles', () {
      expect(
        analyserLatex('racines(3;8i)').giac,
        '[simplify(abs((8*i))^(1/3)),[simplify((arg((8*i))+2*0*pi)/3),'
        'simplify((arg((8*i))+2*1*pi)/3),simplify((arg((8*i))+2*2*pi)/3)]]',
      );
    });

    test('refusés : une variable, n hors de 2 à 12', () {
      expect(() => analyserLatex('formeexp(z)'), throwsA(isA<ErreurLatex>()));
      expect(() => analyserLatex('racines(1;8)'), throwsA(isA<ErreurLatex>()));
      expect(() => analyserLatex('racines(13;8)'), throwsA(isA<ErreurLatex>()));
      expect(() => analyserLatex('racines(8)'), throwsA(isA<ErreurLatex>()));
    });

    test('au clavier', () {
      final saisie = lireSaisie('racines(4;-16)=');
      expect(saisie.latex, r'\text{racines}\left(4;-16\right)=');
      expect(formeDemandee(saisie.latex!), FormeComplexe.racines);
      expect(analyserLatex(saisie.latex!).giac, startsWith('[simplify('));
    });
  });

  group('écriture de la réponse de Giac', () {
    String? ecrire(FormeComplexe f, String r) => ecrireFormeComplexe(f, r);

    test('r e^{iθ}', () {
      expect(
        ecrire(FormeComplexe.exponentielle, r'[\sqrt{2},\frac{\pi }{4}]'),
        r'\sqrt{2}\,e^{i\frac{\pi}{4}}',
      );
      expect(
        ecrire(FormeComplexe.exponentielle, r'[2,-\frac{2\cdot \pi }{3}]'),
        r'2\,e^{-i\frac{2\pi}{3}}',
      );
      expect(ecrire(FormeComplexe.exponentielle, r'[4,\pi ]'), r'4\,e^{i\pi}');
    });

    test('module 1, argument nul, zéro', () {
      expect(
        ecrire(FormeComplexe.exponentielle, r'[1,\frac{\pi }{2}]'),
        r'e^{i\frac{\pi}{2}}',
      );
      expect(ecrire(FormeComplexe.exponentielle, '[5,0]'), '5');
      // 0 n'a pas d'argument, même si Giac rend arg(0) = 0.
      expect(ecrire(FormeComplexe.trigonometrique, '[0,0]'), '0');
    });

    test('r (cos θ + i sin θ)', () {
      expect(
        ecrire(FormeComplexe.trigonometrique, r'[\sqrt{2},\frac{\pi }{4}]'),
        r'\sqrt{2}\left(\cos \frac{\pi}{4}+i\sin \frac{\pi}{4}\right)',
      );
      expect(
        ecrire(FormeComplexe.trigonometrique, r'[2,-\frac{2\cdot \pi }{3}]'),
        r'2\left(\cos\left(-\frac{2\pi}{3}\right)'
        r'+i\sin\left(-\frac{2\pi}{3}\right)\right)',
      );
    });

    test('arctan au lieu de atan', () {
      expect(
        ecrire(
          FormeComplexe.exponentielle,
          r'[5,\mathrm{atan}\left(\frac{4}{3}\right)]',
        ),
        r'5\,e^{i\arctan\left(\frac{4}{3}\right)}',
      );
    });

    test('racines : z_k', () {
      expect(
        ecrire(
          FormeComplexe.racines,
          r'[2,[\frac{\pi }{6},\frac{5\cdot \pi }{6},\frac{3\cdot \pi }{2}]]',
        ),
        r'z_{0}=2\,e^{i\frac{\pi}{6}}\,;\,z_{1}=2\,e^{i\frac{5\pi}{6}}'
        r'\,;\,z_{2}=2\,e^{i\frac{3\pi}{2}}',
      );
      expect(
        ecrire(FormeComplexe.racines, r'[1,[0,\pi ]]'),
        r'z_{0}=1\,;\,z_{1}=e^{i\pi}',
      );
    });

    test('ce qui n’a pas la forme attendue : rien', () {
      expect(ecrire(FormeComplexe.exponentielle, r'\sqrt{2}'), isNull);
      expect(ecrire(FormeComplexe.exponentielle, '[1,2,3]'), isNull);
      expect(ecrire(FormeComplexe.racines, '[2,3]'), isNull);
    });
  });

  group('équations dans ℂ', () {
    test('inconnue z : csolve, seulement en degré 1 ou 2', () {
      final a = analyserLatex('z^{2}+1=0');
      expect(a.type, TypeExpression.equation);
      expect(a.inconnues, ['z']);
      expect(
        a.giac,
        'ifte(degree(numer(normal(((z)^(2)+1)-(0))),z)>=1 and '
        'degree(numer(normal(((z)^(2)+1)-(0))),z)<=2,'
        'csolve(((z)^(2)+1)=(0),z),undef)',
      );
    });

    test('i dans l’équation : dans ℂ aussi', () {
      expect(analyserLatex('(1+i)x=2-i').giac, contains('csolve('));
    });

    test('x sans i : dans ℝ, comme avant', () {
      expect(analyserLatex('x^{2}+1=0').giac, 'solve((x)^(2)+1=0,x)');
    });

    test('dansC', () {
      expect(dansC('z', 'z^2', '0'), isTrue);
      expect(dansC('x', '2*i*x', '1'), isTrue);
      expect(dansC('x', 'sin(x)', 'pi'), isFalse);
      expect(dansC('x', 'x', 'inf'), isFalse);
    });
  });
}
