import 'package:fikajiana/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

extension PumpApp on WidgetTester {
  /// Monte l'application avec une taille et une langue données.
  Future<void> pumpFikajiana({
    Size taille = const Size(400, 800),
    Locale langue = const Locale('fr'),
    bool sansAnimation = false,
  }) async {
    view.physicalSize = taille;
    view.devicePixelRatio = 1;
    platformDispatcher.localesTestValue = [langue];
    platformDispatcher.accessibilityFeaturesTestValue = _Accessibilite(
      sansAnimation: sansAnimation,
    );
    addTearDown(view.reset);
    addTearDown(platformDispatcher.clearAllTestValues);
    await pumpWidget(const App());
    await pumpAndSettle();
  }
}

class _Accessibilite extends FakeAccessibilityFeatures {
  const new({required bool sansAnimation})
    : super(disableAnimations: sansAnimation);
}
