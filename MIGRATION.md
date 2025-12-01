# Migration Guide: v1.x to v2.0

## Overview

Marko.nvim v2.0 represents a complete rewrite that leverages Neovim's native ShaDa system instead of custom YAML configuration files. This provides better reliability, simpler code, and tighter integration with Neovim.

## Breaking Changes

### Configuration File Format
- **Old**: Custom YAML file at `~/.local/share/nvim/marko/config.yaml`
- **New**: Native ShaDa files at `~/.local/state/nvim/marko/marko_<project_id>.shada`

### Commands Removed
- `:MarkoReload` - No longer needed (ShaDa handles reloading automatically)
- `:MarkoDeleteConfig` - Replaced by `:MarkoClean`
- `:MarkoDebug` - Replaced by `:MarkoInfo`

### Commands Added
- `:MarkoInfo` - Display current project info and marks
- `:MarkoList` - List all project ShaDa files
- `:MarkoClean` - Delete ShaDa for current project

### Commands Changed
- `:MarkoSave` - Now saves ShaDa instead of YAML config

## What You Need to Do

### 1. Update Your Configuration (Optional)

The default configuration still works:

```lua
require("marko").setup()
```

If you had custom options, only `debug` is still supported:

```lua
require("marko").setup({
  debug = true  -- Enable verbose logging
})
```

### 2. Your Old Marks

Your old marks in `~/.local/share/nvim/marko/config.yaml` are **not automatically migrated**. 

To preserve important marks:
1. Before upgrading, note down your important marks using `:MarkoDebug`
2. After upgrading, manually recreate them using `mA`, `mB`, etc. or `:MarkoMark A`

### 3. Clean Up (Optional)

After upgrading, you can safely delete the old config directory:

```bash
rm -rf ~/.local/share/nvim/marko/
```

## Benefits of v2.0

1. **More Reliable**: Uses Neovim's battle-tested ShaDa system
2. **No Race Conditions**: No longer fights with Neovim's startup/shutdown
3. **Simpler Code**: 70% less code, easier to maintain
4. **Better Isolation**: Each project is truly independent
5. **Native Integration**: Works WITH Neovim instead of against it

## Side Effects (Features!)

Because v2.0 uses project-specific ShaDa files, the following are also isolated per project:
- Command history
- Search history  
- Registers
- Jump list
- Buffer list

This is intentional and helps keep your projects truly separate!

## Troubleshooting

### Marks not persisting?
- Check `:MarkoInfo` to see the ShaDa file path
- Make sure the directory `~/.local/state/nvim/marko/` is writable
- Try `:MarkoSave` to manually save

### Want global ShaDa for some projects?
You can always start Neovim without marko for projects where you want the global ShaDa:
```bash
nvim --clean  # Uses default ShaDa
```

## Questions?

Open an issue at: https://github.com/mohseenrm/marko.nvim/issues
