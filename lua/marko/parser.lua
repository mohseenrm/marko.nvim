-- Import globals to fix luacheck warnings
require("marko.globals")

local yaml = require("marko.yaml")

local function readAll(file)
	local f = io.open(file, "rb")
	local content = f:read("*all")
	f:close()
	return content
end

-- This is a standalone script for testing yaml parsing
-- It expects command line arguments, which we need to handle carefully in luacheck
local M = {}

function M.parse_command_line(args)
	local debug = false
	local filename = nil
	if args and #args >= 1 then
		if args[1] == "-d" and #args >= 2 then
			debug = true
			filename = args[2]
		else
			filename = args[1]
			if #args >= 2 and args[2] == "-d" then
				debug = true
			end
		end
	end
	return debug, filename
end

function M.parse_file(filename, debug_mode)
	if not filename then
		error("file name parameter required")
	end

	local content = readAll(filename)

	-- ENABLE WHEN DEBUGGING PARSER ERRORS
	if debug_mode then
		local tokens = yaml.tokenize(content)
		-- Use ipairs instead of while loop to avoid unused variable
		for i, token in ipairs(tokens) do
			print(i, token[1], "'" .. (token.raw or "") .. "'")
		end
	end

	return yaml.eval(content)
end

-- Main entry point
function M.main(args)
	local debug_mode, filename = M.parse_command_line(args or {})
	if filename then
		local parsed = M.parse_file(filename, debug_mode)
		yaml.dump(parsed)
	else
		print("Usage: parser.lua [-d] filename")
	end
end

-- Only call main when run directly, not when required
if rawget(_G, "arg") then
	M.main(arg)
end

return M

