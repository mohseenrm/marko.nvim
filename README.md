# marko.nvim

[![Tests](https://github.com/mohseenrm/marko.nvim/actions/workflows/tests.yaml/badge.svg)](https://github.com/mohseenrm/marko.nvim/actions/workflows/tests.yaml)
[![Lint](https://github.com/mohseenrm/marko.nvim/actions/workflows/lint.yaml/badge.svg)](https://github.com/mohseenrm/marko.nvim/actions/workflows/lint.yaml)

A project-aware global marks manager for Neovim. Marko automatically isolates global marks per project using Neovim's native ShaDa (shared data) system, ensuring marks from different projects don't interfere with each other.

## Features ✨

- **Project-Scoped Global Marks**: Each project directory gets its own isolated set of global marks
- **Persistent Global Marks**: Marks are automatically saved when you exit Neovim and restored when you return to the same project
- **Leverages Native ShaDa**: Works with Neovim's built-in shared data system
- **Zero Configuration**: Just install and it works automatically
- **Simple Commands**: Easy-to-use commands for managing and inspecting your marks

## Installation 🚀

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  "mohseenrm/marko.nvim",
  priority = 1000,
  lazy = false,
  config = function()
    require("marko").setup()
  end
}
```

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "mohseenrm/marko.nvim",
  priority = 1000,
  lazy = false,
  config = function()
    require("marko").setup()
  end
}
```

Or with configuration options using lazy.nvim's `opts` feature:

```lua
{
  "mohseenrm/marko.nvim",
  priority = 1000,
  lazy = false,
  opts = {
    debug = false  -- Set to true for verbose logging
  }
}
```

The `opts` table will be automatically passed to the setup function by lazy.nvim.

## Usage 🪝

### Setting Marks

Marko works with Neovim's uppercase global marks (A-Z). Set marks as you normally would:

```
mA  # Set mark A at current cursor position
mB  # Set mark B at current cursor position
```

### Navigating to Marks

Navigate to marks using the standard Neovim commands:

```
'A  # Jump to the line of mark A
`A  # Jump to the exact position of mark A
```

### Commands

Marko provides the following commands:

- `:MarkoInfo` - Display current project directory, ShaDa file location, and all active global marks
- `:MarkoList` - List all project-specific ShaDa files managed by Marko
- `:MarkoClean` - Delete the ShaDa file for current project (clears all marks, with confirmation)
- `:MarkoSave` - Manually save ShaDa for the current project
- `:MarkoMark {A-Z}` - Set a global mark at the current cursor position (e.g., `:MarkoMark A` sets mark A)

### Configuration

Setup with default options:

```lua
require("marko").setup()
```

Setup with custom options:

```lua
require("marko").setup({
  debug = false  -- Set to true for verbose logging
})
```

## How It Works

Marko leverages Neovim's native ShaDa (shared data) system to isolate marks per project. When you start Neovim:

1. Marko detects your current working directory (absolute path)
2. Sets Neovim's `shadafile` option to a project-specific ShaDa file in `~/.local/state/nvim/marko/`
3. Loads the ShaDa file for that project, restoring all marks from your last session

When you exit Neovim:

1. Neovim automatically saves the current state (marks, registers, history) to the project-specific ShaDa file
2. Next time you open that project, your marks are exactly as you left them

**Key benefit**: Each project directory has completely isolated marks. Opening project A won't show marks from project B, and vice versa. This works with Neovim's native systems instead of trying to override them.

## Features Explained

### Project-Based Isolation

Each project (identified by its absolute working directory path) gets its own ShaDa file stored in `~/.local/state/nvim/marko/`. The filename is generated from the project path to ensure uniqueness.

For example:

- `/home/user/projects/app1` → `~/.local/state/nvim/marko/marko__home_user_projects_app1.shada`
- `/home/user/projects/app2` → `~/.local/state/nvim/marko/marko__home_user_projects_app2.shada`

### ShaDa Files

ShaDa files are Neovim's native format for storing session data. They use MessagePack encoding and handle merging, timestamps, and error recovery automatically. By using ShaDa, Marko benefits from all of Neovim's built-in persistence features without reinventing the wheel.

## Development

Want to contribute to marko.nvim? Here's how to set up your local development environment:

### Prerequisites

- Neovim (version 0.7.0 or higher)
- Lua (5.1 or higher)

### Setup

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/yourusername/marko.nvim
   cd marko.nvim
   ```

### Plugin Structure

- `lua/marko/init.lua`: Main entry point, ShaDa management
- `lua/marko/globals.lua`: Global variable definitions for luacheck
- `plugin/init.lua`: Plugin initialization
- `tests/`: Test suite (needs updating for new approach)

### Running Tests

Tests are written in a simple test framework:

```bash
# Run the full test suite
lua tests/run.lua
```

**Note**: Tests need to be updated to reflect the new ShaDa-based approach.

### Linting

The project uses `luacheck` for static code analysis:

```bash
# Install luacheck via LuaRocks
luarocks install luacheck
export PATH=~/.luarocks/bin:$PATH

# Run luacheck on the entire project
luacheck lua/

# Run luacheck on a specific file
luacheck lua/marko/init.lua
```

Luacheck configuration is managed via the `.luacheckrc` file at the project root.

### Guidelines for Contributing

1. **Create a Feature Branch**: Always work on a feature branch, not directly on `main`
2. **Follow Code Style**: Match the existing style (snake_case for functions and variables, tabs for indentation)
3. **Add Tests**: Add tests for any new functionality
4. **Test Before Pushing**: Run the test suite before submitting a PR
5. **Document Changes**: Update this README.md if adding new features or changing behavior

### Testing Your Changes Locally

To test the plugin in your Neovim environment while developing:

#### With packer.nvim:

```lua
use {
  "~/path/to/marko.nvim",
  config = function()
    require("marko").setup({
      debug = true -- Enable debug logging during development
    })
  end
}
```

Then run `:PackerSync` to load the local version

#### With lazy.nvim:

```lua
{
  dir = "~/path/to/marko.nvim",
  dev = true,
  priority = 1000,
  lazy = false,
  opts = {
    debug = true -- Enable debug logging during development
  }
}
```

Then restart Neovim or run `:Lazy sync` to load the local version

### Debugging

Set the `debug` option to `true` in your setup to enable verbose logging:

```lua
require("marko").setup({
  debug = true
})
```

Messages will be displayed using `vim.notify()` and can be viewed in Neovim.

## License

MIT
