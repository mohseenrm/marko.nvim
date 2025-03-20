-- Test utilities for marko.nvim

local M = {}

-- Create a simple YAML config for testing
M.create_test_config = function()
	return [[
/test/project:
  - mark: "A"
    data:
      row: 10
      col: 0
      buffer: 1
      filename: "/test/project/test.lua"
  - mark: "B"
    data:
      row: 20
      col: 5
      buffer: 1
      filename: "/test/project/another.lua"
/another/project:
  - mark: "C"
    data:
      row: 15
      col: 2
      buffer: 1
      filename: "/another/project/test.lua"
]]
end

-- Create a mock mark object for testing
M.create_test_mark = function(mark, row, col, buffer, filename)
	return {
		mark = mark,
		row = row,
		col = col,
		buffer = buffer,
		filename = filename or "/test/project/test.lua",
	}
end

-- Create mock get_mark results
M.setup_mock_marks = function()
	local orig_get_mark = vim.api.nvim_get_mark

	vim.api.nvim_get_mark = function(mark, opts)
		if mark == "A" then
			return { 10, 0, 1, "/test/project/test.lua" }
		elseif mark == "B" then
			return { 20, 5, 1, "/test/project/another.lua" }
		elseif mark == "C" then
			return { 15, 2, 1, "/another/project/test.lua" }
		else
			return { 0, 0, 0, "" }
		end
	end

	return function()
		vim.api.nvim_get_mark = orig_get_mark
	end
end

-- Spy on function calls
M.spy = function(obj, method_name)
	local orig_method = obj[method_name]
	local calls = {}

	obj[method_name] = function(...)
		table.insert(calls, { ... })
		return orig_method(...)
	end

	return {
		calls = calls,
		restore = function()
			obj[method_name] = orig_method
		end,
	}
end

return M
