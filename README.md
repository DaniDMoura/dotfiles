# Dotfiles

Configurações pessoais para **Arch Linux** (nativo ou WSL) com **Omarchy**.

## Inclui

- **Shell:** Zsh + Starship
- **Editor:** Neovim (LazyVim-based)
- **Terminal:** Ghostty, Alacritty
- **Multiplexer:** Tmux
- **WM:** Hyprland + Waybar
- **Launcher:** Walker
- **Tema Omarchy:** Liquid Glass (custom)

## Instalação rápida

```bash
git clone https://github.com/seu-usuario/dotfiles.git ~/.dotfiles
~/.dotfiles/scripts/install.sh
```

## Uso diário

Depois de instalado, use o script de symlinks sempre que atualizar o repo:

```bash
~/.dotfiles/scripts/symlink.sh
```

## Estrutura

```
~/.dotfiles/
├── config/          # Symlinks para ~/.config/
├── home/            # Arquivos pontuais na ~
├── scripts/         # Automação
├── packages/        # Listas de pacotes
└── README.md
```

## Atenção

- O tema **Liquid Glass** está versionado em `config/omarchy/themes/liquid-glass/`.
- Outros temas do omarchy são gerenciados pelo próprio omarchy (`omarchy get <tema>`).
- O symlink interno do Neovim (`lua/plugins/theme.lua`) aponta para `~/.config/omarchy/current/theme/neovim.lua`.
