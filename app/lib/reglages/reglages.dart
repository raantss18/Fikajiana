import 'dart:async';

import 'package:fikajiana/reglages/support.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _cleSupport = 'support';
const _cleStylo = 'stylo';
const _cleApproche = 'approche';
const _cleDegres = 'degres';
const _cleStyletConnu = 'stylet_connu';
const _cleEcrireAuDoigt = 'ecrire_au_doigt';
const _cleAuPropre = 'au_propre';
const _cleAider = 'aider_reconnaissance';
const _clePrenom = 'prenom';

/// Réglages de l'utilisateur, gardés sur l'appareil seulement.
class Reglages extends ChangeNotifier {
  new({this.stockage}) {
    final stockage = this.stockage;
    if (stockage == null) return;
    final nom = stockage.getString(_cleSupport);
    _support = SupportEcriture.values.asNameMap()[nom] ?? _support;
    final stylo = stockage.getInt(_cleStylo) ?? 0;
    _indiceStylo = stylo.clamp(0, _support.stylos.length - 1);
    _approche = stockage.getBool(_cleApproche) ?? false;
    _degres = stockage.getBool(_cleDegres) ?? false;
    _styletConnu = stockage.getBool(_cleStyletConnu) ?? false;
    _ecrireAuDoigt = stockage.getBool(_cleEcrireAuDoigt) ?? false;
    _auPropre = stockage.getBool(_cleAuPropre) ?? true;
    _aider = stockage.getBool(_cleAider) ?? true;
    _prenom = stockage.getString(_clePrenom) ?? '';
  }

  var _aider = true;

  /// « Aider la reconnaissance » : l'écriture lue reste sur l'appareil pour
  /// l'entraînement ; rien ne part sans le geste de la personne (ADR 0042).
  bool get aiderReconnaissance => _aider;

  set aiderReconnaissance(bool valeur) {
    if (valeur == _aider) return;
    _aider = valeur;
    notifyListeners();
    unawaited(stockage?.setBool(_cleAider, valeur));
  }

  var _prenom = '';

  /// Le prénom écrit comme auteur des écritures exportées.
  String get prenom => _prenom;

  set prenom(String valeur) {
    final net = valeur.trim();
    if (net == _prenom) return;
    _prenom = net;
    notifyListeners();
    unawaited(stockage?.setString(_clePrenom, net));
  }

  var _auPropre = true;

  /// Ce qui est lu s'écrit au propre à la place de l'encre (Antsa).
  bool get auPropre => _auPropre;

  set auPropre(bool valeur) {
    if (valeur == _auPropre) return;
    _auPropre = valeur;
    notifyListeners();
    unawaited(stockage?.setBool(_cleAuPropre, valeur));
  }

  static Future<Reglages> charger() async =>
      Reglages(stockage: await SharedPreferences.getInstance());

  final SharedPreferences? stockage;
  SupportEcriture _support = SupportEcriture.feuilleBlanche;
  var _indiceStylo = 0;

  var _approche = false;
  var _degres = false;
  var _styletConnu = false;
  var _ecrireAuDoigt = false;

  /// Un stylet a déjà servi sur cet appareil.
  bool get styletConnu => _styletConnu;

  /// Malgré un stylet connu, le doigt écrit aussi.
  bool get ecrireAuDoigt => _ecrireAuDoigt;

  /// La main ne fait que déplacer la page.
  bool get doigtDefile => _styletConnu && !_ecrireAuDoigt;

  void noterStylet() {
    if (_styletConnu) return;
    _styletConnu = true;
    notifyListeners();
    unawaited(stockage?.setBool(_cleStyletConnu, true));
  }

  set ecrireAuDoigt(bool valeur) {
    if (valeur == _ecrireAuDoigt) return;
    _ecrireAuDoigt = valeur;
    notifyListeners();
    unawaited(stockage?.setBool(_cleEcrireAuDoigt, valeur));
  }

  /// Montre la valeur approchée plutôt que la valeur exacte.
  bool get approche => _approche;

  /// Les angles sont en degrés plutôt qu'en radians.
  bool get degres => _degres;

  set approche(bool valeur) {
    if (valeur == _approche) return;
    _approche = valeur;
    notifyListeners();
    unawaited(stockage?.setBool(_cleApproche, valeur));
  }

  set degres(bool valeur) {
    if (valeur == _degres) return;
    _degres = valeur;
    notifyListeners();
    unawaited(stockage?.setBool(_cleDegres, valeur));
  }

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
