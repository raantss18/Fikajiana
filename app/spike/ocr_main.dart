// Spike T1 : 50 expressions manuscrites, écrites et lues sur l'appareil.
// Textes en français seulement : cet écran n'entre pas dans l'application.
// Les modèles sont déposés par `adb push` dans le dossier de l'app.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/encre/feuille_encre.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/reconnaissance/pix2text.dart';
import 'package:fikajiana/reconnaissance/rasteriser.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:fikajiana/ui/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:path_provider/path_provider.dart';

const _expressions = <(String, String)>[
  ('fraction', r'\frac{1}{2}'),
  ('fraction', r'\frac{3}{4}+\frac{1}{6}'),
  ('fraction', r'\frac{x+1}{x-1}'),
  ('fraction', r'\frac{a}{b}=\frac{c}{d}'),
  ('fraction', r'\frac{2x^{2}+1}{3x}'),
  ('fraction', r'1+\frac{1}{1+\frac{1}{x}}'),
  ('puissance', 'x^{2}'),
  ('puissance', '2^{10}'),
  ('puissance', 'a^{n+1}'),
  ('puissance', 'x^{2}+y^{2}=1'),
  ('puissance', 'e^{-x^{2}}'),
  ('racine', r'\sqrt{2}'),
  ('racine', r'\sqrt{x+1}'),
  ('racine', r'\sqrt[3]{8}'),
  ('racine', r'\frac{1}{\sqrt{x}}'),
  ('racine', r'\sqrt{a^{2}+b^{2}}'),
  ('intégrale', r'\int x\,dx'),
  ('intégrale', r'\int_{0}^{1}x^{2}\,dx'),
  ('intégrale', r'\int_{0}^{\pi}\sin(x)\,dx'),
  ('intégrale', r'\int_{1}^{e}\frac{1}{x}\,dx'),
  ('intégrale', r'\int_{a}^{b}f(t)\,dt'),
  ('intégrale', r'\int_{0}^{+\infty}e^{-t}\,dt'),
  ('limite', r'\lim_{x\to0}\frac{\sin(x)}{x}'),
  ('limite', r'\lim_{n\to+\infty}\frac{1}{n}'),
  ('limite', r'\lim_{x\to1}x^{2}'),
  ('limite', r'\lim_{x\to+\infty}e^{-x}'),
  ('limite', r'\lim_{h\to0}\frac{f(a+h)-f(a)}{h}'),
  ('somme', r'\sum_{k=1}^{n}k'),
  ('somme', r'\sum_{k=0}^{n}x^{k}'),
  ('somme', r'\sum_{n=1}^{+\infty}\frac{1}{n^{2}}'),
  ('somme', r'\sum_{i=1}^{10}i^{2}'),
  ('somme', r'\prod_{k=1}^{n}k'),
  ('matrice', r'\begin{pmatrix}1&2\\3&4\end{pmatrix}'),
  ('matrice', r'\begin{pmatrix}a&b\\c&d\end{pmatrix}'),
  ('matrice', r'\begin{pmatrix}1&0\\0&1\end{pmatrix}'),
  ('matrice', r'\begin{pmatrix}x&1\\2&y\end{pmatrix}'),
  ('matrice', r'\begin{pmatrix}2&-1\\0&3\end{pmatrix}'),
  ('système', r'\begin{cases}x+y=1\\x-y=3\end{cases}'),
  ('système', r'\begin{cases}2x+y=5\\x-3y=2\end{cases}'),
  ('système', r'\begin{cases}x=1\\y=2\end{cases}'),
  ('système', r'\begin{cases}a+b=c\\a-b=d\end{cases}'),
  ('système', r'\begin{cases}x^{2}+y=1\\y=2x\end{cases}'),
  ('fonction', 'f(x)=x^{2}'),
  ('fonction', r'f(x)=\frac{1}{x}'),
  ('fonction', r'g(t)=\sin(t)+\cos(t)'),
  ('fonction', r'f(x)=\ln(x)'),
  ('fonction', 'f(x)=e^{x}+1'),
  ('fonction', r'h(x)=\sqrt{x}'),
  ('fonction', "f'(x)=2x"),
  ('fonction', 'y=3x+2'),
];

