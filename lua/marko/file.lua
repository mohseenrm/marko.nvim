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

	-- Ensure project_path ends with a path separator to prevent partial path matches
	local normalized_project_path = project_path
	if normalized_project_path:sub(-1) ~= "/" then
		normalized_project_path = normalized_project_path .. "/"
	end

	for _, mark in ipairs(marks) do
		local content = vim.api.nvim_get_mark(mark, {})
		local mark_path = content[4] or ""

		-- More detailed validation
		local valid = mark_path ~= "" and mark_path ~= nil
		local in_project = false

		if valid then
			-- Normalize the mark path to ensure it's a file path
			local mark_file_path = mark_path

			-- Only use direct prefix match for exact path matching
			-- This ensures the mark path starts with the project path
			if string.sub(mark_file_path, 1, #normalized_project_path) == normalized_project_path then
				in_project = true
			-- Alternative test using direct string prefix for exact path
			elseif string.sub(mark_file_path, 1, #project_path) == project_path then
				-- Secondary check for files directly in the root of the project (no trailing slash)
				in_project = true
			end
		end

		if valid and in_project then
			table.insert(filtered_marks, mark)
		end
	end

	return filtered_marks
end

-- Custom YAML parser to handle multiple directories with detailed mark information
function M.parse_config(content)
	if not content or content == "" then
		return {}
	end

	-- Manually parse the YAML to ensure we get all directories
	local result = {}
	local current_dir = nil
	local current_mark = nil
	local current_mark_data = nil
	local in_data_section = false
	local lines = {}

	-- Split content into lines
	for line in content:gmatch("[^\r\n]+") do
		table.insert(lines, line)
	end

	for i, line in ipairs(lines) do
		-- Skip empty lines and comments
		if line:match("^%s*$") then
			-- Skip empty lines, but preserve context
		elseif line:match("^%s*#") then
			-- Skip comments, but preserve context
		else
			-- Check if this is a directory line (ends with colon and doesn't have indent)
			local dir = line:match("^([^%s][^:]+):$")
			if dir then
				-- Found a new directory
				current_dir = dir
				result[current_dir] = result[current_dir] or {}
				current_mark = nil
				current_mark_data = nil
				in_data_section = false
			elseif current_dir and line:match("^%s*-%s+mark:") then
				-- New style mark entry with explicit mark: field
				local mark = line:match('^%s*-%s+mark:%s*"([^"]+)"')
				if mark then
					-- This is a mark identifier in the new format
					current_mark = mark
					current_mark_data = {
						mark = mark,
						row = 0,
						col = 0,
						buffer = 0,
						filename = "",
					}
					in_data_section = false
				end
			elseif current_dir and current_mark and line:match("^%s+data:") then
				-- Found the data section for a mark
				in_data_section = true
			elseif current_dir and current_mark and in_data_section and line:match("^%s+%w+:") then
				-- This is a property within the data section
				local prop, value = line:match("^%s+(%w+):%s*(.+)$")
				if prop and value and current_mark_data then
					-- Remove quotes if present
					value = value:gsub('^"(.*)"$', "%1")

					-- Try to convert to number if appropriate
					if prop ~= "filename" then
						local num_value = tonumber(value)
						if num_value then
							value = num_value
						end
					end

					-- Set the property in the current mark data
					current_mark_data[prop] = value

					-- If this is the last property (filename), add the mark to the result
					if prop == "filename" then
						table.insert(result[current_dir], current_mark_data)
					end
				end
			elseif current_dir and line:match("^%s*-%s") then
				-- Handle old-style mark entries for backward compatibility
				local mark, value = line:match("^%s*-%s+([^:]+):%s*(.+)$")
				if mark and value then
					-- Legacy single-line mark entry
					local num_value = tonumber(value)
					if num_value then
						value = num_value
					end

					table.insert(result[current_dir], {
						mark = mark,
						row = value,
						col = 0,
						buffer = 0,
						filename = "",
					})
				end
			end
		end
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
		base_config = base_config .. '  - mark: "' .. mark .. '"\n'
		base_config = base_config .. "    data:\n"
		base_config = base_config .. "      row: " .. content[1] .. "\n"
		base_config = base_config .. "      col: " .. content[2] .. "\n"
		base_config = base_config .. "      buffer: " .. content[3] .. "\n"
		base_config = base_config .. '      filename: "' .. (content[4] or "") .. '"\n'
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
				-- Use new format with mark: and data: sections
				yaml_content = yaml_content .. '  - mark: "' .. mark_data.mark .. '"\n'
				yaml_content = yaml_content .. "    data:\n"
				yaml_content = yaml_content .. "      row: " .. mark_data.row .. "\n"
				yaml_content = yaml_content .. "      col: " .. mark_data.col .. "\n"
				yaml_content = yaml_content .. "      buffer: " .. mark_data.buffer .. "\n"
				yaml_content = yaml_content .. '      filename: "' .. mark_data.filename .. '"\n'
			end
		end
	end

	return yaml_content
end

-- Updates an existing config with a new directory and marks
function M.update_config(existing_config, cwd, marks_to_save)
	-- Validate input and ensure existing_config is a table
	if type(existing_config) ~= "table" then
		existing_config = {}
	end

	-- Create a copy of the existing config to preserve data from other directories
	local updated_config = vim.deepcopy(existing_config)

	-- Ensure the current directory exists in the config
	if not updated_config[cwd] then
		updated_config[cwd] = {}
	end

	-- Create a set of marks to be saved for fast lookup
	local mark_set = {}
	for _, mark in ipairs(marks_to_save) do
		mark_set[mark] = true
	end

	-- Remove only entries for marks that are being updated in this directory
	local filtered_marks = {}
	for _, mark_entry in ipairs(updated_config[cwd]) do
		local should_keep = true
		if mark_entry.mark and mark_set[mark_entry.mark] then
			should_keep = false
		end
		if should_keep then
			table.insert(filtered_marks, mark_entry)
		end
	end

	-- Update with filtered marks
	updated_config[cwd] = filtered_marks

	-- Add the current marks for this directory
	for _, mark in ipairs(marks_to_save) do
		local content = vim.api.nvim_get_mark(mark, {})
		if content and content[1] then
			local line_number = content[1]
			table.insert(updated_config[cwd], {
				mark = mark,
				row = content[1],
				col = content[2],
				buffer = content[3],
				filename = content[4] or "",
			})
		end
	end

	-- Generate YAML string
	return M.generate_yaml_from_config(updated_config)
end

-- Save directory marks to config file
function M.save_directory_marks(config_path, directory_path)
	directory_path = directory_path or vim.fn.getcwd()

	-- Step 1: Ensure config file exists
	local exists = M.check_path(config_path)
	if not exists then
		-- Create config file first
		local success, err = M.create_path(config_path)
		if not success then
			vim.notify("Error creating config file path: " .. err, vim.log.levels.ERROR, { title = "marko.nvim" })
			return nil, err
		end

		-- Initialize with empty content
		local success, err = M.write_file(config_path, "")
		if not success then
			vim.notify("Error initializing config file: " .. err, vim.log.levels.ERROR, { title = "marko.nvim" })
			return nil, err
		end
	end

	-- Step 2: Read existing config
	local content, err = M.read_file(config_path)
	if not content then
		vim.notify(
			"Error reading config file: " .. (err or "unknown error"),
			vim.log.levels.ERROR,
			{ title = "marko.nvim" }
		)
		return nil, err
	end

	-- Step 3: Parse the config safely
	local parsed_config = {}
	if content and content ~= "" then
		local success, result = pcall(function()
			return M.parse_config(content)
		end)

		if success and result and type(result) == "table" then
			parsed_config = result
		else
			vim.notify("Warning: Failed to parse config, starting fresh", vim.log.levels.WARN, { title = "marko.nvim" })
		end
	end

	-- Step 4: Get current marks for this directory
	local curr_marks = M.filter_marks(directory_path)

	-- Step 5: Update the config with current directory marks while preserving other directories
	local updated_content = M.update_config(parsed_config, directory_path, curr_marks)

	-- Step 6: Write the updated config back to file
	local success, err = M.write_file(config_path, updated_content)
	if not success then
		vim.notify("Error saving directory marks: " .. err, vim.log.levels.ERROR, { title = "marko.nvim" })
		return nil, err
	end

	-- Return the updated parsed config
	local new_config = M.parse_config(updated_content)
	return new_config
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

		-- Check if we have marks for this directory
		local current_dir_marks = parsed_config[cwd]
		if current_dir_marks and #current_dir_marks == 0 then
			-- Directory exists but has no marks
			-- Check if we have actual marks for this directory
			local actual_marks = M.filter_marks(cwd)
			if #actual_marks > 0 then
				return M.save_directory_marks(path, cwd)
			end
		end

		return parsed_config
	else
		-- Path does not exist, create it and save current directory marks
		return M.save_directory_marks(path, cwd)
	end
end

return M
