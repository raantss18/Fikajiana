# Récepteur des dons d'écriture de Fikajiana (ADR 0042).
# Construire depuis la racine du dépôt : docker build -f plateforme/Dockerfile -t fikajiana-dons .
# --build-arg S3=0 : sans boto3, si les dons restent sur le disque (image plus petite).

FROM python:3.13-slim AS construction
COPY --from=ghcr.io/astral-sh/uv:0.10.12 /uv /usr/local/bin/uv
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy UV_PROJECT_ENVIRONMENT=/app/.venv
WORKDIR /app/plateforme
COPY plateforme/pyproject.toml plateforme/uv.lock ./
ARG S3=1
# Les versions exactes du verrou (Waitress, boto3), sans les outils de test.
RUN uv sync --locked --no-dev $( [ "$S3" = 1 ] && echo --extra s3 ) --no-install-project

FROM python:3.13-slim
COPY --from=construction /app/.venv /app/.venv
COPY collecte/classes.txt /app/collecte/classes.txt
WORKDIR /app/plateforme
COPY plateforme/schema.py plateforme/stockage.py plateforme/recepteur.py ./
# Utilisateur sans droits ; seuls les dons sont écrits, dans /donnees.
RUN useradd --system --uid 10001 --no-create-home dons && mkdir /donnees && chown dons /donnees
USER dons
ENV FIKA_DOSSIER=/donnees PATH=/app/.venv/bin:$PATH PYTHONUNBUFFERED=1
VOLUME /donnees
EXPOSE 8080
HEALTHCHECK --interval=60s --timeout=5s CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/v1/sante', timeout=4)"]
CMD ["python", "recepteur.py"]
