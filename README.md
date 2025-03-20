# marko.nvim

[![Tests](https://github.com/mohseenrm/marko.nvim/actions/workflows/tests.yml/badge.svg)](https://github.com/mohseenrm/marko.nvim/actions/workflows/tests.yml)
[![Lint](https://github.com/mohseenrm/marko.nvim/actions/workflows/lint.yml/badge.svg)](https://github.com/mohseenrm/marko.nvim/actions/workflows/lint.yml)

A behind the scene global marks manager for Neovim. Marko saves and restores your global marks for each project directory, so they persist across Neovim sessions and are properly isolated between projects.

## Features ✨

- **Project-Scoped Global Marks**: Only see global marks that belong to your current working directory
- **Persistent Global Marks**: Global Marks are automatically saved when you exit Neovim and restored when you return
- **Proper File type Detection**: Ensures buffers opened via global marks have proper syntax highlighting
- **Simple Commands**: Easy-to-use commands for managing your global marks

## Installation 🚀

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  "mohseenrm/marko.nvim",
  config = function()
    require("marko").setup()
  end
}
```

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "mohseenrm/marko.nvim",
  config = function()
    require("marko").setup()
  end
}
```

Or with configuration options using lazy.nvim's `opts` feature:

```lua
{
  "mohseenrm/marko.nvim",
  opts = {
    debug = false
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

- `:MarkoSave` - Manually save global marks for the current directory
- `:MarkoReload` - Clear all global marks and reload from config
- `:MarkoDeleteConfig` - Delete the global marks config file (with confirmation)
- `:MarkoMark {A-Z}` - Set a global mark at the current cursor position (e.g., `:MarkoMark A` sets mark A)
- `:MarkoDebug` - Display detailed information about all global marks, including filtered marks for the current directory and config file content

### Configuration

Setup with default options:

```lua
require("marko").setup()
```

Setup with custom options:

```lua
require("marko").setup({
  debug = false      -- Set to true for verbose logging
})
```

## How It Works

Marko saves your global marks in `~/.local/share/nvim/marko/config.yaml` and manages them based on your current working directory. When you start Neovim in a project, it will:

1. Clear all existing global marks
2. Loads global marks from config that match your current directory
3. Expands paths that start with `~` to full absolute paths
4. Set those global marks in the appropriate files
5. Automatically adjusts line numbers if they're outside the valid range for a file

When you exit Neovim, your current global marks are saved automatically. The plugin handles both absolute and relative paths, automatically expanding home directory references (`~`) to ensure proper mark restoration across different environments.

## Features Explained

### Project-Based Filtering

Marko only shows and restores global marks that belong to the current project directory. This prevents global marks from other projects showing up in your current project.

### Syntax Highlighting

When jumping to marks, Marko ensures that buffer filetype is correctly set to maintain proper syntax highlighting.

### Configuration File

Marks are stored in a YAML file with the following structure:

```yaml
/path/to/project1:
  - mark: "A"
    data:
      row: 10
      col: 0
      buffer: 1
      filename: "/path/to/project1/file.lua"
  - mark: "B"
    data:
      row: 20
      col: 5
      buffer: 1
      filename: "/path/to/project1/another.lua"
/path/to/project2:
  - mark: "C"
    data:
      row: 15
      col: 2
      buffer: 1
      filename: "/path/to/project2/test.lua"
  - mark: "D"
    data:
      row: 5
      col: 0
      buffer: 3
      filename: "~/Projects/project2/config.lua"
```

Both absolute paths and paths with `~` (home directory) are supported. The plugin will automatically expand `~` to the full home directory path when restoring marks.

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

- `lua/marko/init.lua`: Main entry point, setup function
- `lua/marko/config.lua`: Configuration and mark management
- `lua/marko/file.lua`: File operations and path handling
- `lua/marko/parser.lua`: YAML parsing utilities
- `lua/marko/utils.lua`: Helper functions
- `lua/marko/yaml.lua`: YAML serialization/deserialization
- `plugin/init.lua`: Plugin initialization
- `tests/`: Test suite

### Running Tests

Tests are written in a simple test framework:

```bash
# Run the full test suite
lua tests/run.lua
```

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
  opts = {
    debug = true -- Enable debug logging during development
  }
}
```

Then restart Neovim or run `:Lazy sync` to load the local version

You can also add a `dependencies` table if your plugin depends on other plugins during development.

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