void main() => runApp(const _AppEssai());

class _AppEssai extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fikajiana (OCR)',
      theme: AppTheme.clair,
      darkTheme: AppTheme.sombre,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _EcranOcr(),
    );
  }
}

class _EcranOcr extends StatefulWidget {
  const new();

  @override
  State<_EcranOcr> createState() => _EcranOcrState();
}

class _EcranOcrState extends State<_EcranOcr> {
  late final File _resultats;
  final _reponses = <Map<String, dynamic>>[];
  var _encre = Encre();
  Pix2Text? _modele;
  Lecture? _lecture;
  String? _erreur;
  var _occupe = false;

  int get _indice => _reponses.length;

  @override
  void initState() {
    super.initState();
    unawaited(_ouvrir());
  }

  Future<void> _ouvrir() async {
    try {
      final dossier = (await getExternalStorageDirectory())!.path;
      _resultats = File('$dossier/resultats.jsonl');
      if (_resultats.existsSync()) {
        for (final ligne in _resultats.readAsLinesSync()) {
          _reponses.add(jsonDecode(ligne) as Map<String, dynamic>);
        }
      }
      _modele = await Pix2Text.ouvrir(dossier);
    } on Object catch (erreur) {
      _erreur = 'Modèle non ouvert : $erreur';
    }
    if (mounted) setState(() {});
  }

  Future<void> _reconnaitre() async {
    final modele = _modele;
    if (modele == null || _encre.estVide) return;
    setState(() {
      _occupe = true;
      _erreur = null;
    });
    try {
      final image = await rasteriser(_encre);
      final tenseur = await versTenseur(image!);
      image.dispose();
      _lecture = await modele.lire(tenseur);
    } on Object catch (erreur) {
      _erreur = 'Lecture impossible : $erreur';
    }
    if (mounted) setState(() => _occupe = false);
  }

  void _juger({required bool juste}) {
    final lecture = _lecture;
    if (lecture == null) return;
    final (famille, cible) = _expressions[_indice];
    final reponse = {
      'indice': _indice,
      'famille': famille,
      'cible': cible,
      'lu': lecture.latex,
      'exact': normaliserLatex(lecture.latex) == normaliserLatex(cible),
      'juste': juste,
      'msEncodeur': lecture.msEncodeur,
      'msDecodeur': lecture.msDecodeur,
      'jetons': lecture.jetons,
      'rssMo': ProcessInfo.currentRss ~/ 1000000,
      'traits': _encre.versJson(),
    };
    _resultats.writeAsStringSync(
      '${jsonEncode(reponse)}\n',
      mode: FileMode.append,
      flush: true,
    );
    setState(() {
      _reponses.add(reponse);
      _encre = Encre();
      _lecture = null;
    });
  }

  String _ligne(Map<String, dynamic> r) {
    final verdict = r['juste'] == true ? 'juste' : 'faux';
    final duree = "${r['msEncodeur']}+${r['msDecodeur']} ms";
    return "${r['indice']} ${r['famille']} $verdict $duree | "
        "${r['cible']} | ${r['lu']}";
  }

