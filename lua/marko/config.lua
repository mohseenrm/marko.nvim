local file = require("marko.file")
local utils = require("marko.utils")

local M = {}

local marks_path = os.getenv("HOME") .. "/.local/share/nvim/marko/config.yaml"

-- Cache to store the last known config state
local config_cache = nil

local marks = {}
-- INFO: A-Z
for i = 65, 90 do
	table.insert(marks, string.char(i))
end

function M.filter_marks(project_path)
	-- This function is no longer used, delegating to file.filter_marks instead
	-- Keeping for backward compatibility
	return file.filter_marks(project_path)
end

-- iterate over marks, skips mark if part of table skip, else calls vim.api.nvim_del_mark
function M.del_marks(skipped_marks)
	print("SKIPPED_MARKS: " .. vim.inspect(skipped_marks))
	for _, mark in ipairs(marks) do
		if not vim.tbl_contains(skipped_marks, mark) then
			vim.api.nvim_del_mark(mark)
		end
	end
end

-- Function to save the current directory's marks
function M.save_current_marks()
	local cwd = vim.fn.getcwd()
	vim.notify("Saving marks for: " .. cwd, vim.log.levels.INFO, { title = "marko.nvim" })

	-- IMPORTANT: Use the file.lua implementation of filter_marks since it's more robust
	local curr_marks = file.filter_marks(cwd)
	vim.notify(
		"Found " .. #curr_marks .. " marks for project using file.filter_marks",
		vim.log.levels.WARN,
		{ title = "marko.nvim" }
	)

	-- Debug what we found
	if #curr_marks > 0 then
		vim.notify("Found " .. #curr_marks .. " marks to save", vim.log.levels.INFO, { title = "marko.nvim" })

		-- List each mark for debugging
		for _, mark in ipairs(curr_marks) do
			local content = vim.api.nvim_get_mark(mark, {})
			if content and content[4] then
				vim.notify("Mark " .. mark .. " at " .. content[4], vim.log.levels.DEBUG, { title = "marko.nvim" })
			end
		end

		-- Call file.save_directory_marks directly which will handle the saving
		local result, err = file.save_directory_marks(marks_path, cwd)

		if result then
			-- Update our local cache with the result from file.save_directory_marks
			config_cache = result

			vim.notify(
				"Successfully saved marks for " .. cwd .. " using file.save_directory_marks",
				vim.log.levels.INFO,
				{ title = "marko.nvim" }
			)
			return true
		else
			vim.notify(
				"Error saving marks: " .. (err or "unknown error"),
				vim.log.levels.ERROR,
				{ title = "marko.nvim" }
			)
			return false
		end
	else
		vim.notify("No marks found to save", vim.log.levels.WARN, { title = "marko.nvim" })
		return false
	end
end

-- Load the full config from disk
function M.load_full_config()
	local content = file.read_file(marks_path)
	if content and content ~= "" then
		local config = file.parse_config(content)
		if config and type(config) == "table" then
			config_cache = config

			-- Log directories found
			local dirs = vim.tbl_keys(config)
			if #dirs > 0 then
				vim.notify(
					"Loaded config with directories: " .. table.concat(dirs, ", "),
					vim.log.levels.DEBUG,
					{ title = "marko.nvim" }
				)
			end

			return config
		end
	end

	-- If we couldn't load or parse the file, start with empty config
	config_cache = {}
	return {}
end

function M.setup()
	-- Create user command to manually save marks
	vim.api.nvim_create_user_command("MarkoSave", function()
		-- Skip reloading config to avoid overwriting marks
		M.save_current_marks()
	end, { desc = "Save marks for current directory" })

	-- Load marks when Neovim starts and save any current marks
	vim.api.nvim_create_autocmd("UIEnter", {
		callback = function()
			vim.notify(
				"Initializing marko.nvim for directory: " .. vim.fn.getcwd(),
				vim.log.levels.INFO,
				{ title = "marko.nvim" }
			)

			-- Load config first to initialize cache
			M.load_full_config()

			-- Then save current marks
			M.save_current_marks()
		end,
	})

	-- Save marks when Neovim exits
	vim.api.nvim_create_autocmd("QuitPre", {
		callback = function()
			-- DON'T reload config before saving to avoid losing marks
			M.save_current_marks()
		end,
	})

	-- Also save marks on buffer write, but throttle it to avoid too many writes
	-- local last_save_time = 0
	-- vim.api.nvim_create_autocmd("BufWritePost", {
	-- 	callback = function()
	-- 		-- Only save once every 5 seconds at most
	-- 		local current_time = os.time()
	-- 		if current_time - last_save_time >= 5 then
	-- 			-- DON'T reload config before saving to avoid losing marks
	-- 			M.save_current_marks()
	--
	-- 			-- Update last save time
	-- 			last_save_time = current_time
	-- 		end
	-- 	end,
	-- })
end

return M
