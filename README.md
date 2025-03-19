# marko.nvim

A Neovim plugin for project-scoped marks management. Marko saves and restores your marks for each project directory, so they persist across Neovim sessions and are properly isolated between projects.

## Features

- **Project-Scoped Marks**: Only see marks that belong to your current working directory
- **Persistent Marks**: Marks are automatically saved when you exit Neovim and restored when you return
- **Proper File type Detection**: Ensures buffers opened via marks have proper syntax highlighting
- **Simple Commands**: Easy-to-use commands for managing your marks

## Installation

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
    auto_save = true,
    debug = false
  }
}
```

The `opts` table will be automatically passed to the setup function by lazy.nvim.

## Usage

### Setting Marks

Marko works with Neovim's uppercase marks (A-Z). Set marks as you normally would:

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

- `:MarkoSave` - Manually save marks for the current directory
- `:MarkoReload` - Clear all marks and reload from config
- `:MarkoDeleteConfig` - Delete the marks config file (with confirmation)

### Configuration

Setup with default options:

```lua
require("marko").setup()
```

Setup with custom options:

```lua
require("marko").setup({
  auto_save = true,  -- Auto-save marks more frequently
  debug = false      -- Set to true for verbose logging
})
```

## How It Works

Marko saves your marks in `~/.local/share/nvim/marko/config.yaml` and manages them based on your current working directory. When you start Neovim in a project, it will:

1. Clear all existing marks
2. Load marks from config that match your current directory
3. Set those marks in the appropriate files

When you exit Neovim, your current marks are saved automatically.

## Features Explained

### Project-Based Filtering

Marko only shows and restores marks that belong to the current project directory. This prevents marks from other projects showing up in your current project.

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
```

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
