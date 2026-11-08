import 'dart:async';
import 'dart:convert';
import 'dart:math';

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
const _cleDonner = 'dons_consentis';
const _cleConsentementDemande = 'dons_consentement_demande';
const _cleWifiSeulement = 'dons_wifi_seulement';
const _cleAdresse = 'dons_adresse';
const _cleContributeur = 'dons_contributeur';

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
    _donner = stockage.getBool(_cleDonner) ?? false;
    _consentementDemande = stockage.getBool(_cleConsentementDemande) ?? false;
    _wifiSeulement = stockage.getBool(_cleWifiSeulement) ?? true;
    _adresse = stockage.getString(_cleAdresse) ?? '';
    _contributeur = stockage.getString(_cleContributeur) ?? '';
  }

  // Dons d'écriture (ADR 0042) : rien ne part sans « oui » ni adresse.

  var _donner = false;

  /// « Aider à améliorer la reconnaissance » : les lignes jugées partent
  /// vers la plateforme. Non par défaut.
  bool get donner => _donner;

  set donner(bool valeur) {
    _consentementDemande = true;
    unawaited(stockage?.setBool(_cleConsentementDemande, true));
    if (valeur == _donner) {
      notifyListeners();
      return;
    }
    _donner = valeur;
    notifyListeners();
    unawaited(stockage?.setBool(_cleDonner, valeur));
  }

  var _consentementDemande = false;

  /// La question a déjà été posée (une seule fois).
  bool get consentementDemande => _consentementDemande;

  var _wifiSeulement = true;

  /// N'envoyer que sur un réseau non facturé (Wi-Fi).
  bool get wifiSeulement => _wifiSeulement;

  set wifiSeulement(bool valeur) {
    if (valeur == _wifiSeulement) return;
    _wifiSeulement = valeur;
    notifyListeners();
    unawaited(stockage?.setBool(_cleWifiSeulement, valeur));
  }

  var _adresse = '';

  /// L'adresse de la plateforme ; vide, rien ne part.
  String get adressePlateforme => _adresse;

  set adressePlateforme(String valeur) {
    final net = valeur.trim();
    if (net == _adresse) return;
    _adresse = net;
    notifyListeners();
    unawaited(stockage?.setString(_cleAdresse, net));
  }

  var _contributeur = '';

  /// L'identifiant au hasard des dons, tiré au premier besoin ; il sert au
  /// retrait, et n'est lié à rien d'autre.
  String get contributeur {
    if (_contributeur.isEmpty) nouveauContributeur();
    return _contributeur;
  }

  /// Un nouvel identifiant : après un retrait, les dons suivants ne sont
  /// plus liés aux anciens.
  void nouveauContributeur() {
    final hasard = Random.secure();
    _contributeur = base64Url
        .encode(List.generate(16, (_) => hasard.nextInt(256)))
        .replaceAll('=', '');
    unawaited(stockage?.setString(_cleContributeur, _contributeur));
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
