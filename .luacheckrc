-- Relaxed Luacheck configuration for Neovim plugins
std = {
  max_line_length = false,
  -- Globals for Neovim Lua API
  globals = {
    "vim",
    "assert",
    "describe",
    "it",
    "before_each",
    "after_each",
  },
}

-- Ignore warnings for unused self parameters in methods, common in OOP
self = false

-- Files to exclude
exclude_files = {
  ".luacheckrc",
}

-- Rules to ignore
ignore = {
  "212", -- Unused argument
  "631", -- Line too long
}