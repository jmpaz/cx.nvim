# cx.nvim

Neovim integration for [`contextualize`](https://github.com/jmpaz/contextualize).

`cx.nvim` currently:
- reads `contextualize`'s context registry,
- opens authored manifest sources from generated context files,
- and exposes optional picker/file-manager integrations.

## Install

Install this repository as a normal Neovim plugin (`contextualize` must be on `PATH`).

```lua
require('cx').setup()
```

## Commands

- `:CxContexts` browses registered contexts.
- `:CxManifests` aliases `:CxContexts`.
- `:CxSource` opens the manifest source for the current generated context file.
- `:CxSourceVsplit` opens the source in a vertical split.

## Telescope

```lua
require('telescope').load_extension('cx')
require('telescope').extensions.cx.contexts()
```

## mini.files

```lua
require('cx').setup({
  integrations = {
    mini_files = true,
  },
})
```

The default mini.files mapping is `gd`.
