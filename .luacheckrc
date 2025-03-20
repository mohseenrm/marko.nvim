-- Relaxed Luacheck configuration for Neovim plugins
std = "lua51"

-- Define Neovim global
globals = {
  "vim",
  -- For tests
  "assert",
  "describe",
  "it",
  "before_each",
  "after_each",
}

-- Don't report unused self parameters of methods
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

-- Allow accessing globals defined in vim namespace
read_globals = {
  "vim",
}