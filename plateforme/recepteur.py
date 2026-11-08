"""Récepteur des dons d'écriture (ADR 0042) : une application WSGI, bibliothèque standard seulement.

API (fixée avec l'app) :
  POST /v1/dons     corps = une séance (`collecte/FORMAT.md`, champs permis : `schema.py`) → 201 {"recu": n}
  POST /v1/retrait  {"contributeur": "<id>"} → 202 {"retire": n}
  GET  /v1/export?depuis=<ISO 8601>  avec « Authorization: Bearer <FIKA_JETON_ADMIN> » → JSON lines
  GET  /v1/sante    → 200 {"ok": true}
  GET  /v1/mon-ip   avec le jeton : l'adresse que le récepteur attribue à l'appelant (réglage du proxy)

Lancement : `python recepteur.py` (Waitress, voir `servir()`). HTTPS est assuré devant (Caddy, hébergeur).
Journal : méthode, chemin, statut, durée. Jamais l'IP, jamais le contenu.

Variables d'environnement :
  FIKA_DOSSIER        dossier des dons (défaut ./dons-recus) ; ou FIKA_S3_SEAU (+ FIKA_S3_ADRESSE,
                      FIKA_S3_REGION, FIKA_S3_PREFIXE, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
  FIKA_JETON_ADMIN    jeton de l'export (≥ 32 caractères) ; absent : export fermé
  FIKA_DEBIT          requêtes POST permises par IP et par fenêtre (défaut 30)
  FIKA_FENETRE        durée de la fenêtre en secondes (défaut 60)
  FIKA_DERRIERE_PROXY nombre d'adresses ajoutées à droite de X-Forwarded-For par les proxys de
                      confiance : 1 derrière Caddy ; 0 ou absent : l'adresse de la connexion
  FIKA_PORT ou PORT   port d'écoute (défaut 8080 ; Cloud Run fournit PORT)
"""

from __future__ import annotations

import collections
import datetime as dt
import hmac
import json
import logging
import os
import threading
import time
import urllib.parse

import schema
import stockage as stockage_mod

journal = logging.getLogger("fikajiana.dons")


class Limiteur:
    """Fenêtre glissante par IP, en mémoire. Une IP est oubliée dès que sa fenêtre est vide."""

    def __init__(self, permis: int, fenetre: float, horloge=time.monotonic):
        self.permis, self.fenetre, self.horloge = permis, fenetre, horloge
        self.vus: dict[str, collections.deque] = {}
        self.verrou = threading.Lock()
        self.dernier_menage = horloge()

    def accepter(self, ip: str) -> float:
        """0 si la requête passe, sinon le nombre de secondes à attendre."""
        with self.verrou:
            maintenant = self.horloge()
            if maintenant - self.dernier_menage >= self.fenetre:
                self._menage(maintenant)
            file = self.vus.setdefault(ip, collections.deque())
            while file and file[0] <= maintenant - self.fenetre:
                file.popleft()
            if len(file) >= self.permis:
                return max(1.0, file[0] + self.fenetre - maintenant)
            file.append(maintenant)
            return 0.0

    def _menage(self, maintenant: float) -> None:
        for ip in [ip for ip, f in self.vus.items() if not f or f[-1] <= maintenant - self.fenetre]:
            del self.vus[ip]
        self.dernier_menage = maintenant

    def nombre_ip(self) -> int:
        with self.verrou:
            self._menage(self.horloge())
            return len(self.vus)


