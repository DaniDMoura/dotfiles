# Dotfiles

Config pessoal para Omarchy, também compativel com WSL usando Arch Linux como distro. Inclui Zsh + Starship, Neovim (LazyVim-based), Ghostty, Alacritty, Tmux, Hyprland e Opencode.

## Instalação 

```bash
git clone https://github.com/seu-usuario/dotfiles.git ~/.dotfiles
~/.dotfiles/scripts/install.sh
```

## Sincronizar

Depois de instalado, use o script de symlinks sempre que atualizar o repo:

```bash
~/.dotfiles/scripts/symlink.sh
```

## Atenção

- O tema **Liquid Glass** está versionado em `config/omarchy/themes/liquid-glass/`.
- Outros temas do omarchy são gerenciados pelo próprio omarchy (`omarchy get <tema>`).
- O symlink interno do Neovim (`lua/plugins/theme.lua`) aponta para `~/.config/omarchy/current/theme/neovim.lua`.
