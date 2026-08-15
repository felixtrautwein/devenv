#!/usr/bin/env bash
# Managed by https://github.com/felixtrautwein/devenv - run `devenv sync` to update.
#
# Runs INSIDE the container on every attach. Every step is optional so that the
# same script works for python, terraform, helm and embedded repositories alike.
set -euo pipefail
shopt -s nullglob globstar

# --- align the container identity with the host so bind mounts stay writable ---
if [[ -n "${HOST_UID:-}" && "${HOST_UID}" != "$(id -u)" ]]; then
    sudo usermod -u "${HOST_UID}" "${USER}"
    sudo chown -R "${HOST_UID}" "${HOME}"
fi

if [[ -n "${HOST_GID:-}" && "${HOST_GID}" != "$(id -g)" ]]; then
    sudo groupmod -g "${HOST_GID}" "${USER}"
    sudo chgrp -R "${HOST_GID}" "${HOME}"
fi

if [[ -n "${DOCKER_SOCK_GID:-}" ]]; then
    if getent group docker >/dev/null; then
        sudo groupmod -g "${DOCKER_SOCK_GID}" docker
    else
        sudo groupadd -g "${DOCKER_SOCK_GID}" docker
    fi
    sudo usermod -aG docker "${USER}"
fi

cd "${WORKSPACE_FOLDER}"

# direnv only trusts .envrc files below an explicit prefix.
mkdir -p "${HOME}/.config/direnv"
printf '[whitelist]\nprefix = [ "%s" ]\n' "${WORKSPACE_FOLDER}" \
    >"${HOME}/.config/direnv/config.toml"

# --- python environment ---
if [[ -f pyproject.toml ]]; then
    uv venv --allow-existing
    # shellcheck disable=SC1091
    source .venv/bin/activate
    if grep -q '^\[tool\.uv\.workspace\]' pyproject.toml; then
        uv sync --all-packages
    else
        uv sync
    fi
fi

# --- container registry login, only when a token is available ---
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    echo "${GITHUB_TOKEN}" |
        docker login ghcr.io -u "${GHCR_USER:-${USER}}" --password-stdin ||
        echo "ghcr.io login failed - continuing without it." >&2
fi

# --- git hooks ---
if [[ -f .pre-commit-config.yaml ]]; then
    if ! command -v pre-commit >/dev/null; then
        uv tool install pre-commit >/dev/null 2>&1 || true
    fi
    pre-commit install >/dev/null 2>&1 || true
fi

if [[ -f .gitattributes ]] && grep -q 'filter=lfs' .gitattributes; then
    git lfs install --local >/dev/null 2>&1 || true
fi

# --- repository specific hook ---
if [[ -x .devcontainer/postAttachCommand.local.sh ]]; then
    .devcontainer/postAttachCommand.local.sh
fi
