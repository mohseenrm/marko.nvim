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
	
	-- Debug the project path we're filtering for
	vim.notify("Filtering marks for project: " .. project_path, 
		vim.log.levels.WARN, { title = "marko.nvim" })
	
	for _, mark in ipairs(marks) do
		local content = vim.api.nvim_get_mark(mark, {})
		local mark_path = content[4] or ""
		
		-- More detailed validation
		local valid = mark_path ~= "" and mark_path ~= nil
		local in_project = false
		
		if valid then
			-- Debug the mark path
			vim.notify("Checking mark " .. mark .. " with path: " .. mark_path, 
				vim.log.levels.DEBUG, { title = "marko.nvim" })
				
			-- Try different ways to match the project path
			-- Simple string prefix check (most reliable for nested paths)
			if string.sub(mark_path, 1, #project_path) == project_path then
				in_project = true
				vim.notify("PREFIX MATCH for " .. mark .. ": " .. mark_path .. " starts with " .. project_path,
					vim.log.levels.WARN, { title = "marko.nvim" })
			-- Standard Lua pattern match for path
			elseif mark_path:match("^" .. project_path) then
				in_project = true 
				vim.notify("PATTERN MATCH for " .. mark .. ": " .. mark_path .. " matches pattern ^" .. project_path,
					vim.log.levels.WARN, { title = "marko.nvim" })
			-- Fallback to more relaxed matching
			elseif mark_path:find(project_path, 1, true) then
				in_project = true
				vim.notify("FIND MATCH for " .. mark .. ": " .. mark_path .. " contains " .. project_path,
					vim.log.levels.WARN, { title = "marko.nvim" })
			end
		end

		if valid and in_project then
			vim.notify("Mark " .. mark .. " MATCHES project: " .. project_path, 
				vim.log.levels.WARN, { title = "marko.nvim" })
			table.insert(filtered_marks, mark)
		end
	end
	
	vim.notify("Found " .. #filtered_marks .. " marks for project: " .. project_path, 
		vim.log.levels.WARN, { title = "marko.nvim" })
		
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
	
	for i, line in ipairs(lines) do
		-- Skip empty lines
		if line:match("^%s*$") then
			-- Skip empty lines, but preserve current directory context
		elseif line:match("^%s*#") then
			-- Skip comments, but preserve current directory context
		else
			-- Check if this is a directory line (ends with colon)
			local dir = line:match("^([^:]+):$")
			if dir then
				-- Found a new directory
				current_dir = dir
				result[current_dir] = result[current_dir] or {}
				
				-- Debug new directory found
				vim.notify("Parser found directory: " .. current_dir, 
					vim.log.levels.WARN, { title = "marko.nvim" })
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
					
					-- Debug mark found
					vim.notify("Parser found mark " .. mark .. " in dir " .. current_dir, 
						vim.log.levels.DEBUG, { title = "marko.nvim" })
				end
			end
		end
	end
	
	-- Debug summary of parsing results
	for dir, dir_marks in pairs(result) do
		vim.notify("Parser: Dir '" .. dir .. "' has " .. #dir_marks .. " marks", 
			vim.log.levels.WARN, { title = "marko.nvim" })
	end
	
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
	
	-- Show which directory we're processing
	vim.notify(
		"Processing directory: " .. directory_path,
		vim.log.levels.WARN,
		{ title = "marko.nvim" }
	)
	
	-- Process each mark
	for _, mark in ipairs(curr_marks) do
		local mark_data = vim.api.nvim_get_mark(mark, {})
		if mark_data then
			local line_num = mark_data[1]
			local col_num = mark_data[2]
			local filename = mark_data[4] or "unknown"
			
			-- Print full mark details for debugging
			vim.notify(
				"Mark " .. mark .. ": line=" .. tostring(line_num) .. ", col=" .. tostring(col_num) .. ", file=" .. filename,
				vim.log.levels.WARN,
				{ title = "marko.nvim" }
			)
			
			-- Only add valid marks
			if line_num and line_num > 0 then
				table.insert(dir_marks, { [mark] = line_num })
			end
		end
	end

	-- BEFORE: Check what's in config_data before we make changes
	vim.notify(
		"BEFORE UPDATE - CONFIG DATA HAS " .. #vim.tbl_keys(config_data) .. " DIRECTORIES",
		vim.log.levels.ERROR,
		{ title = "marko.nvim" }
	)

	-- Step 4: Update just the current directory in the config
	-- Only update if we actually have marks
	if #curr_marks > 0 then
		config_data[directory_path] = dir_marks
		vim.notify(
			"Updating directory with " .. #dir_marks .. " marks",
			vim.log.levels.WARN,
			{ title = "marko.nvim" }
		)
	else
		-- Ensure the directory exists but don't overwrite existing marks
		if not config_data[directory_path] then
			config_data[directory_path] = {}
		end
	end

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
		if type(config_marks) == "table" and #config_marks > 0 then
			for _, mark_entry in ipairs(config_marks) do
				for mark_key, mark_value in pairs(mark_entry) do
					table.insert(lines, "  - " .. mark_key .. ": " .. mark_value)
				end
			end
		else
			-- Better formatting for empty directories
			table.insert(lines, "  # No marks for this directory")
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
	
	vim.notify("Getting config for current directory: " .. cwd, 
		vim.log.levels.WARN, { title = "marko.nvim" })

	-- path does exist
	if res then
		-- read and parse content
		local content, err = M.read_file(path)

		if not content or content == "" then
			-- Empty or invalid file, create a new one with current directory marks
			vim.notify("Empty config file, creating new one", 
				vim.log.levels.WARN, { title = "marko.nvim" })
			return M.save_directory_marks(path, cwd)
		end

		local parsed_config = M.parse_config(content)
		
		-- Debug what we found in the config
		local config_dirs = vim.tbl_keys(parsed_config)
		vim.notify("Found " .. #config_dirs .. " directories in config", 
			vim.log.levels.WARN, { title = "marko.nvim" })
			
		-- Check each directory and its marks count
		for dir, dir_marks in pairs(parsed_config) do
			vim.notify("Config dir: " .. dir .. " has " .. #dir_marks .. " marks", 
				vim.log.levels.WARN, { title = "marko.nvim" })
		end

		-- Check if current directory exists in config
		if not utils.get(parsed_config, cwd) then
			-- Directory doesn't exist in config, add it
			vim.notify("Current directory not in config, adding: " .. cwd, 
				vim.log.levels.WARN, { title = "marko.nvim" })
			return M.save_directory_marks(path, cwd)
		end
		
		-- Check if we have marks for this directory
		local current_dir_marks = parsed_config[cwd]
		if current_dir_marks and #current_dir_marks == 0 then
			-- Directory exists but has no marks
			vim.notify("Directory exists but has no marks: " .. cwd, 
				vim.log.levels.WARN, { title = "marko.nvim" })
			
			-- Check if we have actual marks for this directory
			local actual_marks = M.filter_marks(cwd)
			if #actual_marks > 0 then
				vim.notify("Found " .. #actual_marks .. " marks to add to " .. cwd, 
					vim.log.levels.WARN, { title = "marko.nvim" })
				return M.save_directory_marks(path, cwd)
			end
		end

		return parsed_config
	else
		-- Path does not exist, create it and save current directory marks
		vim.notify("Config file doesn't exist, creating new one", 
			vim.log.levels.WARN, { title = "marko.nvim" })
		return M.save_directory_marks(path, cwd)
	end
end

return M
