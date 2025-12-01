# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-12-01

### Changed

- **BREAKING**: Complete rewrite to use Neovim's native ShaDa system instead of custom YAML config
- **BREAKING**: Marks now stored in project-specific ShaDa files at `~/.local/state/nvim/marko/`
- Project detection now based on absolute working directory path (no git/package.json detection)
- Simplified codebase by 70% by leveraging native Neovim features

### Added

- `:MarkoInfo` command to display project info and active marks
- `:MarkoList` command to list all project ShaDa files
- `:MarkoClean` command to delete current project's ShaDa file

### Removed

- **BREAKING**: `:MarkoReload` command (no longer needed)
- **BREAKING**: `:MarkoDeleteConfig` command (replaced by `:MarkoClean`)
- **BREAKING**: `:MarkoDebug` command (replaced by `:MarkoInfo`)
- **BREAKING**: Custom YAML configuration file
- Old modules: config.lua, file.lua, utils.lua, yaml.lua, parser.lua (deprecated)

### Fixed

- Race conditions between plugin and Neovim's ShaDa system
- Timing issues with mark loading/saving
- Complex path matching logic that caused bugs
- Marks from other projects bleeding through

### Migration

See [MIGRATION.md](MIGRATION.md) for detailed migration instructions from v1.x to v2.0.

## [1.x] - Previous Versions

Earlier versions used custom YAML configuration. See git history for details.
