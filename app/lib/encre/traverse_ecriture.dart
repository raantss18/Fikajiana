import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Un bouton posé sur la feuille, qui laisse aussi passer le stylet.
///
/// Sans cela, un trait commencé sur un résultat ou sur un `?` n'est ni écrit ni
/// raturé (vu sur le Pad 7). Le bouton reçoit quand même son toucher : son
/// action doit appeler `Encre.retirerPointDuToucher`.
class TraverseEcriture extends SingleChildRenderObjectWidget {
  const new({required Widget super.child, super.key});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenduTraversant();
}

class _RenduTraversant extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    super.hitTest(result, position: position);
    return false;
  }
}
