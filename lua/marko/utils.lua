-- Import globals to fix luacheck warnings
require("marko.globals")

local M = {}

-- Get a value from a table, with an optional default value if the key doesn't exist
-- @param tbl The table to get the value from
-- @param key The key to look up
-- @param default Optional default value to return if the key doesn't exist
-- @return The value at tbl[key] if it exists, otherwise the default value (or nil)
function M.get(tbl, key, default)
	if tbl == nil then
		return default
	end

	local value = tbl[key]
	if value == nil then
		return default
	end

	return value
end

-- Helper function to properly set a global mark (capital letter)
-- @param mark The mark to set (A-Z)
-- @param row Row position (1-based)
-- @param col Column position (0-based)
-- @param buffer Buffer number
-- @param filename Full path to the file
-- @return Boolean indicating if mark was set successfully
function M.set_global_mark(mark, row, col, buffer, filename)
	-- Validate mark is a capital letter
	if not mark:match("^%u$") then
		M.log("Invalid mark: " .. mark .. " (must be A-Z)", vim.log.levels.ERROR, { title = "marko.nvim" })
		return false
	end

	-- Ensure row and col are numbers
	row = tonumber(row) or 1
	col = tonumber(col) or 0

	-- Expand tilde in path if present
	local expanded_filename = filename
	if filename:match("^~/") then
		local home_dir = os.getenv("HOME")
		if home_dir then
			expanded_filename = home_dir .. filename:sub(2)
			M.log(
				"Expanded filename from " .. filename .. " to " .. expanded_filename,
				vim.log.levels.INFO,
				{ title = "marko.nvim" }
			)
		end
	end

	-- Use Neovim's API to create a buffer if needed
	if buffer == 0 or not vim.api.nvim_buf_is_valid(buffer) then
		-- Check if file exists
		if vim.fn.filereadable(expanded_filename) == 0 then
			M.log("File not found: " .. expanded_filename, vim.log.levels.WARN, { title = "marko.nvim" })
			return false
		end

		-- Create a new buffer
		buffer = vim.fn.bufadd(expanded_filename)
		if buffer == 0 then
			M.log("Failed to create buffer for: " .. expanded_filename, vim.log.levels.ERROR, { title = "marko.nvim" })
			return false
		end
	end

	-- Load the buffer to ensure we can get line count
	vim.fn.bufload(buffer)

	-- Get total number of lines in the buffer
	local line_count = vim.api.nvim_buf_line_count(buffer)
	-- Ensure row is within valid range (1 to line_count)
	if row < 1 or row > line_count then
		M.log(
			"Mark "
				.. mark
				.. ": Row "
				.. row
				.. " is outside valid range (1-"
				.. line_count
				.. ") for "
				.. expanded_filename
				.. ". Using line 1 instead.",
			vim.log.levels.WARN,
			{ title = "marko.nvim" }
		)
		-- Set to line 1 as fallback
		row = 1
	end

	local mark_set
	-- Neovim 0.10+ has a global nvim_set_mark function
	if vim.fn.has("nvim-0.10") == 1 and vim.api.nvim_set_mark then
		mark_set = vim.api.nvim_set_mark(mark, row, col, {})
	else
		-- For older Neovim versions, use buffer-specific mark setting
		mark_set = vim.api.nvim_buf_set_mark(buffer, mark, row, col, {})
	end

	if mark_set then
		M.log("Successfully set global mark " .. mark .. " for " .. filename, vim.log.levels.INFO, { title = "marko.nvim" })

		-- Double-check mark was set correctly
		local check = vim.api.nvim_get_mark(mark, {})
		if check and check[4] then
			M.log("Mark " .. mark .. " set at " .. (check[4] or "unknown"), vim.log.levels.INFO, { title = "marko.nvim" })
		end
	else
		M.log("Failed to set mark " .. mark .. " for " .. filename, vim.log.levels.ERROR, { title = "marko.nvim" })
	end

	return mark_set
end

-- Safely navigate a nested table structure using a list of keys
-- @param tbl The table to traverse
-- @param keys A list of keys to navigate through the table
-- @param default Optional default value to return if any key in the path doesn't exist
-- @return The value at the end of the path if it exists, otherwise the default value (or nil)
function M.get_nested(tbl, keys, default)
	if tbl == nil then
		return default
	end

	local current = tbl
	for _, key in ipairs(keys) do
		if type(current) ~= "table" then
			return default
		end

		current = current[key]
		if current == nil then
			return default
		end
	end

	return current
end

-- Get the debug state from marko options
function M.is_debug_enabled()
	local marko = package.loaded["marko"]
	if marko and marko.options and marko.options.debug == true then
		return true
	end
	return false
end

-- Conditionally log based on debug setting
-- @param message The message to log
-- @param level The log level (vim.log.levels)
-- @param opts Additional options for notify
function M.log(message, level, opts)
	-- Always show errors and warnings
	if level == vim.log.levels.ERROR or level == vim.log.levels.WARN then
		vim.notify(message, level, opts)
	-- Only show info and debug messages if debug is enabled
	elseif M.is_debug_enabled() then
		vim.notify(message, level, opts)
	end
end

return M
