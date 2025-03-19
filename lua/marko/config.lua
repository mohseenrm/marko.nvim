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

-- Clear all marks except those in the skipped_marks table
function M.del_marks(skipped_marks)
	skipped_marks = skipped_marks or {}
	vim.notify(
		"Clearing marks (except " .. #skipped_marks .. " skipped)",
		vim.log.levels.INFO,
		{ title = "marko.nvim" }
	)

	for _, mark in ipairs(marks) do
		if not vim.tbl_contains(skipped_marks, mark) then
			vim.api.nvim_del_mark(mark)
		end
	end
end

-- Clear all marks (no exceptions)
function M.clear_all_marks()
	vim.notify("Clearing all marks", vim.log.levels.INFO, { title = "marko.nvim" })
	for _, mark in ipairs(marks) do
		vim.api.nvim_del_mark(mark)
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

-- Set marks from the config for the current directory
function M.set_marks_from_config()
	local cwd = vim.fn.getcwd()
	vim.notify("Setting marks for directory: " .. cwd, vim.log.levels.INFO, { title = "marko.nvim" })

	-- Ensure we have a loaded config
	if not config_cache then
		M.load_full_config()
	end

	-- Check if we have marks for this directory
	if not config_cache or not config_cache[cwd] or #config_cache[cwd] == 0 then
		vim.notify("No saved marks found for directory: " .. cwd, vim.log.levels.WARN, { title = "marko.nvim" })
		return false
	end

	local dir_marks = config_cache[cwd]
	local set_count = 0

	-- Set each mark from the config
	for _, mark_data in ipairs(dir_marks) do
		if mark_data.mark and mark_data.filename and mark_data.row then
			-- Check if the file exists
			local file_exists = vim.fn.filereadable(mark_data.filename) == 1

			if file_exists then
				-- Open the file to get a valid buffer number
				local buffer = vim.fn.bufadd(mark_data.filename)
				if buffer == 0 then
					vim.notify(
						"Failed to get buffer for file: " .. mark_data.filename,
						vim.log.levels.WARN,
						{ title = "marko.nvim" }
					)
				else
					-- Ensure the buffer is loaded
					vim.fn.bufload(buffer)

					-- Set the mark using nvim_buf_set_mark
					local success =
						vim.api.nvim_buf_set_mark(buffer, mark_data.mark, mark_data.row, mark_data.col or 0, {})

					if success then
						set_count = set_count + 1
						vim.notify(
							"Set mark " .. mark_data.mark .. " at " .. mark_data.filename .. ":" .. mark_data.row,
							vim.log.levels.DEBUG,
							{ title = "marko.nvim" }
						)
					else
						vim.notify(
							"Failed to set mark " .. mark_data.mark .. " at " .. mark_data.filename,
							vim.log.levels.WARN,
							{ title = "marko.nvim" }
						)
					end
				end
			else
				vim.notify(
					"Skipping mark " .. mark_data.mark .. " - file does not exist: " .. mark_data.filename,
					vim.log.levels.WARN,
					{ title = "marko.nvim" }
				)
			end
		end
	end

	vim.notify("Set " .. set_count .. " marks for directory: " .. cwd, vim.log.levels.INFO, { title = "marko.nvim" })
	return set_count > 0
end

function M.setup()
	-- Create user command to manually save marks
	vim.api.nvim_create_user_command("MarkoSave", function()
		-- Skip reloading config to avoid overwriting marks
		M.save_current_marks()
	end, { desc = "Save marks for current directory" })

	-- Add a command to clear and reload marks
	vim.api.nvim_create_user_command("MarkoReload", function()
		M.clear_all_marks()
		M.load_full_config()
		M.set_marks_from_config()
	end, { desc = "Clear all marks and reload from config" })

	-- Initialize when Neovim starts - clear all marks and load from config
	vim.api.nvim_create_autocmd("UIEnter", {
		callback = function()
			vim.notify(
				"Initializing marko.nvim for directory: " .. vim.fn.getcwd(),
				vim.log.levels.INFO,
				{ title = "marko.nvim" }
			)

			-- Load config first to initialize cache
			M.load_full_config()

			-- Clear all existing marks
			M.clear_all_marks()

			-- Set marks from the config
			M.set_marks_from_config()
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

