# syntax=docker/dockerfile:1
#
# Universal development image.
# Every capability is behind a build ARG so that slim variants can be produced
# from the same definition. See image/variants/*.env for the presets.

ARG PYTHON_VERSION=3.13
ARG DEBIAN_SUITE=bookworm

FROM python:${PYTHON_VERSION}-${DEBIAN_SUITE}

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000
ARG DOCKER_GID=999

ARG INSTALL_DOCKER=true
ARG INSTALL_GITHUB_CLI=true
ARG INSTALL_KUBERNETES=true
ARG INSTALL_CLOUD=true
ARG INSTALL_EMBEDDED=false
ARG EXTRA_APT_PACKAGES=""

ARG KUBERNETES_APT_MINOR=v1.34
ARG HELM_MAJOR=3
ARG HCLOUD_CLI_VERSION=v1.51.0

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Europe/Berlin \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

COPY scripts/ /tmp/devenv-scripts/

RUN chmod +x /tmp/devenv-scripts/*.sh && /tmp/devenv-scripts/apt-base.sh

RUN if [ "${INSTALL_DOCKER}" = "true" ]; then /tmp/devenv-scripts/install-docker.sh; fi

RUN if [ "${INSTALL_GITHUB_CLI}" = "true" ]; then /tmp/devenv-scripts/install-github-cli.sh; fi

RUN if [ "${INSTALL_KUBERNETES}" = "true" ]; then /tmp/devenv-scripts/install-kubernetes.sh; fi

RUN if [ "${INSTALL_CLOUD}" = "true" ]; then /tmp/devenv-scripts/install-cloud.sh; fi

RUN if [ "${INSTALL_EMBEDDED}" = "true" ]; then /tmp/devenv-scripts/install-embedded.sh; fi

RUN if [ -n "${EXTRA_APT_PACKAGES}" ]; then \
        apt-get update \
        && apt-get install -y --no-install-recommends ${EXTRA_APT_PACKAGES} \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/*; \
    fi

RUN /tmp/devenv-scripts/setup-user.sh && rm -rf /tmp/devenv-scripts

ENV USER=${USERNAME} \
    HOME=/home/${USERNAME} \
    USER_HOME=/home/${USERNAME}
ENV PATH=${HOME}/.local/bin:${PATH}

USER ${USERNAME}
WORKDIR /home/${USERNAME}

# uv is per-user; install it as the unprivileged user so upgrades work in-place.
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=${HOME}/.local/bin sh \
    && uv --version

CMD ["/bin/bash"]
