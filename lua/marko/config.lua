-- DEPRECATED: This module is no longer used in marko.nvim v2.0+
-- The plugin now uses project-specific ShaDa files instead of custom YAML config
-- Please see lua/marko/init.lua for the new implementation

local M = {}

M.setup = function()
	vim.notify(
		"marko.config is deprecated. The plugin now uses ShaDa files. Please update your configuration.",
		vim.log.levels.WARN,
		{ title = "marko.nvim" }
	)
end

return M
