import 'package:flutter/services.dart';

/// Les coordonnées publiques d'Antsa, autrice de Fikajiana (demande
/// d'Antsa, 2026-11-09). Rien ne part sans le geste de la personne : un
/// toucher ouvre l'app de courriel, le navigateur ou WhatsApp.
abstract final class Contact {
  /// Son nom, tel qu'elle l'écrit.
  static const nom = 'Antsa Malala RANIRIAMANJAKA';

  /// Son courriel public.
  static const courriel = 'antsa.raniriamanjaka@univ-antananarivo.mg';

  /// Le dépôt du code source (licence : ADR 0001).
  static const depot = 'https://github.com/raantss18/Fikajiana';

  /// Son numéro WhatsApp, chiffres seuls avec l'indicatif (`261…`), donné
  /// par Antsa le 2026-11-09.
  static const whatsApp = '261334383882';

  /// Le lien d'une discussion WhatsApp (<https://faq.whatsapp.com/5913398998672934>).
  /// `null` cacherait l'entrée des Réglages.
  static String? get lienWhatsApp => 'https://wa.me/$whatsApp';
}

const _systeme = MethodChannel('fikajiana/systeme');

/// Ouvre [lien] (`mailto:`, `https:`) dans l'app qui sait le faire. `false`
/// si aucune ne le peut (ou hors d'Android).
Future<bool> ouvrirLien(String lien) async {
  try {
    return await _systeme.invokeMethod<bool>('ouvrir', {'lien': lien}) ?? false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}
