local yaml = require("marko.yaml")

local M = {}

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

-- Custom YAML parser to handle multiple directories properly
function M.parse_config(content)
	if not content or content == "" then
		return {}
	end
	
	-- Manually parse the YAML to ensure we get all directories
	local result = {}
	local current_dir = nil
	local lines = {}
	
	-- Split content into lines
	for line in content:gmatch("[^\r\n]+") do
		table.insert(lines, line)
	end
	
	for _, line in ipairs(lines) do
		-- Skip empty lines
		if line:match("^%s*$") then
			-- Skip empty lines
		elseif line:match("^%s*#") then
			-- Skip comments
		else
			-- Check if this is a directory line (ends with colon)
			local dir = line:match("^([^:]+):$")
			if dir then
				-- Found a new directory
				current_dir = dir
				if not result[current_dir] then
					result[current_dir] = {}
				end
			elseif current_dir and line:match("^%s*-%s") then
				-- This is a mark entry
				local mark, value = line:match("^%s*-%s+([^:]+):%s*(.+)$")
				if mark and value then
					-- Try to convert value to number if possible
					local num_value = tonumber(value)
					if num_value then
						value = num_value
					end
					
					-- Add to current directory's marks
					table.insert(result[current_dir], { [mark] = value })
				end
			end
		end
	end
	
	vim.notify("CUSTOM PARSER FOUND " .. vim.inspect(vim.tbl_count(result)) .. " DIRECTORIES", 
		vim.log.levels.ERROR, { title = "marko.nvim" })
	
	return result
end

function M.check_path(path)
	local file = io.open(path, "r")
	if file then
		file:close()
		return true
	end
	return false
end

function M.create_path(path)
	local parent = path:match("(.*/)")
	local mkdir_cmd = string.format("mkdir -p %s", parent)

	local result = os.execute(mkdir_cmd)
	if result ~= 0 then
		return nil, "Failed to create path, err: " .. result
	end

	local touch_cmd = string.format("touch %s", path)
	local result = os.execute(touch_cmd)

	if result ~= 0 then
		return nil, "Failed to create path, err: " .. result
	end
	return true
end

function M.create_file(path)
	local file, err = io.open(path, "w")
	if not file then
		return nil, err
	end
	file:close()
	return true
end

function M.write_file(path, content)
	local file, err = io.open(path, "w")
	if not file then
		return nil, err
	end
	file:write(content)
	file:close()
	return true
end

function M.read_file(path)
	local file, err = io.open(path, "r")
	if not file then
		return nil, err
	end
	local content = file:read("*all")
	file:close()
	return content
end

-- takes cwd, marks_to_save, generates config based on template base_config, mark content can be retrieved from vim.api.nvim_get_mark
function M.generate_config(cwd, marks_to_save)
	local base_config = cwd .. ":\n"
	for _, mark in ipairs(marks_to_save) do
		local content = vim.api.nvim_get_mark(mark, {})
		base_config = base_config .. "  - " .. mark .. ": " .. content[1] .. "\n"
	end
	return base_config
end

-- Generate a YAML string from a Lua table - separate function for clarity
function M.generate_yaml_from_config(config_table)
	local yaml_content = ""

	if type(config_table) ~= "table" then
		return yaml_content
	end

	-- Go through each directory in the config
	for dir, dir_marks in pairs(config_table) do
		if dir and type(dir_marks) == "table" then
			yaml_content = yaml_content .. dir .. ":\n"

			-- Go through each mark in the directory
			for _, mark_data in ipairs(dir_marks) do
				for mark_key, mark_value in pairs(mark_data) do
					yaml_content = yaml_content .. "  - " .. mark_key .. ": " .. mark_value .. "\n"
				end
			end
		end
	end

	return yaml_content
end

