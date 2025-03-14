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

function M.parse_config(content)
	return yaml.eval(content)
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

-- Updates an existing config with a new directory and marks
function M.update_config(existing_config, cwd, marks_to_save)
	-- Create a copy of the existing config
	local updated_config = vim.deepcopy(existing_config)

	-- Always replace the directory's marks with the current ones
	updated_config[cwd] = {}

	-- Add all marks for this directory
	for _, mark in ipairs(marks_to_save) do
		local content = vim.api.nvim_get_mark(mark, {})
		local line_number = content[1]
		table.insert(updated_config[cwd], { [mark] = line_number })
	end

	-- Convert back to YAML format
	local yaml_content = ""
	for dir, curr_marks in pairs(updated_config) do
		print("DEBUG: dir: " .. vim.inspect(dir))
		print("DEBUG: curr_marks: " .. vim.inspect(curr_marks))
		yaml_content = yaml_content .. dir .. ":\n"
		for _, mark_data in ipairs(curr_marks) do
			for mark_key, mark_value in pairs(mark_data) do
				yaml_content = yaml_content .. "  - " .. mark_key .. ": " .. mark_value .. "\n"
			end
		end
	end

	return yaml_content
end

-- Save directory marks to config file
function M.save_directory_marks(config_path, directory_path)
	local utils = require("marko.utils")
	directory_path = directory_path or vim.fn.getcwd()

	-- Check if config file exists
	local exists = M.check_path(config_path)
	if not exists then
		-- Create config file first
		local success, err = M.create_path(config_path)
		if not success then
			vim.notify("Error creating config file path: " .. err, vim.log.levels.ERROR, { title = "marko.nvim" })
			return nil, err
		end

		-- Write initial empty config
		local success, err = M.write_file(config_path, "")
		if not success then
			vim.notify("Error initializing config file: " .. err, vim.log.levels.ERROR, { title = "marko.nvim" })
			return nil, err
		end
	end

	-- Read and parse existing config
	local content, err = M.read_file(config_path)
	if not content then
		vim.notify(
			"Error reading config file: " .. (err or "unknown error"),
			vim.log.levels.ERROR,
			{ title = "marko.nvim" }
		)
		return nil, err
	end

	-- Parse the config (even if empty)
	local parsed_config = {}
	if content ~= "" then
		parsed_config = M.parse_config(content)
	end

	-- Get marks for the directory
	local marks = M.filter_marks(directory_path)

	-- Update the config with current directory marks
	local updated_content = M.update_config(parsed_config, directory_path, marks)

	-- Write the updated config back to file
	local success, err = M.write_file(config_path, updated_content)
	if not success then
		vim.notify("Error saving directory marks: " .. err, vim.log.levels.ERROR, { title = "marko.nvim" })
		return nil, err
	end

	-- Return the updated parsed config
	return M.parse_config(updated_content)
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
