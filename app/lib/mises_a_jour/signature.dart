import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Clé publique Ed25519 des publications de Fikajiana. La clé privée est dans
/// `release-keys/`, hors de Git.
const String clePubliqueBase64 = 'x0K7GNrUrRDDYSy/P7+mMtVLczvkVtRJM3vEIlpJQHg=';

/// Le JSON de [corps] si [signatureBase64] est bien celle de la clé publique,
/// `null` sinon : rien de non signé n'est jamais lu (ADR 0015).
Future<Map<String, dynamic>?> lireJsonSigne(
  List<int> corps,
  String signatureBase64, {
  String clePublique = clePubliqueBase64,
}) async {
  try {
    final valide = await Ed25519().verify(
      corps,
      signature: Signature(
        base64.decode(signatureBase64.trim()),
        publicKey: SimplePublicKey(
          base64.decode(clePublique),
          type: KeyPairType.ed25519,
        ),
      ),
    );
    if (!valide) return null;
    return jsonDecode(utf8.decode(corps)) as Map<String, dynamic>;
  } on Object {
    return null;
  }
}
