require("marko.globals")

local file = require("marko.file")

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

	for _, mark in ipairs(marks) do
		if not vim.tbl_contains(skipped_marks, mark) then
			vim.api.nvim_del_mark(mark)
		end
	end
end

-- Clear all marks (no exceptions)
function M.clear_all_marks()
	for _, mark in ipairs(marks) do
		vim.api.nvim_del_mark(mark)
	end
end

-- Function to save the current directory's marks
function M.save_current_marks(force)
	local cwd = vim.fn.getcwd()
	local utils = require("marko.utils")

	-- Debug output start
	utils.log("Saving marks for directory: " .. cwd, vim.log.levels.INFO, { title = "marko.nvim" })
	-- Debug output end

	-- Get marks for current directory
	local curr_marks = file.filter_marks(cwd)

	-- Debug output start
	utils.log("Found " .. #curr_marks .. " marks for current directory", vim.log.levels.INFO, { title = "marko.nvim" })
	if #curr_marks > 0 then
		local marks_list = table.concat(curr_marks, ", ")
		utils.log("Marks: " .. marks_list, vim.log.levels.INFO, { title = "marko.nvim" })
	end
	-- Debug output end

	-- Check if we should proceed (force=true or marks exist)
	if force or #curr_marks > 0 then
		-- Ensure the config directory exists
		local config_dir = vim.fn.fnamemodify(marks_path, ":h")
		if vim.fn.isdirectory(config_dir) == 0 then
			vim.fn.mkdir(config_dir, "p")
			utils.log("Created config directory: " .. config_dir, vim.log.levels.INFO, { title = "marko.nvim" })
		end

		-- Call file.save_directory_marks directly which will handle the saving
		local result, err = file.save_directory_marks(marks_path, cwd)

		if result then
			-- Update our local cache with the result from file.save_directory_marks
			config_cache = result
			utils.log("Successfully saved marks to " .. marks_path, vim.log.levels.INFO, { title = "marko.nvim" })
			return true
		else
			utils.log("Error saving marks: " .. (err or "unknown error"), vim.log.levels.ERROR, { title = "marko.nvim" })
			return false
		end
	else
		utils.log("No marks found for current directory, nothing to save", vim.log.levels.WARN, { title = "marko.nvim" })
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
	local utils = require("marko.utils")

	-- Ensure we have a loaded config
	if not config_cache then
		M.load_full_config()
	end

	-- Check if we have marks for this directory
	if not config_cache or not config_cache[cwd] or #config_cache[cwd] == 0 then
		-- vim.notify("No marks found in config for directory: " .. cwd, vim.log.levels.INFO, { title = "marko.nvim" })
		return false
	end

	local dir_marks = config_cache[cwd]
	local set_count = 0

	-- vim.notify(
	-- 	"Setting " .. #dir_marks .. " marks from config for directory: " .. cwd,
	-- 	vim.log.levels.INFO,
	-- 	{ title = "marko.nvim" }
	-- )

	-- Set each mark from the config
	for _, mark_data in ipairs(dir_marks) do
		if mark_data.mark and mark_data.filename and mark_data.row then
			-- Expand any ~ in filename
			local expanded_filename = mark_data.filename
			if expanded_filename:match("^~/") then
				local home_dir = os.getenv("HOME")
				if home_dir then
					expanded_filename = home_dir .. expanded_filename:sub(2)
					utils.log(
						"Expanded filename from " .. mark_data.filename .. " to " .. expanded_filename,
						vim.log.levels.INFO,
						{ title = "marko.nvim" }
					)
				end
			end

			-- Check if the file exists using expanded filename
			local file_exists = vim.fn.filereadable(expanded_filename) == 1

			if file_exists then
				-- Use our utility function to set the global mark
				local success = utils.set_global_mark(
					mark_data.mark,
					mark_data.row,
					mark_data.col or 0,
					mark_data.buffer or 0,
					expanded_filename
				)

				if success then
					set_count = set_count + 1
				end
			else
				if expanded_filename ~= mark_data.filename then
					utils.log(
						"File not found: " .. mark_data.filename .. " (expanded to: " .. expanded_filename .. ")",
						vim.log.levels.WARN,
						{ title = "marko.nvim" }
					)
				else
					utils.log("File not found: " .. mark_data.filename, vim.log.levels.WARN, { title = "marko.nvim" })
				end
			end
		else
			vim.notify("Invalid mark data: missing required fields", vim.log.levels.WARN, { title = "marko.nvim" })
		end
	end

	vim.notify(
		"Successfully set " .. set_count .. " out of " .. #dir_marks .. " marks",
		vim.log.levels.INFO,
		{ title = "marko.nvim" }
	)

	return set_count > 0
end

-- Helper function to ensure a buffer has proper syntax highlighting
function M.ensure_buffer_filetype(buffer_or_path)
	-- Determine if we got a buffer number or a path
	local buffer = buffer_or_path
	local path = buffer_or_path

	if type(buffer_or_path) == "string" then
		-- We got a path, try to find the buffer
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_get_name(buf) == path then
				buffer = buf
				break
			end
		end

		-- If buffer not found, create it
		if type(buffer) == "string" then
			buffer = vim.fn.bufadd(path)
			vim.fn.bufload(buffer)
		end
	end

	-- Make sure buffer is valid
	if buffer and buffer ~= 0 and vim.api.nvim_buf_is_valid(buffer) then
		-- Get the buffer's filetype using the new API
		local current_ft = vim.api.nvim_get_option_value("filetype", { buf = buffer })

		-- Only try to set filetype if it's not already set
		if current_ft == "" then
			local filename = vim.api.nvim_buf_get_name(buffer)
			-- Force filetype detection
			vim.api.nvim_command("doautocmd BufRead " .. vim.fn.fnameescape(filename))

			-- Try to detect filetype from filename
			local filetype = vim.filetype.match({ filename = filename })
			if filetype then
				-- Set filetype using the new API
				vim.api.nvim_set_option_value("filetype", filetype, { buf = buffer })
				return true
			end
		else
			-- Already has a filetype
			return true
		end
	end

	return false
end

-- Function to delete the config file
function M.delete_config_file()
	-- Check if config file exists
	local exists = file.check_path(marks_path)

	if exists then
		-- Try to delete the file
		local result, err = os.remove(marks_path)

		if result then
			-- Reset the cache
			config_cache = {}

			return true
		else
			vim.notify(
				"Failed to delete marks config file: " .. (err or "unknown error"),
				vim.log.levels.ERROR,
				{ title = "marko.nvim" }
			)
			return false
		end
	else
		return false
	end
end

function M.setup(opts)
	-- Create user command to manually save marks
	vim.api.nvim_create_user_command("MarkoSave", function()
		M.save_current_marks(true)
	end, { desc = "Save marks for current directory" })

	-- Add a command to clear and reload marks
	vim.api.nvim_create_user_command("MarkoReload", function()
		M.clear_all_marks()
		M.load_full_config()
		M.set_marks_from_config()
	end, { desc = "Clear all marks and reload from config" })

	-- Add a command to delete the config file
	vim.api.nvim_create_user_command("MarkoDeleteConfig", function()
		-- Ask for confirmation
		vim.ui.select({ "Yes", "No" }, {
			prompt = "Are you sure you want to delete the marks config file?",
			format_item = function(item)
				return item
			end,
		}, function(choice)
			if choice == "Yes" then
				local success = M.delete_config_file()
				if success then
					-- Also clear all marks
					M.clear_all_marks()
				end
			else
				vim.notify("Operation cancelled", vim.log.levels.INFO, { title = "marko.nvim" })
			end
		end)
	end, { desc = "Delete the marks config file" })

	-- Add debug command to check all marks
	vim.api.nvim_create_user_command("MarkoDebug", function()
		local cwd = vim.fn.getcwd()
		vim.notify("Current directory: " .. cwd, vim.log.levels.INFO, { title = "marko.nvim" })

		-- Print all marks
		vim.notify("=== All Marks ===", vim.log.levels.INFO, { title = "marko.nvim" })
		for _, mark in ipairs(marks) do
			local content = vim.api.nvim_get_mark(mark, {})
			local row = content[1] or 0
			local col = content[2] or 0
			local buf = content[3] or 0
			local file_path = content[4] or ""

			if row > 0 and file_path ~= "" then
				vim.notify(
					string.format("Mark %s: row=%d, col=%d, buf=%d, file=%s", mark, row, col, buf, file_path),
					vim.log.levels.INFO,
					{ title = "marko.nvim" }
				)
			end
		end

		-- Print filtered marks
		local filtered = file.filter_marks(cwd)
		vim.notify(string.format("=== Filtered Marks (%d) ===", #filtered), vim.log.levels.INFO, { title = "marko.nvim" })
		for _, mark in ipairs(filtered) do
			local content = vim.api.nvim_get_mark(mark, {})
			vim.notify(
				string.format("Filtered mark %s: %s", mark, content[4] or ""),
				vim.log.levels.INFO,
				{ title = "marko.nvim" }
			)
		end

		-- Print config file path
		vim.notify("Config file path: " .. marks_path, vim.log.levels.INFO, { title = "marko.nvim" })

		-- Check if config file exists
		if file.check_path(marks_path) then
			local content = file.read_file(marks_path)
			if content and content ~= "" then
				vim.notify("Config file content:\n" .. content, vim.log.levels.INFO, { title = "marko.nvim" })
				local parsed = file.parse_config(content)
				if parsed and type(parsed) == "table" then
					for dir, marks_list in pairs(parsed) do
						vim.notify(
							string.format("Directory: %s, Marks: %d", dir, #marks_list),
							vim.log.levels.INFO,
							{ title = "marko.nvim" }
						)
					end
				end
			else
				vim.notify("Config file is empty", vim.log.levels.INFO, { title = "marko.nvim" })
			end
		else
			vim.notify("Config file does not exist", vim.log.levels.INFO, { title = "marko.nvim" })
		end
	end, { desc = "Debug marks information" })

	-- Add command to manually set a mark for the current file
	vim.api.nvim_create_user_command("MarkoMark", function(args)
		local utils = require("marko.utils")
		local mark = args.args

		-- Validate mark is provided and is a capital letter
		if not mark or not mark:match("^%u$") then
			vim.notify("Please provide a valid mark (A-Z)", vim.log.levels.ERROR, { title = "marko.nvim" })
			return
		end

		-- Get current buffer, cursor position, and file path
		local buffer = vim.api.nvim_get_current_buf()
		local cursor = vim.api.nvim_win_get_cursor(0)
		local row = cursor[1]
		local col = cursor[2]
		local filename = vim.api.nvim_buf_get_name(buffer)

		if filename == "" then
			vim.notify("Cannot set mark on unnamed buffer", vim.log.levels.ERROR, { title = "marko.nvim" })
			return
		end

		-- Set the global mark
		local success = utils.set_global_mark(mark, row, col, buffer, filename)

		if success then
			vim.notify("Mark '" .. mark .. "' set for current file", vim.log.levels.INFO, { title = "marko.nvim" })
			-- Save marks immediately
			M.save_current_marks(true)
		end
	end, { nargs = 1, desc = "Set a mark for the current file" })

	-- Initialize when Neovim starts - clear all marks and load from config
	vim.api.nvim_create_autocmd("UIEnter", {
		callback = function()
			-- Load config first to initialize cache
			M.load_full_config()

			-- Clear all existing marks
			M.clear_all_marks()

			-- Set marks from the config
			M.set_marks_from_config()
		end,
	})

	-- Fix syntax highlighting when jumping to marks
	vim.api.nvim_create_autocmd("BufEnter", {
		callback = function(args)
			-- Get the buffer number
			local bufnr = args.buf

			-- Ensure proper filetype for the buffer
			M.ensure_buffer_filetype(bufnr)
		end,
	})

	-- Save marks when Neovim exits - use multiple events to ensure saving happens
	vim.api.nvim_create_autocmd({ "QuitPre", "VimLeavePre", "VimLeave" }, {
		callback = function()
			M.save_current_marks(true)
		end,
		group = vim.api.nvim_create_augroup("MarkoSaveOnExit", { clear = true }),
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


