local config = require("marko.config")
local M = {}

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

function M.get_config(path)
	-- create marks path if does not exist, create new file and save content for cwd
	local res = M.check_path(path)
	local cwd = vim.fn.getcwd()
  local test = config.filter_marks(cwd)
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
    return base_config
	else
		-- path does not exist
		local success, err = M.create_path(path)

		if not success then
			vim.notify("Error creating file path" .. err, vim.log.levels.ERROR, { title = "marko.nvim" })
			return nil, err
		end

		local success, err = M.write_file(path, base_config)

		if not success then
			vim.notify("Error creating file" .. err, vim.log.levels.ERROR, { title = "marko.nvim" })
			return nil, err
		end

		return base_config
	end

	return base_config
end

return M
