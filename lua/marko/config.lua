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
		vim.log.levels.DEBUG,
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
	vim.notify("Clearing all marks", vim.log.levels.DEBUG, { title = "marko.nvim" })
	for _, mark in ipairs(marks) do
		vim.api.nvim_del_mark(mark)
	end
end

-- Function to save the current directory's marks
function M.save_current_marks()
	local cwd = vim.fn.getcwd()
	vim.notify("Saving marks for: " .. cwd, vim.log.levels.DEBUG, { title = "marko.nvim" })

	-- Get marks for current directory
	local curr_marks = file.filter_marks(cwd)

	if #curr_marks > 0 then
		-- Call file.save_directory_marks directly which will handle the saving
		local result, err = file.save_directory_marks(marks_path, cwd)

		if result then
			-- Update our local cache with the result from file.save_directory_marks
			config_cache = result

			vim.notify("Successfully saved marks for " .. cwd, vim.log.levels.DEBUG, { title = "marko.nvim" })
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
		vim.notify("No marks found to save", vim.log.levels.DEBUG, { title = "marko.nvim" })
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
	vim.notify("Setting marks for directory: " .. cwd, vim.log.levels.DEBUG, { title = "marko.nvim" })

	-- Ensure we have a loaded config
	if not config_cache then
		M.load_full_config()
	end

	-- Check if we have marks for this directory
	if not config_cache or not config_cache[cwd] or #config_cache[cwd] == 0 then
		vim.notify("No saved marks found for directory: " .. cwd, vim.log.levels.DEBUG, { title = "marko.nvim" })
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
				-- Use the built-in Neovim method that properly handles file type detection
				local buffer

				-- Try to find if the buffer is already loaded
				for _, buf in ipairs(vim.api.nvim_list_bufs()) do
					if vim.api.nvim_buf_get_name(buf) == mark_data.filename then
						buffer = buf
						break
					end
				end

				-- If buffer isn't already loaded, create it properly with filetype detection
				if not buffer then
					buffer = vim.fn.bufadd(mark_data.filename)
					if buffer ~= 0 then
						-- Load the buffer with filetype detection
						vim.fn.bufload(buffer)

						-- Force filetype detection to ensure syntax highlighting
						vim.api.nvim_command("doautocmd BufRead " .. vim.fn.fnameescape(mark_data.filename))

						-- Get the filetype based on the filename and set it explicitly
						local filetype = vim.filetype.match({ filename = mark_data.filename })
						if filetype then
							vim.api.nvim_buf_set_option(buffer, "filetype", filetype)
						end
					end
				end

				if buffer == 0 then
					vim.notify(
						"Failed to get buffer for file: " .. mark_data.filename,
						vim.log.levels.WARN,
						{ title = "marko.nvim" }
					)
				else
					-- Set the mark using nvim_buf_set_mark
					local success =
						vim.api.nvim_buf_set_mark(buffer, mark_data.mark, mark_data.row, mark_data.col or 0, {})

					if success then
						set_count = set_count + 1
					else
						vim.notify(
							"Failed to set mark " .. mark_data.mark .. " at " .. mark_data.filename,
							vim.log.levels.WARN,
							{ title = "marko.nvim" }
						)
					end
				end
			end
		end
	end

	vim.notify("Set " .. set_count .. " marks for directory: " .. cwd, vim.log.levels.DEBUG, { title = "marko.nvim" })
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
		-- Get the buffer's filetype
		local current_ft = vim.api.nvim_buf_get_option(buffer, "filetype")

		-- Only try to set filetype if it's not already set
		if current_ft == "" then
			local filename = vim.api.nvim_buf_get_name(buffer)
			-- Force filetype detection
			vim.api.nvim_command("doautocmd BufRead " .. vim.fn.fnameescape(filename))

			-- Try to detect filetype from filename
			local filetype = vim.filetype.match({ filename = filename })
			if filetype then
				vim.api.nvim_buf_set_option(buffer, "filetype", filetype)
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

			vim.notify("Successfully deleted marks config file", vim.log.levels.DEBUG, { title = "marko.nvim" })
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
		vim.notify("Marks config file does not exist", vim.log.levels.DEBUG, { title = "marko.nvim" })
		return false
	end
end

function M.setup()
	-- Create user command to manually save marks
	vim.api.nvim_create_user_command("MarkoSave", function()
		M.save_current_marks()
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

	-- Initialize when Neovim starts - clear all marks and load from config
	vim.api.nvim_create_autocmd("UIEnter", {
		callback = function()
			vim.notify(
				"Initializing marko.nvim for directory: " .. vim.fn.getcwd(),
				vim.log.levels.DEBUG,
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

	-- Fix syntax highlighting when jumping to marks
	vim.api.nvim_create_autocmd("BufEnter", {
		callback = function(args)
			-- Get the buffer number
			local bufnr = args.buf

			-- Ensure proper filetype for the buffer
			M.ensure_buffer_filetype(bufnr)
		end,
	})

	-- Save marks when Neovim exits
	vim.api.nvim_create_autocmd("QuitPre", {
		callback = function()
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
