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

function M.get_config(path)
	-- create marks path if does not exist, create new file and save content for cwd
	local res = M.check_path(path)
	local cwd = vim.fn.getcwd()
	-- print("TEST: " .. test)
	local base_config = [[
]] .. cwd .. [[:
  - A: mark content
  - B: mark content
]]

	-- path does exist
	if res then
		-- read and parse content
		local content, err = M.read_file(path)
		-- print("HERE 1" .. err)

		if not content then
			local success, err = M.write_file(path, base_config)
			vim.notify("Error parsing mark content" .. err, vim.log.levels.ERROR, { title = "marko.nvim" })
			return nil, err
		end

		print(content)
		local test = M.parse_config(content)
		print("TEST: " .. vim.inspect(test))
		return content
	else
		-- path does not exist
		print("CREATING CONFIG")
		print("CWD: " .. cwd)
		local success, err = M.create_path(path)

		if not success then
			vim.notify("Error creating file path" .. err, vim.log.levels.ERROR, { title = "marko.nvim" })
			return nil, err
		end

		-- process: create config, filter marks, write filtered marks to file, delete + filter global marks
		local filtered_marks = M.filter_marks(cwd)
		print("FILTERED_MARKS 1: " .. vim.inspect(filtered_marks))
		-- config.del_marks(filtered_marks)
		local gen_config = M.generate_config(cwd, filtered_marks)

		local success, err = M.write_file(path, gen_config)

		if not success then
			vim.notify("Error creating file" .. err, vim.log.levels.ERROR, { title = "marko.nvim" })
			return nil, err
		end

		return gen_config
	end
end

return M
