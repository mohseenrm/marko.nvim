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
	-- enumerate over marks, check if valid and if starts with project_path
	local filtered_marks = {}
	for _, mark in ipairs(marks) do
		local content = vim.api.nvim_get_mark(mark, {})
		local mark_path = content[4]
		local valid = mark_path ~= ""
		local in_project = mark_path:match(project_path) ~= nil

		if valid and in_project then
			table.insert(filtered_marks, mark)
		end
	end
	return filtered_marks
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

	-- Use our improved filter_marks function to get current marks
	local curr_marks = file.filter_marks(cwd)

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

		-- Use the cached config if available, otherwise start with empty
		local current_config = config_cache or {}

		-- Update only this directory's marks
		local dir_marks = {}
		for _, mark in ipairs(curr_marks) do
			local content = vim.api.nvim_get_mark(mark, {})
			if content and content[1] then
				table.insert(dir_marks, { [mark] = content[1] })
			end
		end

		-- Update just this directory
		current_config[cwd] = dir_marks

		-- Generate YAML content manually to ensure correct format
		local yaml_lines = {}
		local sorted_dirs = vim.tbl_keys(current_config)
		table.sort(sorted_dirs)

		for i, dir in ipairs(sorted_dirs) do
			-- Add spacing between directories
			if i > 1 then
				table.insert(yaml_lines, "")
			end

			local marks = current_config[dir]
			table.insert(yaml_lines, dir .. ":")

			if marks and #marks > 0 then
				for _, mark_entry in ipairs(marks) do
					for mark_key, mark_value in pairs(mark_entry) do
						table.insert(yaml_lines, "  - " .. mark_key .. ": " .. mark_value)
					end
				end
			else
				table.insert(yaml_lines, "  # No marks for this directory")
			end
		end

		-- Generate the YAML string and write to file
		local yaml_content = table.concat(yaml_lines, "\n") .. "\n"
		local success, err = file.write_file(marks_path, yaml_content)

		if success then
			-- Update cache
			config_cache = current_config

			vim.notify(
				"Successfully saved " .. #dir_marks .. " marks for " .. cwd,
				vim.log.levels.INFO,
				{ title = "marko.nvim" }
			)
			return true
		else
			vim.notify(
				"Error writing config: " .. (err or "unknown error"),
				vim.log.levels.ERROR,
				{ title = "marko.nvim" }
			)
			return false
		end
	else
		vim.notify("No marks found to save", vim.log.levels.WARN, { title = "marko.nvim" })

		-- If no marks, still make sure directory exists in config
		if config_cache and not config_cache[cwd] then
			config_cache[cwd] = {}

			-- Generate YAML manually
			local yaml_lines = {}
			local sorted_dirs = vim.tbl_keys(config_cache)
			table.sort(sorted_dirs)

			for i, dir in ipairs(sorted_dirs) do
				if i > 1 then
					table.insert(yaml_lines, "")
				end

				local marks = config_cache[dir]
				table.insert(yaml_lines, dir .. ":")

				if marks and #marks > 0 then
					for _, mark_entry in ipairs(marks) do
						for mark_key, mark_value in pairs(mark_entry) do
							table.insert(yaml_lines, "  - " .. mark_key .. ": " .. mark_value)
						end
					end
				else
					table.insert(yaml_lines, "  # No marks for this directory")
				end
			end

			local yaml_content = table.concat(yaml_lines, "\n") .. "\n"
			file.write_file(marks_path, yaml_content)
		end

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
		-- Always reload config first to ensure we have the latest state
		M.load_full_config()
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
	vim.api.nvim_create_autocmd("VimLeavePre", {
		callback = function()
			-- Always reload config first to ensure we have latest state
			M.load_full_config()
			M.save_current_marks()
		end,
	})

	-- Also save marks on buffer write, but throttle it to avoid too many writes
	local last_save_time = 0
	vim.api.nvim_create_autocmd("BufWritePost", {
		callback = function()
			-- Only save once every 5 seconds at most
			local current_time = os.time()
			if current_time - last_save_time >= 5 then
				-- Always reload config first
				M.load_full_config()
				M.save_current_marks()

				-- Update last save time
				last_save_time = current_time
			end
		end,
	})
end

return M