-- Updates an existing config with a new directory and marks
function M.update_config(existing_config, cwd, marks_to_save)
	-- Important debugging
	vim.notify("DEBUG update_config - Input existing_config: " .. vim.inspect(existing_config), vim.log.levels.DEBUG)

	-- Validate input
	if type(existing_config) ~= "table" then
		existing_config = {}
		vim.notify("DEBUG update_config - Invalid config type, initializing empty table", vim.log.levels.DEBUG)
	end

	-- Make a deep copy to avoid modifying the original table
	local updated_config = vim.deepcopy(existing_config)
	vim.notify("DEBUG update_config - After deepcopy: " .. vim.inspect(updated_config), vim.log.levels.DEBUG)

	-- Make sure the directory entry exists in the config
	if not updated_config[cwd] then
		updated_config[cwd] = {}
		vim.notify("DEBUG update_config - Adding new directory to config: " .. cwd, vim.log.levels.DEBUG)
	end

	-- Prepare for storing the current marks for this directory
	local dir_marks = {}

	-- Add the marks for this directory
	for _, mark in ipairs(marks_to_save) do
		local content = vim.api.nvim_get_mark(mark, {})
		if content and content[1] then
			local line_number = content[1]
			table.insert(dir_marks, { [mark] = line_number })
		end
	end

	-- Update just this directory with the new marks
	updated_config[cwd] = dir_marks

	vim.notify(
		"DEBUG update_config - Final config before YAML generation: " .. vim.inspect(updated_config),
		vim.log.levels.DEBUG
	)

	-- Use the dedicated function to generate YAML
	local yaml_content = M.generate_yaml_from_config(updated_config)

	vim.notify("DEBUG update_config - Final YAML content: " .. yaml_content, vim.log.levels.DEBUG)

	return yaml_content
end

