#!/usr/bin/env bash
# Managed by https://github.com/felixtrautwein/devenv - run `devenv sync` to update.
#
# Runs on the HOST before the container is created. Must stay idempotent and must
# not require a pre-existing devcontainer.
set -euo pipefail
trap exit INT

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="${repository_root}/.devcontainer/.env"

# Files the compose file bind-mounts read-only; they must exist on the host.
touch "${HOME}/.netrc"
mkdir -p "${HOME}/.ssh"

if ! command -v docker >/dev/null; then
    echo "docker is not installed - see https://docs.docker.com/engine/install/" >&2
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "Docker is not running. Starting it..."
    sudo service docker start
fi

if ! id -nG "${USER}" | grep -qw docker; then
    echo "Adding ${USER} to the docker group (log out and back in to take effect)..."
    sudo usermod -aG docker "${USER}"
fi

# Preserve manual overrides (e.g. DEVENV_IMAGE, GITHUB_TOKEN) already in .env.
# WORKSPACE_FOLDER mirrors the host path inside the container so that
# ${localEnv:PWD} in devcontainer.json and the compose bind mount agree.
declare -A managed=(
    [USER]="${USER}"
    [WORKSPACE_FOLDER]="${repository_root}"
    [HOST_UID]="$(id -u)"
    [HOST_GID]="$(id -g)"
    [DOCKER_SOCK_GID]="$(stat -c '%g' /var/run/docker.sock)"
    [COMPOSE_PROJECT_NAME]="devcontainer-${USER}-$(basename "${repository_root}")"
)

touch "${env_file}"
for key in "${!managed[@]}"; do
    value="${managed[${key}]}"
    if grep -q "^${key}=" "${env_file}"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "${env_file}"
    else
        echo "${key}=${value}" >>"${env_file}"
    fi
done

grep -q '^DEVENV_IMAGE=' "${env_file}" ||
    echo "DEVENV_IMAGE=ghcr.io/felixtrautwein/devenv:web" >>"${env_file}"

# `docker compose build` never refreshes an already present base image tag, so a
# stale (or locally built) DEVENV_IMAGE would silently be reused forever.
# Set DEVENV_SKIP_PULL=1 in .env when DEVENV_IMAGE is built locally on purpose.
devenv_image="$(sed -n 's/^DEVENV_IMAGE=//p' "${env_file}" | tail -1)"
skip_pull="$(sed -n 's/^DEVENV_SKIP_PULL=//p' "${env_file}" | tail -1)"
if [[ -z "${skip_pull}" || "${skip_pull}" == "0" ]]; then
    echo "Pulling ${devenv_image}..."
    docker pull "${devenv_image}" ||
        echo "Pull failed - falling back to the local copy of ${devenv_image}." >&2
fi
