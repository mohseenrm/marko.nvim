local file = require("marko.file")

local M = {}

local marks_path = os.getenv("HOME") .. "/.local/share/nvim/marko/config.yaml"

function M.setup()
	local config = file.get_config(marks_path)
	-- print("FINAL" .. config)
end

return M
