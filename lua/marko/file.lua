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

  -- TODO: create child file
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
	else
		print("HERE 2")
		-- path does not exist
		local success, err = M.create_path(path)

		if err then
			vim.notify("Error creating file path" .. err, vim.log.levels.ERROR, { title = "marko.nvim" })
			return nil, err
		end

		local success, err = M.write_file(path, base_config)

		if err then
			vim.notify("Error creating file" .. err, vim.log.levels.ERROR, { title = "marko.nvim" })
			return nil, err
		end

		return base_config
	end

	local dir = path:match("(.*/)")
	if dir then
		local success, err = M.create_path(dir)
		if not success then
			return nil, err
		end
	end

	-- if it does, read and parse content
	local content, err = M.read_file(path)
	if not content then
		-- If the file does not exist, create it
		local success, err = M.create_file(path)
		if not success then
			return nil, err
		end
		return {}
	end

	local config = load("return " .. content)()
	return config
end

return M
