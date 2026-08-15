#!/usr/bin/env bash
# Create the unprivileged devcontainer user.
#
# The image is built once and shared, so the account name is fixed (default
# "dev"). The host uid/gid and the docker socket gid are remapped at attach time
# by .devcontainer/postAttachCommand.sh, because they differ per machine.
set -euo pipefail

groupadd -g "${USER_GID}" "${USERNAME}"
useradd -s /bin/bash -u "${USER_UID}" -g "${USER_GID}" -m "${USERNAME}"

echo "${USERNAME} ALL=(root) NOPASSWD:ALL" >"/etc/sudoers.d/${USERNAME}"
chmod 0440 "/etc/sudoers.d/${USERNAME}"

if ! getent group docker >/dev/null; then
    groupadd -g "${DOCKER_GID}" docker
fi
usermod -aG docker "${USERNAME}"
# Serial/USB access for the embedded workflows; the groups may not exist yet.
for group in dialout plugdev; do
    getent group "${group}" >/dev/null || groupadd "${group}"
    usermod -aG "${group}" "${USERNAME}"
done

user_home="/home/${USERNAME}"
install -d -o "${USERNAME}" -g "${USERNAME}" \
    "${user_home}/.cache" \
    "${user_home}/.local/bin" \
    "${user_home}/.config/direnv" \
    "${user_home}/.ssh"

# History lives in the cache volume so it survives container rebuilds.
cat >>"${user_home}/.bashrc" <<'EOF'

# --- devenv ---
export HISTFILE="${HOME}/.cache/.bash_history"
export HISTSIZE=100000
export HISTFILESIZE=100000
shopt -s histappend
export PATH="${HOME}/.local/bin:${PATH}"
# The workspace is bind-mounted at its host path, so activate by location.
if [ -d "${PWD}/.venv" ]; then
    export VIRTUAL_ENV="${PWD}/.venv"
    export PATH="${VIRTUAL_ENV}/bin:${PATH}"
fi
command -v direnv >/dev/null && eval "$(direnv hook bash)"
command -v uv >/dev/null && eval "$(uv generate-shell-completion bash)" 2>/dev/null || true
EOF

cat >"${user_home}/.zshrc" <<'EOF'
export HISTFILE="${HOME}/.cache/.zsh_history"
export HISTSIZE=100000
export SAVEHIST=100000
setopt SHARE_HISTORY
export PATH="${HOME}/.local/bin:${PATH}"
if [ -d "${PWD}/.venv" ]; then
    export VIRTUAL_ENV="${PWD}/.venv"
    export PATH="${VIRTUAL_ENV}/bin:${PATH}"
fi
command -v direnv >/dev/null && eval "$(direnv hook zsh)"
autoload -Uz compinit && compinit -d "${HOME}/.cache/.zcompdump"
PROMPT='%F{cyan}%n%f@%F{green}%m%f %F{yellow}%~%f %# '
EOF

chown -R "${USERNAME}:${USERNAME}" "${user_home}"
