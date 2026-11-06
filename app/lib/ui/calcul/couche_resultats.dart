import 'package:fikajiana/comprendre/calcul_feuille.dart';
import 'package:fikajiana/comprendre/ecriture_resultat.dart';
import 'package:fikajiana/encre/vue_feuille.dart';
import 'package:fikajiana/ui/calcul/carte_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Une main rapide : un chiffre s'écrit en un quart de seconde, et un long
/// résultat ne fait jamais attendre plus d'une seconde.
const double _msParTrait = 170;
const double _msMin = 260;
const double _msMax = 1000;

/// Les résultats s'écrivent trait par trait quand ils arrivent ou changent.
/// Ceux qui étaient là à l'ouverture de la feuille ne se réécrivent pas.
class CoucheResultats extends StatefulWidget {
  const new({
    required this.blocs,
    required this.vue,
    required this.approche,
    required this.virgule,
    super.key,
  });

  final List<BlocCalcul> blocs;
  final VueFeuille vue;
  final bool approche;
  final bool virgule;

  @override
  State<CoucheResultats> createState() => _CoucheResultatsState();
}

class _CoucheResultatsState extends State<CoucheResultats>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_avancer);
  final _vus = <String, EcritureResultat>{};
  final _departs = <String, Duration>{};
  final _durees = <String, double>{};
  Duration _temps = Duration.zero;
  var _premier = true;

  void _avancer(Duration temps) {
    setState(() {
      _temps = temps;
      _departs.removeWhere(
        (cle, depart) =>
            (temps - depart).inMicroseconds / 1000 >= _durees[cle]!,
      );
      if (_departs.isEmpty) {
        _ticker.stop();
        _temps = Duration.zero;
      }
    });
  }

  void _relever() {
    final animer = !_premier && !MediaQuery.disableAnimationsOf(context);
    _premier = false;
    final presents = <String>{};
    for (final bloc in widget.blocs) {
      final ecrit = bloc.ecriture(
        approcheVoulue: widget.approche,
        virgule: widget.virgule,
      );
      if (ecrit == null) continue;
      presents.add(bloc.cle);
      final avant = _vus[bloc.cle];
      _vus[bloc.cle] = ecrit;
      // Un résultat déplacé avec son calcul ne se réécrit pas.
      if (!animer || identical(avant, ecrit)) continue;
      if (avant != null && avant.contours.length == ecrit.contours.length) {
        continue;
      }
      _departs[bloc.cle] = _temps;
      _durees[bloc.cle] = (ecrit.contours.length * _msParTrait).clamp(
        _msMin,
        _msMax,
      );
    }
    _vus.removeWhere((cle, _) => !presents.contains(cle));
    if (_departs.isNotEmpty && !_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _relever();
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: PeintreResultats(
          blocs: widget.blocs,
          couleur: Theme.of(context).colorScheme.tertiary,
          zoom: widget.vue.zoom,
          decalage: widget.vue.decalage,
          approche: widget.approche,
          virgule: widget.virgule,
          avancees: {
            for (final MapEntry(key: cle, value: depart) in _departs.entries)
              cle: (_temps - depart).inMicroseconds / 1000 / _durees[cle]!,
          },
        ),
      ),
    );
  }
}