  /// Rapport sans l'encre : à copier, l'écriture reste sur l'appareil.
  String _rapport() {
    int compte(String cle) => _reponses.where((r) => r[cle] == true).length;
    final n = _reponses.length;
    final lignes = [
      'Fikajiana spike OCR : $n réponses',
      'exact (LaTeX normalisé) : ${compte('exact')}/$n',
      'juste (jugé par Antsa) : ${compte('juste')}/$n',
      for (final r in _reponses) _ligne(r),
    ];
    return lignes.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final fini = _indice >= _expressions.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          fini
              ? 'Terminé'
              : 'Expression ${_indice + 1} sur ${_expressions.length}',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copier le rapport',
            onPressed: () =>
                unawaited(Clipboard.setData(ClipboardData(text: _rapport()))),
          ),
        ],
      ),
      body: SafeArea(child: fini ? _ecranFin() : _ecranEcriture()),
    );
  }

  /// Relit les traits déjà écrits avec la rastérisation du moment.
  Future<void> _relire() async {
    final modele = _modele;
    if (modele == null) return;
    setState(() => _occupe = true);
    final sortie = File('${_resultats.parent.path}/relecture.jsonl');
    if (sortie.existsSync()) sortie.deleteSync();
    final buffer = StringBuffer();
    for (final r in _reponses) {
      final encre = Encre();
      for (final trait in r['traits'] as List<dynamic>) {
        final points = (trait as List<dynamic>).cast<List<dynamic>>();
        encre.commencer(PointEncre.depuisJson(points.first));
        for (final point in points.skip(1)) {
          encre.prolonger(PointEncre.depuisJson(point));
        }
      }
      final image = await rasteriser(encre);
      final lecture = await modele.lire(await versTenseur(image!));
      image.dispose();
      buffer.writeln(
        jsonEncode({
          'indice': r['indice'],
          'cible': r['cible'],
          'lu': lecture.latex,
          'ms': lecture.msEncodeur + lecture.msDecodeur,
          'rssMo': ProcessInfo.currentRss ~/ 1000000,
        }),
      );
    }
    sortie.writeAsStringSync(buffer.toString(), flush: true);
    if (mounted) setState(() => _occupe = false);
  }

  Widget _ecranFin() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.all(AppEspacement.md),
        child: FilledButton(
          onPressed: _occupe ? null : _relire,
          child: Text(_occupe ? 'Relecture…' : 'Relire mes traits'),
        ),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppEspacement.md),
          child: SelectableText(_rapport()),
        ),
      ),
    ],
  );

  Widget _ecranEcriture() {
    final (famille, cible) = _expressions[_indice];
    final lecture = _lecture;
    final couleurs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppEspacement.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('À écrire ($famille) : '),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Math.tex(cible),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppEspacement.sm),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: couleurs.outline),
              ),
              child: FeuilleEncre(
                encre: _encre,
                libelle: "Zone d'écriture",
                surChangement: () => setState(() => _lecture = null),
              ),
            ),
          ),
          const SizedBox(height: AppEspacement.sm),
          Wrap(
            spacing: AppEspacement.sm,
            runSpacing: AppEspacement.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: _encre.peutAnnuler
                    ? () => setState(() {
                        _encre.annuler();
                        _lecture = null;
                      })
                    : null,
                child: const Text('Annuler'),
              ),
              OutlinedButton(
                onPressed: _encre.peutRefaire
                    ? () => setState(() {
                        _encre.refaire();
                        _lecture = null;
                      })
                    : null,
                child: const Text('Refaire'),
              ),
              OutlinedButton(
                onPressed: _encre.estVide
                    ? null
                    : () => setState(() {
                        _encre.effacer();
                        _lecture = null;
                      }),
                child: const Text('Effacer'),
              ),
              FilledButton(
                onPressed: _modele == null || _encre.estVide || _occupe
                    ? null
                    : _reconnaitre,
                child: Text(_occupe ? 'Lecture…' : 'Reconnaître'),
              ),
            ],
          ),
          if (_erreur != null) ...[
            const SizedBox(height: AppEspacement.sm),
            SelectableText(_erreur!),
          ],
          if (lecture != null) ...[
            const SizedBox(height: AppEspacement.sm),
            Row(
              children: [
                const Text('Compris : '),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Math.tex(
                      lecture.latex,
                      onErrorFallback: (_) => Text(lecture.latex),
                    ),
                  ),
                ),
                const SizedBox(width: AppEspacement.sm),
                Text('${lecture.msEncodeur + lecture.msDecodeur} ms'),
              ],
            ),
            SelectableText(lecture.latex),
            const SizedBox(height: AppEspacement.sm),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _juger(juste: true),
                    icon: const Icon(Icons.check),
                    label: const Text('Juste'),
                  ),
                ),
                const SizedBox(width: AppEspacement.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _juger(juste: false),
                    icon: const Icon(Icons.close),
                    label: const Text('Faux'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
