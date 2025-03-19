local config = require("marko.config")

local M = {}

-- Store options for the plugin
M.options = {
	auto_save = false,
	debug = false,
}

function M.setup(opts)
	-- Process options
	opts = opts or {}

	-- Merge provided options with defaults
	for k, v in pairs(opts) do
		M.options[k] = v
	end

	-- Initialize the config module
	config.setup()

	return M
end

return M
