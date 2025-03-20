-- Test initialization file for marko.nvim

-- Mock common neovim functions
local mock = {}

-- Mock vim global
_G.vim = {
	fn = {
		getcwd = function()
			return "/test/project"
		end,
		filereadable = function(path)
			-- Return 1 for all paths (both original and expanded)
			return 1
		end,
		has = function(feature)
			-- Return 1 for all feature checks (including nvim-0.10)
			return 1
		end,
		bufadd = function(path)
			return 1
		end,
		bufload = function(buf)
			return true
		end,
		fnameescape = function(path)
			return path
		end,
		fnamemodify = function(path, modifier)
			if modifier == ":h" then
				-- Return the parent directory
				return path:match("(.*/)") or path
			end
			return path
		end,
		isdirectory = function(path)
			-- Return 1 for all directories
			return 1
		end,
		mkdir = function(path, mode)
			-- Return 1 to indicate success
			return 1
		end,
	},
	api = {
		nvim_del_mark = function(mark)
			return true
		end,
		nvim_buf_get_name = function(buf)
			return "/test/project/test.lua"
		end,
		nvim_list_bufs = function()
			return { 1 }
		end,
		nvim_buf_is_valid = function(buf)
			return true
		end,
		nvim_get_option_value = function(option, opts)
			return ""
		end,
		nvim_set_option_value = function(option, value, opts)
			return true
		end,
		nvim_create_user_command = function(name, callback, opts)
			return true
		end,
		nvim_create_autocmd = function(event, opts)
			return true
		end,
		nvim_create_augroup = function(name, opts)
			return 1
		end,
		nvim_command = function(cmd)
			return true
		end,
		nvim_buf_set_mark = function(buffer, mark, row, col, opts)
			-- Added check to match the expanded line range check in utils.lua
			return true
		end,
		nvim_buf_line_count = function(buffer)
			-- Return a large enough line count for tests
			return 100
		end,
		nvim_get_mark = function(mark, opts)
			return { 1, 0, 1, "/test/project/test.lua" }
		end,
	},
	notify = function(msg, level, opts)
		return true
	end,
	filetype = {
		match = function(opts)
			return "lua"
		end,
	},
	log = {
		levels = {
			ERROR = 1,
			WARN = 2,
			INFO = 3,
			DEBUG = 4,
		},
	},
	tbl_contains = function(tbl, val)
		for _, v in ipairs(tbl) do
			if v == val then
				return true
			end
		end
		return false
	end,
	tbl_keys = function(tbl)
		local keys = {}
		for k, _ in pairs(tbl) do
			table.insert(keys, k)
		end
		return keys
	end,
	deepcopy = function(orig)
		local copy
		if type(orig) == "table" then
			copy = {}
			for orig_key, orig_value in next, orig, nil do
				copy[vim.deepcopy(orig_key)] = vim.deepcopy(orig_value)
			end
			setmetatable(copy, vim.deepcopy(getmetatable(orig)))
		else
			copy = orig
		end
		return copy
	end,
	ui = {
		select = function(items, opts, on_choice)
			-- Simulate selecting "Yes"
			on_choice("Yes")
		end,
	},
}

-- Mock os functions
os.getenv = function(var)
	if var == "HOME" then
		return "/test/home"
	end
	return nil
end

os.execute = function(cmd)
	return 0
end
os.remove = function(path)
	return true
end
os.time = function()
	return 1000
end

-- Mock io functions
local mock_files = {}

io.open = function(path, mode)
	if mode == "r" and not mock_files[path] then
		return nil
	end

	return {
		read = function(self, format)
			if mock_files[path] then
				return mock_files[path]
			else
				return ""
			end
		end,
		write = function(self, content)
			mock_files[path] = content
			return true
		end,
		close = function(self)
			return true
		end,
	}
end

-- Export mocks for test use
return {
	mock = mock,
	mock_files = mock_files,

	-- Helper functions
	setup_test = function()
		-- Clear mock state
		mock_files = {}

		-- Reset require cache for marko modules
		package.loaded["marko"] = nil
		package.loaded["marko.config"] = nil
		package.loaded["marko.file"] = nil
		package.loaded["marko.utils"] = nil
		package.loaded["marko.yaml"] = nil

		-- Make sure paths are available
		package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

		-- Return the freshly loaded module
		return require("marko")
	end,
}
