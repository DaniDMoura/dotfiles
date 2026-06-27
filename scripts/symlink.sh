#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Dotfiles Symlink Manager
# =============================================================================
# Cria ou atualiza symlinks de ~/.dotfiles/config/* → ~/.config/*
# e arquivos pontuais na home.
#
# Uso: ./scripts/symlink.sh
# =============================================================================

DOTFILES_DIR="${HOME}/.dotfiles"
CONFIG_DIR="${HOME}/.config"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_err()   { echo -e "${RED}[ERR]${NC}   $1"; }

# ---------------------------------------------------------------------------
# Backup de um path existente (arquivo ou diretório)
# ---------------------------------------------------------------------------
backup_item() {
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    local backup="${target}.bak.$(date +%s)"
    log_warn "Fazendo backup de $(basename "$target") → $(basename "$backup")"
    mv "$target" "$backup"
  fi
}

# ---------------------------------------------------------------------------
# Cria symlink seguro
# ---------------------------------------------------------------------------
safe_link() {
  local src="$1"
  local dst="$2"

  if [[ -L "$dst" ]]; then
    local current_src
    current_src="$(readlink "$dst" || true)"
    if [[ "$current_src" == "$src" ]]; then
      log_ok "Já linkado: $(basename "$dst")"
      return
    else
      log_warn "Symlink diferente detectado: $(basename "$dst")"
      backup_item "$dst"
    fi
  elif [[ -e "$dst" ]]; then
    backup_item "$dst"
  fi

  ln -s "$src" "$dst"
  log_ok "Linkado: $(basename "$dst")"
}

# ---------------------------------------------------------------------------
# Linka tudo dentro de config/
# ---------------------------------------------------------------------------
link_configs() {
  log_info "Linkando configs de ~/.dotfiles/config → ~/.config ..."

  for item in "$DOTFILES_DIR"/config/*; do
    [[ -e "$item" ]] || continue
    local name
    name=$(basename "$item")
    safe_link "$item" "${CONFIG_DIR}/${name}"
  done
}

# ---------------------------------------------------------------------------
# Linka arquivos pontuais na home
# ---------------------------------------------------------------------------
link_home() {
  log_info "Linkando arquivos da home ..."

  # .zshrc aponta para ~/.config/zsh/.zshrc (que está symlinkado)
  if [[ -L "${CONFIG_DIR}/zsh/.zshrc" || -e "${CONFIG_DIR}/zsh/.zshrc" ]]; then
    safe_link "${CONFIG_DIR}/zsh/.zshrc" "${HOME}/.zshrc"
  fi

  # .bashrc
  if [[ -e "${DOTFILES_DIR}/home/.bashrc" ]]; then
    safe_link "${DOTFILES_DIR}/home/.bashrc" "${HOME}/.bashrc"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  log_info "Iniciando symlink manager ..."

  if [[ ! -d "$DOTFILES_DIR" ]]; then
    log_err "Diretório ~/.dotfiles não encontrado!"
    exit 1
  fi

  mkdir -p "$CONFIG_DIR"
  link_configs
  link_home

  log_info "Concluído! Reinicie o shell ou faça logout/login para aplicar tudo."
}

main "$@"
