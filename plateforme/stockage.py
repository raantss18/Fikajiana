"""Où vont les dons : un dossier, ou un stockage objet compatible S3 (au choix par variable d'environnement).

Rangement, identique dans les deux cas :
  dons/<contributeur>/<AAAAMMJJTHHMMSSffffffZ>-<hasard>.json   une séance reçue, telle que vérifiée
  retraits/<contributeur>.json                                  {"contributeur": …, "date": …}
Le contributeur est dans le chemin : un retrait efface un seul préfixe.
"""

from __future__ import annotations

import datetime as dt
import json
import os
import pathlib
import secrets
import tempfile

FORMAT_DATE = "%Y%m%dT%H%M%S%fZ"


def maintenant() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def date_de_cle(cle: str) -> dt.datetime:
    """Date de réception lue dans le nom du fichier."""
    nom = cle.rsplit("/", 1)[-1]
    return dt.datetime.strptime(nom.split("-", 1)[0], FORMAT_DATE).replace(tzinfo=dt.timezone.utc)


def nouvelle_cle(contributeur: str, quand: dt.datetime) -> str:
    return f"dons/{contributeur}/{quand.strftime(FORMAT_DATE)}-{secrets.token_hex(6)}.json"


class Stockage:
    """Interface commune : quelques opérations sur des objets nommés par une clé."""

    def ecrire(self, cle: str, octets: bytes) -> None: ...
    def lire(self, cle: str) -> bytes: ...
    def existe(self, cle: str) -> bool: ...
    def lister(self, prefixe: str) -> list[str]: ...
    def effacer(self, cle: str) -> None: ...

    # Opérations du récepteur, écrites une fois pour les deux stockages.

    def deposer(self, contributeur: str, seance: dict, quand: dt.datetime | None = None) -> str:
        cle = nouvelle_cle(contributeur, quand or maintenant())
        self.ecrire(cle, json.dumps(seance, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))
        return cle

    def est_retire(self, contributeur: str) -> bool:
        return self.existe(f"retraits/{contributeur}.json")

    def retirer(self, contributeur: str, quand: dt.datetime | None = None) -> int:
        """Efface tous les dons de `contributeur` et note le retrait (pour les exports futurs)."""
        note = {"contributeur": contributeur, "date": (quand or maintenant()).isoformat()}
        # La note d'abord : un don qui arriverait pendant l'effacement sera refusé.
        self.ecrire(f"retraits/{contributeur}.json", json.dumps(note).encode("utf-8"))
        cles = self.lister(f"dons/{contributeur}/")
        for cle in cles:
            self.effacer(cle)
        return len(cles)

    def dons_depuis(self, depuis: dt.datetime):
        """(clé, date) des dons reçus à partir de `depuis`, du plus ancien au plus récent."""
        trouves = []
        for cle in self.lister("dons/"):
            try:
                quand = date_de_cle(cle)
            except ValueError:
                continue
            if quand >= depuis:
                trouves.append((cle, quand))
        return sorted(trouves, key=lambda c: (c[1], c[0]))

    def retraits(self) -> list[dict]:
        notes = []
        for cle in self.lister("retraits/"):
            notes.append(json.loads(self.lire(cle)))
        return sorted(notes, key=lambda n: (n["date"], n["contributeur"]))


class StockageDossier(Stockage):
    def __init__(self, racine: str | os.PathLike):
        self.racine = pathlib.Path(racine).resolve()
        self.racine.mkdir(parents=True, exist_ok=True)

    def _chemin(self, cle: str) -> pathlib.Path:
        chemin = (self.racine / cle).resolve()
        if self.racine not in chemin.parents:
            raise ValueError("clé hors du dossier")
        return chemin

    def ecrire(self, cle, octets):
        chemin = self._chemin(cle)
        chemin.parent.mkdir(parents=True, exist_ok=True)
        # Écriture atomique : jamais de fichier à moitié écrit dans un export.
        fd, tmp = tempfile.mkstemp(dir=chemin.parent, prefix=".tmp-")
        try:
            with os.fdopen(fd, "wb") as f:
                f.write(octets)
            os.replace(tmp, chemin)
        except BaseException:
            pathlib.Path(tmp).unlink(missing_ok=True)
            raise

    def lire(self, cle):
        return self._chemin(cle).read_bytes()

    def existe(self, cle):
        return self._chemin(cle).is_file()

    def lister(self, prefixe):
        base = self._chemin(prefixe.rstrip("/")) if prefixe.strip("/") else self.racine
        if not base.is_dir():
            return []
        return sorted(
            p.relative_to(self.racine).as_posix()
            for p in base.rglob("*.json")
            if p.is_file() and not p.name.startswith(".")
        )

    def effacer(self, cle):
        chemin = self._chemin(cle)
        chemin.unlink(missing_ok=True)
        try:
            chemin.parent.rmdir()  # le dossier du contributeur, s'il est vide
        except OSError:
            pass


class StockageS3(Stockage):
    """Tout service compatible S3 (AWS S3, Cloudflare R2, MinIO, Garage…), par boto3."""

    def __init__(self, seau: str, prefixe: str = "", client=None):
        if client is None:
            import boto3  # dépendance facultative : seulement si l'on choisit S3

            client = boto3.client(
                "s3",
                endpoint_url=os.environ.get("FIKA_S3_ADRESSE") or None,
                region_name=os.environ.get("FIKA_S3_REGION") or None,
            )
        self.client = client
        self.seau = seau
        self.prefixe = prefixe.strip("/") + "/" if prefixe.strip("/") else ""

    def ecrire(self, cle, octets):
        self.client.put_object(
            Bucket=self.seau, Key=self.prefixe + cle, Body=octets, ContentType="application/json"
        )

    def lire(self, cle):
        return self.client.get_object(Bucket=self.seau, Key=self.prefixe + cle)["Body"].read()

    def existe(self, cle):
        reponse = self.client.list_objects_v2(Bucket=self.seau, Prefix=self.prefixe + cle, MaxKeys=1)
        return any(o["Key"] == self.prefixe + cle for o in reponse.get("Contents", []))

    def lister(self, prefixe):
        cles, suite = [], None
        while True:
            args = {"Bucket": self.seau, "Prefix": self.prefixe + prefixe}
            if suite:
                args["ContinuationToken"] = suite
            reponse = self.client.list_objects_v2(**args)
            cles += [o["Key"][len(self.prefixe) :] for o in reponse.get("Contents", [])]
            if not reponse.get("IsTruncated"):
                return sorted(c for c in cles if c.endswith(".json"))
            suite = reponse["NextContinuationToken"]

    def effacer(self, cle):
        self.client.delete_object(Bucket=self.seau, Key=self.prefixe + cle)


def depuis_environnement() -> Stockage:
    """`FIKA_S3_SEAU` choisit S3 ; sinon le dossier `FIKA_DOSSIER` (par défaut `./dons-recus`)."""
    seau = os.environ.get("FIKA_S3_SEAU")
    if seau:
        return StockageS3(seau, os.environ.get("FIKA_S3_PREFIXE", ""))
    return StockageDossier(os.environ.get("FIKA_DOSSIER", "dons-recus"))