class Recepteur:
    def __init__(
        self,
        stockage: stockage_mod.Stockage,
        jeton_admin: str | None = None,
        debit: int = 30,
        fenetre: float = 60.0,
        derriere_proxy: int = 0,
        classes: dict[str, str] | None = None,
        horloge=time.monotonic,
    ):
        if jeton_admin is not None and len(jeton_admin) < 32:
            raise ValueError("FIKA_JETON_ADMIN : 32 caractères au moins")
        self.stockage = stockage
        self.jeton_admin = jeton_admin
        self.limiteur = Limiteur(debit, fenetre, horloge)
        self.derriere_proxy = int(derriere_proxy)
        self.classes = classes if classes is not None else schema.lire_classes()

    # --- WSGI -------------------------------------------------------------------------------

    def __call__(self, environ, start_response):
        debut = time.monotonic()
        methode = environ.get("REQUEST_METHOD", "")
        chemin = environ.get("PATH_INFO", "")
        try:
            statut, entetes, corps = self._router(environ, methode, chemin)
        except Exception:  # noqa: BLE001 — une erreur imprévue ne doit rien divulguer
            journal.exception("erreur interne sur %s %s", methode, chemin[:40])
            statut, entetes, corps = _json(500, {"erreur": "erreur interne"})
        start_response(statut, entetes)
        # Seulement des routes connues dans le journal : rien de ce que l'appelant a écrit.
        connu = chemin if chemin in ("/v1/dons", "/v1/retrait", "/v1/export", "/v1/sante", "/v1/mon-ip") else "?"
        journal.info("%s %s %s %.0f ms", methode[:8], connu, statut[:3], (time.monotonic() - debut) * 1000)
        return corps

    def _router(self, environ, methode, chemin):
        routes = {
            "/v1/dons": ("POST", self._don),
            "/v1/retrait": ("POST", self._retrait),
            "/v1/export": ("GET", self._export),
            "/v1/sante": ("GET", lambda env: _json(200, {"ok": True})),
            "/v1/mon-ip": ("GET", self._mon_ip),
        }
        if chemin not in routes:
            return _json(404, {"erreur": "inconnu"})
        attendue, action = routes[chemin]
        if methode != attendue:
            statut, entetes, corps = _json(405, {"erreur": f"{attendue} seulement"})
            return statut, entetes + [("Allow", attendue)], corps
        if methode == "POST" or chemin in ("/v1/export", "/v1/mon-ip"):
            attente = self.limiteur.accepter(self._ip(environ))
            if attente:
                statut, entetes, corps = _json(429, {"erreur": "trop de requêtes"})
                return statut, entetes + [("Retry-After", str(int(attente + 0.999)))], corps
        return action(environ)

    def _ip(self, environ) -> str:
        if self.derriere_proxy:
            # Chaque proxy de confiance ajoute l'adresse qu'il voit à droite ; ce qui est plus à gauche
            # vient du client et peut être inventé. On prend donc la N-ième adresse en partant de la droite.
            relais = [a.strip() for a in environ.get("HTTP_X_FORWARDED_FOR", "").split(",") if a.strip()]
            if len(relais) >= self.derriere_proxy:
                return relais[-self.derriere_proxy]
        return environ.get("REMOTE_ADDR", "")

    def _corps_json(self, environ, maxi: int):
        type_ = environ.get("CONTENT_TYPE", "").split(";")[0].strip().lower()
        if type_ != "application/json":
            raise _Refus(415, "Content-Type: application/json attendu")
        if environ.get("HTTP_CONTENT_ENCODING", "identity").lower() not in ("", "identity"):
            raise _Refus(415, "corps compressé non accepté")
        try:
            longueur = int(environ.get("CONTENT_LENGTH") or -1)
        except ValueError:
            longueur = -1
        if longueur > maxi:
            raise _Refus(413, f"corps de plus de {maxi} octets")
        if longueur < 0:
            raise _Refus(411, "Content-Length obligatoire")
        octets = environ["wsgi.input"].read(longueur)
        if len(octets) != longueur:
            raise _Refus(400, "corps incomplet")
        try:
            return schema.analyser_json(octets)
        except schema.DonInvalide as e:
            raise _Refus(400, str(e)) from e

    # --- Routes -----------------------------------------------------------------------------

    def _don(self, environ):
        try:
            seance = self._corps_json(environ, schema.TAILLE_MAX)
            n = schema.verifier_seance(seance, self.classes)
        except _Refus as r:
            return _json(r.statut, {"erreur": r.message})
        except schema.DonInvalide as e:
            return _json(400, {"erreur": str(e)})
        contributeur = seance["contributeur"]
        if self.stockage.est_retire(contributeur):
            return _json(410, {"erreur": "identifiant retiré : en tirer un nouveau"})
        self.stockage.deposer(contributeur, seance)
        return _json(201, {"recu": n})

    def _retrait(self, environ):
        try:
            demande = self._corps_json(environ, 1024)
            schema._champs(demande, "retrait", {"contributeur"}, {"contributeur"})
            schema._texte(demande["contributeur"], "contributeur", schema.RE_CONTRIBUTEUR)
        except _Refus as r:
            return _json(r.statut, {"erreur": r.message})
        except schema.DonInvalide as e:
            return _json(400, {"erreur": str(e)})
        n = self.stockage.retirer(demande["contributeur"])
        return _json(202, {"retire": n})

    def _refus_admin(self, environ):
        """None si le jeton d'administration est bon, sinon la réponse de refus."""
        if not self.jeton_admin:
            return _json(404, {"erreur": "inconnu"})
        donne = environ.get("HTTP_AUTHORIZATION", "")
        attendu = "Bearer " + self.jeton_admin
        if not hmac.compare_digest(donne.encode("utf-8"), attendu.encode("utf-8")):
            statut, entetes, corps = _json(401, {"erreur": "jeton requis"})
            return statut, entetes + [("WWW-Authenticate", "Bearer")], corps
        return None

    def _mon_ip(self, environ):
        """Rend à l'appelant sa propre adresse telle que comptée, pour régler FIKA_DERRIERE_PROXY. Rien n'est gardé."""
        refus = self._refus_admin(environ)
        if refus:
            return refus
        relais = [a for a in environ.get("HTTP_X_FORWARDED_FOR", "").split(",") if a.strip()]
        return _json(200, {"ip": self._ip(environ), "adresses_relayees": len(relais)})

    def _export(self, environ):
        refus = self._refus_admin(environ)
        if refus:
            return refus
        requete = urllib.parse.parse_qs(environ.get("QUERY_STRING", ""))
        try:
            depuis = dt.datetime.fromisoformat(requete.get("depuis", ["1970-01-01T00:00:00+00:00"])[0])
        except ValueError:
            return _json(400, {"erreur": "depuis : date ISO 8601 attendue"})
        if depuis.tzinfo is None:
            depuis = depuis.replace(tzinfo=dt.timezone.utc)
        jusqua = stockage_mod.maintenant()
        dons = self.stockage.dons_depuis(depuis)
        retraits = self.stockage.retraits()

        def lignes():
            # Une ligne JSON par élément : la réponse se lit au fil de l'eau, quelle que soit sa taille.
            yield _ligne({"type": "export", "depuis": depuis.isoformat(), "jusqua": jusqua.isoformat()})
            for note in retraits:
                yield _ligne({"type": "retrait", **note})
            for cle, quand in dons:
                try:
                    seance = json.loads(self.stockage.lire(cle))
                except (FileNotFoundError, KeyError):
                    continue  # retiré entre-temps
                except Exception as e:  # noqa: BLE001 — S3 : NoSuchKey
                    if "NoSuchKey" in type(e).__name__ or "NoSuchKey" in str(e):
                        continue
                    raise
                yield _ligne(
                    {
                        "type": "don",
                        "cle": cle,
                        "recu": quand.isoformat(),
                        "contributeur": seance["contributeur"],
                        "seance": seance,
                    }
                )

        entetes = [("Content-Type", "application/x-ndjson; charset=utf-8"), ("Cache-Control", "no-store")]
        return "200 OK", entetes, lignes()


