import 'package:fikajiana/comprendre/calcul_feuille.dart';
import 'package:fikajiana/comprendre/ecriture_resultat.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/geometrie/atelier.dart';
import 'package:fikajiana/guide/catalogue.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _Lecteur extends Lecteur {
  @override
  Future<String> lire(List<Trait> traits) async => '';
}

/// Répond toujours : on vérifie ce qui est compris, pas ce que Giac calcule.
class _Moteur implements Moteur {
  final entrees = <String>[];

  @override
  Future<ReponseGiac> calculer(String entree, {bool degres = false}) async {
    entrees.add(entree);
    return const ReponseGiac(exact: '1', latex: '1', approche: '1.0');
  }

  @override
  void interrompre() {}
}

void main() {
  for (final langue in ['fr', 'en']) {
    final l10n = lookupAppLocalizations(Locale(langue));
    final catalogue = catalogueGuide(l10n);

    group('catalogue ($langue)', () {
      test('chaque famille a au moins une entrée', () {
        for (final famille in FamilleGuide.values) {
          expect(catalogue.where((e) => e.famille == famille), isNotEmpty);
        }
      });

      test('les clés sont uniques', () {
        final cles = catalogue.map((e) => e.cle).toList();
        expect(cles.toSet(), hasLength(cles.length));
      });

      test('chaque outil de la Figure a son entrée, avec son aide', () {
        for (final outil in OutilGeo.values) {
          final e = catalogue.singleWhere(
            (e) => e.cle == 'outil.${outil.name}',
          );
          expect(e.phrase, isNotEmpty);
          expect(e.essayable, isTrue);
        }
      });

      test('chaque exemple s’écrit à la main, sans formule imprimée', () {
        for (final e in catalogue) {
          for (final ligne in e.lignes) {
            expect(ecrireALEchelle(ligne, 26), isNotNull, reason: ligne);
          }
        }
      });

      test('chaque mot de géométrie se trouve dans le Guide', () {
        for (final mot in motsDeGeometrie) {
          expect(chercherGuide(catalogue, mot), isNotEmpty, reason: mot);
        }
      });

      test('titres et phrases sont remplis', () {
        for (final e in catalogue) {
          expect(e.titre.trim(), isNotEmpty, reason: e.cle);
          expect(e.phrase.trim(), isNotEmpty, reason: e.cle);
        }
      });
    });
  }

  group('chaque exemple se pose et se comprend sur une Feuille', () {
    final catalogue = catalogueGuide(
      lookupAppLocalizations(const Locale('fr')),
    );
    for (final entree in catalogue.where((e) => e.lignes.isNotEmpty)) {
      test(entree.cle, () async {
        final calcul = CalculFeuille(
          encre: Encre(),
          lecteur: _Lecteur(),
          moteur: _Moteur(),
          pause: Duration.zero,
        );
        addTearDown(calcul.dispose);
        var y = 0.0;
        for (final ligne in entree.lignes) {
          await calcul.saisir(ligne, Offset(0, y += 100));
        }
        expect(calcul.blocs, hasLength(entree.lignes.length));
        for (final bloc in calcul.blocs) {
          expect(
            bloc.etat,
            isNot(anyOf(EtatBloc.nonCompris, EtatBloc.erreur)),
            reason: '${entree.cle} : ${bloc.latex}',
          );
        }
      });
    }

    test('témoin : une ligne incomprise se voit', () async {
      final calcul = CalculFeuille(
        encre: Encre(),
        lecteur: _Lecteur(),
        moteur: _Moteur(),
        pause: Duration.zero,
      );
      addTearDown(calcul.dispose);
      await calcul.saisir(r'\vec{CD}=', Offset.zero);
      expect(calcul.blocs.single.etat, EtatBloc.nonCompris);
    });

    test('le = oublié : un calcul de nombres demande son résultat', () async {
      final calcul = CalculFeuille(
        encre: Encre(),
        lecteur: _Lecteur(),
        moteur: _Moteur(),
        pause: Duration.zero,
      );
      addTearDown(calcul.dispose);
      final egal = catalogue.singleWhere((e) => e.cle == 'egal');
      await calcul.saisir(egal.lignes.single, Offset.zero);
      expect(calcul.blocs.single.demandeResultat, isTrue);
    });
  });

  group('recherche', () {
    final catalogue = catalogueGuide(
      lookupAppLocalizations(const Locale('fr')),
    );
    List<String> cles(String requete) =>
        chercherGuide(catalogue, requete).map((e) => e.cle).toList();

    test('sans accent ni casse : « ecart type » trouve écart-type', () {
      expect(cles('ecart type'), contains('ecartType'));
      expect(cles('ÉCART-TYPE'), contains('ecartType'));
      expect(cles('Ecarttype'), contains('ecartType'));
    });

    test('une commande se trouve par son nom écrit', () {
      expect(cles('pgcd'), contains('pgcd'));
      expect(cles('det'), contains('matrice'));
      expect(cles('mediatrice'), contains('outil.mediatrice'));
    });

    test('plusieurs mots : chacun doit y être', () {
      expect(cles('matrice inverse'), ['inverse']);
    });

    test('vide : tout ; rien de connu : rien', () {
      expect(cles('  '), hasLength(catalogue.length));
      expect(cles('zzzqqq'), isEmpty);
    });

    test('sansAccents', () {
      expect(sansAccents('Écart-type'), 'ecart type');
      expect(sansAccents("Œuvre d'été"), 'oeuvre d ete');
    });
  });
}
