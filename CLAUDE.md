# Marko.nvim Development Guidelines

## Commands
- Test YAML parser: `lua require("marko.parser").parse_file(path, true)` (debug flag enabled)
- No specific lint/test commands available

## Code Style
- **Imports**: Use local variables for required modules
  ```lua
  local config = require("marko.config")
  ```
- **Variables**: Define modules with uppercase `M`
  ```lua
  local M = {}
  -- Functions and logic
  return M
  ```
- **Functions**: Use snake_case for function and variable names
- **Indentation**: Use tabs for indentation
- **Error Handling**: Return nil/false and error message for failing functions
  ```lua
  return nil, "Error message"
  ```
- **Notifications**: Use vim.notify with appropriate log levels

## Plugin Structure
- `plugin/init.lua`: Entry point
- `lua/marko/init.lua`: Setup function
- `lua/marko/config.lua`: Configuration handling
- `lua/marko/file.lua`: File operations
- `lua/marko/parser.lua`: YAML parsing