-- Save directory marks to config file - FIXED VERSION TO PRESERVE OTHER DIRECTORIES
function M.save_directory_marks(config_path, directory_path)
	local utils = require("marko.utils")
	directory_path = directory_path or vim.fn.getcwd()

	vim.notify("Saving marks for directory: " .. directory_path, vim.log.levels.INFO, { title = "marko.nvim" })

	-- Step 1: Create the directory structure if needed
	if not M.check_path(config_path) then
		local success, err = M.create_path(config_path)
		if not success then
			vim.notify("Failed to create config path: " .. err, vim.log.levels.ERROR, { title = "marko.nvim" })
			return nil, err
		end
	end

	-- Step 2: Read and parse existing config
	local config_data = {}
	local content = M.read_file(config_path)

	-- Super verbose debug on the raw content
	vim.notify("RAW CONFIG CONTENT: " .. vim.inspect(content), vim.log.levels.ERROR, { title = "marko.nvim" })

	if content and content ~= "" then
		local success, result = pcall(function()
			return M.parse_config(content)
		end)

		vim.notify("PARSE RESULT SUCCESS: " .. tostring(success), vim.log.levels.ERROR, { title = "marko.nvim" })

		if success and type(result) == "table" then
			-- CRITICAL: Deep copy to ensure no references
			config_data = vim.deepcopy(result)

			-- Debug the loaded config
			local dir_keys = vim.tbl_keys(config_data)
			vim.notify(
				"LOADED CONFIG WITH " .. #dir_keys .. " DIRECTORIES: " .. table.concat(dir_keys, ", "),
				vim.log.levels.ERROR, -- Using ERROR level to make it more visible in logs
				{ title = "marko.nvim" }
			)

			-- Debug each directory's marks to see exactly what we have
			for dir, marks in pairs(config_data) do
				vim.notify(
					"DIRECTORY '" .. dir .. "' HAS " .. #marks .. " MARKS",
					vim.log.levels.ERROR,
					{ title = "marko.nvim" }
				)
			end
		else
			vim.notify(
				"!!! PARSE FAILED !!!: " .. (type(result) == "string" and result or "unknown error"),
				vim.log.levels.ERROR,
				{ title = "marko.nvim" }
			)
			config_data = {}
		end
	else
		vim.notify("EMPTY CONFIG CONTENT", vim.log.levels.ERROR, { title = "marko.nvim" })
	end

	-- Step 3: Get the current directory's marks
	local curr_marks = M.filter_marks(directory_path)
	local dir_marks = {}

	for _, mark in ipairs(curr_marks) do
		local mark_data = vim.api.nvim_get_mark(mark, {})
		if mark_data and mark_data[1] then
			table.insert(dir_marks, { [mark] = mark_data[1] })
		end
	end

	-- BEFORE: Check what's in config_data before we make changes
	vim.notify(
		"BEFORE UPDATE - CONFIG DATA HAS " .. #vim.tbl_keys(config_data) .. " DIRECTORIES",
		vim.log.levels.ERROR,
		{ title = "marko.nvim" }
	)

	-- Step 4: Update just the current directory in the config
	config_data[directory_path] = dir_marks

	-- AFTER: Check what's in config_data after we make changes
	vim.notify(
		"AFTER UPDATE - CONFIG DATA HAS "
			.. #vim.tbl_keys(config_data)
			.. " DIRECTORIES: "
			.. table.concat(vim.tbl_keys(config_data), ", "),
		vim.log.levels.ERROR,
		{ title = "marko.nvim" }
	)

	-- Step 5: Convert config to YAML format
	local lines = {}

	-- Sort the directories for consistent output
	local sorted_dirs = {}
	for dir, _ in pairs(config_data) do
		table.insert(sorted_dirs, dir)
	end
	table.sort(sorted_dirs)

	-- Process each directory in sorted order
	for _, dir in ipairs(sorted_dirs) do
		local config_marks = config_data[dir]

		-- Add a blank line between directories for better readability
		if #lines > 0 then
			table.insert(lines, "")
		end

		table.insert(lines, dir .. ":")
		if #config_marks > 0 then
			for _, mark_entry in ipairs(config_marks) do
				for mark_key, mark_value in pairs(mark_entry) do
					table.insert(lines, "  - " .. mark_key .. ": " .. mark_value)
				end
			end
		else
			table.insert(lines, "  # No marks")
		end
	end

	local yaml_content = table.concat(lines, "\n") .. "\n"

	-- Debug the final YAML content
	vim.notify("FINAL YAML CONTENT:\n" .. yaml_content, vim.log.levels.ERROR, { title = "marko.nvim" })

	-- Step 6: Write to file
	local success, err = M.write_file(config_path, yaml_content)
	if not success then
		vim.notify("Failed to write config: " .. err, vim.log.levels.ERROR, { title = "marko.nvim" })
		return nil, err
	end

	-- Try to read back the file and parse it to verify we're saving correctly
	local saved_content = M.read_file(config_path)
	if saved_content then
		local parsed_saved, result = pcall(function()
			return M.parse_config(saved_content)
		end)
		if parsed_saved and result then
			local saved_dirs = vim.tbl_keys(result)
			vim.notify(
				"VERIFICATION - SAVED CONFIG HAS " .. #saved_dirs .. " DIRECTORIES: " .. table.concat(saved_dirs, ", "),
				vim.log.levels.ERROR,
				{ title = "marko.nvim" }
			)
		end
	end

	vim.notify(
		"Successfully saved marks for directory: " .. directory_path,
		vim.log.levels.INFO,
		{ title = "marko.nvim" }
	)
	return config_data
end

function M.get_config(path)
	-- create marks path if does not exist, create new file and save content for cwd
	local res = M.check_path(path)
	local cwd = vim.fn.getcwd()
	local utils = require("marko.utils")

	-- path does exist
	if res then
		-- read and parse content
		local content, err = M.read_file(path)

		if not content or content == "" then
			-- Empty or invalid file, create a new one with current directory marks
			return M.save_directory_marks(path, cwd)
		end

		local parsed_config = M.parse_config(content)

		-- Check if current directory exists in config
		if not utils.get(parsed_config, cwd) then
			-- Directory doesn't exist in config, add it
			return M.save_directory_marks(path, cwd)
		end

		return parsed_config
	else
		-- Path does not exist, create it and save current directory marks
		return M.save_directory_marks(path, cwd)
	end
end

return M
