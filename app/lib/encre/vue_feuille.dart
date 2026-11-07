import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Ce qu'on voit de la page, sans bord : décalage et zoom.
///
/// Les traits restent en coordonnées de page : ils ne bougent pas quand la vue
/// change. Écran = page × zoom + décalage.
class VueFeuille extends ChangeNotifier {
  static const double zoomMin = 0.5;
  static const double zoomMax = 4;
  static const double _pasBouton = 1.25;

  double _zoom = 1;
  Offset _decalage = Offset.zero;

  double get zoom => _zoom;
  Offset get decalage => _decalage;
  bool get estInitiale => _zoom == 1 && _decalage == Offset.zero;

  Offset versPage(Offset ecran) => (ecran - _decalage) / _zoom;

  void glisser(Offset delta) {
    if (delta == Offset.zero) return;
    _decalage += delta;
    notifyListeners();
  }

  /// Zoome en gardant fixe le point de page sous [centre].
  void zoomer(double facteur, Offset centre) {
    final nouveau = (_zoom * facteur).clamp(zoomMin, zoomMax);
    if (nouveau == _zoom) return;
    final page = versPage(centre);
    _zoom = nouveau;
    _decalage = centre - page * nouveau;
    notifyListeners();
  }

  void zoomerPlus(Offset centre) => zoomer(_pasBouton, centre);
  void zoomerMoins(Offset centre) => zoomer(1 / _pasBouton, centre);

  /// Remet une vue relevée plus tôt ; le temps d'un export, zoom compris.
  void placer(double zoom, Offset decalage) {
    _zoom = zoom;
    _decalage = decalage;
    notifyListeners();
  }

  void recentrer() {
    if (estInitiale) return;
    _zoom = 1;
    _decalage = Offset.zero;
    notifyListeners();
  }
}
