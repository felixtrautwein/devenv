# devenv

A single, reusable definition of a development environment: one universal
devcontainer image (plus slimmer variants) and the devcontainer template that
projects consume, so that tooling is defined once instead of being copy-pasted
into every repository.

## Layout

| Path | Purpose |
| --- | --- |
| `image/Dockerfile` | The universal image. Every capability is behind a build ARG. |
| `image/scripts/` | Install scripts invoked by the Dockerfile. |
| `image/variants/` | Build-arg presets defining the published tags. |
| `template/` | Files copied into consuming projects. |
| `bin/devenv` | CLI to build, push and distribute. |
| `.github/workflows/build-image.yml` | on-change build of all variants. |

## Image variants

Published to `ghcr.io/felixtrautwein/devenv:<variant>`.

| Tag | Contents |
| --- | --- |
| `web` (= `latest`) | `python` + kubectl, helm, terraform, hcloud, ansible |
| `python` | python + uv, docker cli, gh |
| `embedded` | `python` + platformio, clang, udev rules |

Every variant contains the shared base: Debian bookworm with CPython, `uv`,
git + git-lfs, gettext, direnv, zsh, ripgrep, jq, network debugging tools
(`nmap`, `net-tools`, `iputils-ping`), archive tools and `wireguard-tools`,
timezone `Europe/Berlin` and `LANG=C.UTF-8`.

## Usage in a project

```bash
/path/to/devenv/bin/devenv sync /path/to/your-project
```

This writes `.devcontainer/`, and - only if they do not exist yet -
`.devcontainer/Dockerfile`, `.vscode/settings.json` and
`.pre-commit-config.yaml`. Then reopen the project in the container.

Pick a slimmer image by setting `DEVENV_IMAGE` in `.devcontainer/.env`:

```dotenv
DEVENV_IMAGE=ghcr.io/felixtrautwein/devenv:python
```

Project-specific packages go into that project's `.devcontainer/Dockerfile`,
below the marker comment:

```dockerfile
ARG DEVENV_IMAGE=ghcr.io/felixtrautwein/devenv:web
FROM ${DEVENV_IMAGE}

# --- repository specific additions below ---
USER root
RUN apt-get update && apt-get install -y --no-install-recommends libpq-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
USER dev
```

Project-specific setup steps go into an executable
`.devcontainer/postAttachCommand.local.sh`, which the shared post-attach script
runs last.

## How the container is wired

- `initializeCommand.sh` runs on the host: it makes sure Docker is available,
  that the user is in the `docker` group, and generates `.devcontainer/.env`
  with `USER`, `WORKSPACE_FOLDER`, `HOST_UID`, `HOST_GID`, `DOCKER_SOCK_GID` and
  `COMPOSE_PROJECT_NAME`. Existing keys such as `DEVENV_IMAGE` are preserved.
- The image ships a fixed user `dev`. `postAttachCommand.sh` remaps its uid/gid
  to the host values and aligns the `docker` group with the host socket gid, so
  the shared image works on any machine while bind mounts stay writable.
- The project is mounted at its host path (`${localEnv:PWD}`), so file paths are
  identical inside and outside the container - stack traces, `direnv` whitelists
  and editor jumps all line up. `~/.cache` is a named volume
  (`devenv-cache-$USER`) that also holds the shell history.
- `postAttachCommand.sh` is capability-detecting: it runs `uv sync` only when a
  `pyproject.toml` exists (`--all-packages` for uv workspaces), installs
  pre-commit hooks only when `.pre-commit-config.yaml` exists, enables git-lfs
  only when `.gitattributes` uses it, and logs in to `ghcr.io` only when
  `GITHUB_TOKEN` is set (as `GHCR_USER`, defaulting to `$USER`).

## Building locally

```bash
bin/devenv doctor            # check host prerequisites
bin/devenv variants          # list variants
bin/devenv build web         # build locally into the docker daemon
bin/devenv push web python   # build and push to the registry
```

Set `DEVENV_REGISTRY` to publish the images somewhere else.

## Migration notes

`devenv sync` never overwrites an existing `.pre-commit-config.yaml`,
`.vscode/settings.json` or `.devcontainer/Dockerfile`. When migrating an
existing project, diff its files against `template/` and keep only the genuinely
project-specific parts.
