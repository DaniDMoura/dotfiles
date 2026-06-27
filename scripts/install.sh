#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Dotfiles Install Script
# =============================================================================
# Setup completo para uma máquina nova rodando Arch Linux (nativo ou WSL).
#
# Uso: curl -fsSL <url> | bash
#   ou: git clone <repo> ~/.dotfiles && ~/.dotfiles/scripts/install.sh
# =============================================================================

DOTFILES_DIR="${HOME}/.dotfiles"
REPO_URL="https://github.com/seu-usuario/dotfiles.git"  # <-- edite aqui

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_err()   { echo -e "${RED}[ERR]${NC}   $1"; }

# ---------------------------------------------------------------------------
# Detecta distro
# ---------------------------------------------------------------------------
detect_distro() {
  if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    echo "$ID"
  else
    echo "unknown"
  fi
}

# ---------------------------------------------------------------------------
# Instala pacotes no Arch
# ---------------------------------------------------------------------------
install_arch_packages() {
  log_info "Instalando pacotes no Arch Linux ..."

  local pkg_file="${DOTFILES_DIR}/packages/arch.txt"
  if [[ ! -f "$pkg_file" ]]; then
    log_err "Arquivo de pacotes não encontrado: ${pkg_file}"
    exit 1
  fi

  # Lê pacotes, ignora comentários e linhas vazias
  local packages
  packages=$(grep -v '^#' "$pkg_file" | grep -v '^$' | tr '\n' ' ')

  # Atualiza e instala
  sudo pacman -Syu --noconfirm
  # shellcheck disable=SC2086
  sudo pacman -S --needed --noconfirm ${packages}

  log_ok "Pacotes instalados."
}

# ---------------------------------------------------------------------------
# Clona o repositório
# ---------------------------------------------------------------------------
clone_dotfiles() {
  if [[ -d "$DOTFILES_DIR" ]]; then
    log_warn "~/.dotfiles já existe. Pulando clone."
    return
  fi

  log_info "Clonando dotfiles ..."
  git clone "$REPO_URL" "$DOTFILES_DIR"
  log_ok "Dotfiles clonados."
}

# ---------------------------------------------------------------------------
# Configura shell padrão
# ---------------------------------------------------------------------------
set_default_shell() {
  if [[ "$SHELL" == */zsh ]]; then
    log_ok "Zsh já é o shell padrão."
    return
  fi

  if ! command -v zsh &>/dev/null; then
    log_warn "zsh não encontrado. Pulando troca de shell."
    return
  fi

  log_info "Alterando shell padrão para zsh ..."
  chsh -s "$(command -v zsh)"
  log_ok "Shell alterado. Faça logout e login novamente para aplicar."
}

# ---------------------------------------------------------------------------
# Instala omarchy (se desejado)
# ---------------------------------------------------------------------------
install_omarchy() {
  if [[ -d "$HOME/.local/share/omarchy" ]]; then
    log_ok "Omarchy já parece estar instalado."
    return
  fi

  log_info "Instalando omarchy ..."
  bash <(curl -fsSL https://omarchy.org/install)
  log_ok "Omarchy instalado."
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  echo -e "${GREEN}"
  echo "╔═══════════════════════════════════════╗"
  echo "║      Dotfiles Setup - Arch Linux      ║"
  echo "╚═══════════════════════════════════════╝"
  echo -e "${NC}"

  local distro
  distro=$(detect_distro)

  if [[ "$distro" != "arch" && "$distro" != "archlinux" ]]; then
    log_warn "Distro detectada: ${distro}. Este script foi testado no Arch Linux."
    read -rp "Continuar mesmo assim? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || exit 0
  fi

  clone_dotfiles
  install_arch_packages
  install_omarchy

  log_info "Criando symlinks ..."
  bash "${DOTFILES_DIR}/scripts/symlink.sh"

  set_default_shell

  echo
  echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}  Setup concluído! Reinicie o terminal ou faça login   ${NC}"
  echo -e "${GREEN}  novamente para carregar todas as configurações.       ${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
}

main "$@"
