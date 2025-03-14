local file = require("marko.file")
local config = require("marko.config")

local M = {}

local marks_path = os.getenv("HOME") .. "/.local/share/nvim/marko/config.yaml"

function M.setup()
	local _config = file.get_config(marks_path)
	-- print("FINAL" .. config)
end

return M
