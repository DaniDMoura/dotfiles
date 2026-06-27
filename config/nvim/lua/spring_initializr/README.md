# spring-initializr.nvim

Create Spring Boot projects inside Neovim via [start.spring.io](https://start.spring.io).

## Requirements

- Neovim >= 0.10
- `curl`, `unzip`
- Optional: [snacks.nvim](https://github.com/folke/snacks.nvim) or [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) for dependency picker

## Installation (LazyVim)

Already registered in `lua/plugins/spring-initializr.lua`.

## Commands

| Command | Description |
|---------|-------------|
| `:SpringNew` | Full wizard |
| `:SpringNew com.group:artifact` | Quick mode — coordinates from args, rest from wizard |
| `:SpringRefreshMetadata` | Refresh metadata cache |
| `:SpringClearCache` | Clear metadata cache |

## `:SpringNew` Full Wizard

1. **Project type** — Maven, Gradle Groovy, Gradle Kotlin
2. **Language** — Java, Kotlin, Groovy
3. **Java version** — defaults pre-selected from your last choice
4. **Coordinates** — `group:artifact` format (e.g. `com.danilo:my-app`)
5. **Dependencies** — fuzzy search with "Recent" section at top + live counter
6. **Destination** — current directory or custom path

Spring Boot version is auto-detected (latest stable, no SNAPSHOT).

## `:SpringNew com.group:artifact` Quick Mode

- Group + Artifact from the argument
- Still asks: Project type, Language, Java version, Dependencies, Destination
- Uses your saved preferences as defaults

## Dependency Picker Keys

- `<Tab>` / `<Space>` → toggle selection
- `<CR>` → confirm and close
- `<Esc>` → cancel

The picker shows your **recently used dependencies** at the top for quick access, and displays a **live counter** of selected items in the title.

## Configuration

```lua
require("spring_initializr").setup({
  auto_open = "ask",          -- "ask", true (auto open), false (never open)
  download_timeout = 60000,
  background_refresh = false, -- silently refresh metadata on startup
})
```

## Preferences

Your last choices (project type, language, java version, group id, recent dependencies) are automatically saved in Neovim's cache directory. The next time you run `:SpringNew`, defaults are pre-filled from your previous session.

## Architecture

```
lua/spring_initializr/
  init.lua       -- setup, commands, wizard, generator
  metadata.lua   -- Spring Initializr API client + cache
  ui.lua         -- dependency picker (Snacks / Telescope / vim.ui)
  util.lua       -- async coroutines, prefs persistence, helpers
```

- **No callback hell** — wizard uses Lua coroutines for sequential async flow
- **No global state**
- **Async by default** (`vim.system`)
- **Metadata cached** for 24h in `stdpath("cache")`
- **Invalid cache auto-deleted** — if cache is corrupted, it's removed automatically
