ARG DEVENV_IMAGE=ghcr.io/felixtrautwein/devenv:web
FROM ${DEVENV_IMAGE}

# devenv maintains its own images, so it needs the linters used by CI.
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends shellcheck \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
USER dev