class _Refus(Exception):
    def __init__(self, statut: int, message: str):
        super().__init__(message)
        self.statut, self.message = statut, message


_RAISONS = {
    200: "OK", 201: "Created", 202: "Accepted", 400: "Bad Request", 401: "Unauthorized",
    404: "Not Found", 405: "Method Not Allowed", 410: "Gone", 411: "Length Required",
    413: "Content Too Large", 415: "Unsupported Media Type", 429: "Too Many Requests",
    500: "Internal Server Error",
}


def _ligne(objet) -> bytes:
    return (json.dumps(objet, ensure_ascii=False, separators=(",", ":")) + "\n").encode("utf-8")


def _json(code: int, objet):
    corps = json.dumps(objet, ensure_ascii=False).encode("utf-8")
    entetes = [
        ("Content-Type", "application/json; charset=utf-8"),
        ("Content-Length", str(len(corps))),
        ("Cache-Control", "no-store"),
        ("X-Content-Type-Options", "nosniff"),
    ]
    return f"{code} {_RAISONS[code]}", entetes, [corps]


def depuis_environnement() -> Recepteur:
    return Recepteur(
        stockage_mod.depuis_environnement(),
        jeton_admin=os.environ.get("FIKA_JETON_ADMIN") or None,
        debit=int(os.environ.get("FIKA_DEBIT", "30")),
        fenetre=float(os.environ.get("FIKA_FENETRE", "60")),
        derriere_proxy=int(os.environ.get("FIKA_DERRIERE_PROXY") or 0),
    )


def options_waitress(application: Recepteur) -> dict:
    return {
        # Garde-fou en plus de la vérification de l'application.
        "max_request_body_size": schema.TAILLE_MAX + 1024,
        "threads": 4,
        "ident": "fikajiana-dons",
        # Waitress efface X-Forwarded-For par défaut (clear_untrusted_proxy_headers = True) : derrière un
        # proxy de confiance, l'application en a besoin pour compter le débit par client (`_ip`).
        "clear_untrusted_proxy_headers": application.derriere_proxy == 0,
    }


def servir() -> None:
    import waitress

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
    application = depuis_environnement()
    waitress.serve(
        application,
        host=os.environ.get("FIKA_HOTE", "0.0.0.0"),
        port=int(os.environ.get("FIKA_PORT") or os.environ.get("PORT") or 8080),
        **options_waitress(application),
    )


if __name__ == "__main__":
    servir()
