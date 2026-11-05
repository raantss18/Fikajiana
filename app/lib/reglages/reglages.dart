import 'dart:async';

import 'package:fikajiana/reglages/support.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _cleSupport = 'support';
const _cleStylo = 'stylo';

/// Réglages de l'utilisateur, gardés sur l'appareil seulement.
class Reglages extends ChangeNotifier {
  new({this.stockage}) {
    final stockage = this.stockage;
    if (stockage == null) return;
    final nom = stockage.getString(_cleSupport);
    _support = SupportEcriture.values.asNameMap()[nom] ?? _support;
    final stylo = stockage.getInt(_cleStylo) ?? 0;
    _indiceStylo = stylo.clamp(0, _support.stylos.length - 1);
  }

  static Future<Reglages> charger() async =>
      Reglages(stockage: await SharedPreferences.getInstance());

  final SharedPreferences? stockage;
  SupportEcriture _support = SupportEcriture.feuilleBlanche;
  var _indiceStylo = 0;

  SupportEcriture get support => _support;
  int get indiceStylo => _indiceStylo;

  set support(SupportEcriture valeur) {
    if (valeur == _support) return;
    _support = valeur;
    notifyListeners();
    unawaited(stockage?.setString(_cleSupport, valeur.name));
  }

  set indiceStylo(int valeur) {
    if (valeur == _indiceStylo) return;
    _indiceStylo = valeur;
    notifyListeners();
    unawaited(stockage?.setInt(_cleStylo, valeur));
  }
}

/// Donne les réglages à tout l'arbre.
class PorteeReglages extends InheritedNotifier<Reglages> {
  const new({required Reglages reglages, required super.child, super.key})
    : super(notifier: reglages);

  static Reglages de(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PorteeReglages>()!.notifier!;
}
