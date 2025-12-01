-- Import globals to fix luacheck warnings
require("marko.globals")

local M = {}

-- Store options for the plugin
M.options = {
	debug = false,
}

-- Get the ShaDa directory for marko
local function get_shada_dir()
	local state_dir = vim.fn.stdpath("state")
	return state_dir .. "/marko"
end

-- Generate a stable identifier for a directory path
local function get_project_id(path)
	-- Use the absolute path directly, but create a safe filename
	-- Replace / with _ and remove any special characters
	local safe_path = path:gsub("/", "_"):gsub("[^%w_-]", "")
	return safe_path
end

-- Get the ShaDa file path for current working directory
function M.get_shada_path(cwd)
	cwd = cwd or vim.fn.getcwd()
	local project_id = get_project_id(cwd)
	local shada_dir = get_shada_dir()
	return shada_dir .. "/marko_" .. project_id .. ".shada"
end

-- Set up project-specific ShaDa file
local function setup_project_shada()
	local cwd = vim.fn.getcwd()
	local shada_path = M.get_shada_path(cwd)
	local shada_dir = get_shada_dir()

	-- Create marko shada directory if it doesn't exist
	if vim.fn.isdirectory(shada_dir) == 0 then
		vim.fn.mkdir(shada_dir, "p")
		if M.options.debug then
			vim.notify("Created ShaDa directory: " .. shada_dir, vim.log.levels.INFO, { title = "marko.nvim" })
		end
	end

	-- Set the shadafile option to project-specific path
	vim.o.shadafile = shada_path

	if M.options.debug then
		vim.notify(
			"Using project-specific ShaDa: " .. shada_path,
			vim.log.levels.INFO,
			{ title = "marko.nvim" }
		)
	end

	-- Load the ShaDa file for this project
	-- This will restore marks, registers, etc. from previous sessions
	local ok, err = pcall(function()
		vim.cmd("rshada!")
	end)

	if not ok and M.options.debug then
		vim.notify(
			"Note: Could not load ShaDa (this is normal for new projects): " .. tostring(err),
			vim.log.levels.INFO,
			{ title = "marko.nvim" }
		)
	end
end

function M.setup(opts)
	-- Process options
	opts = opts or {}

	-- Merge provided options with defaults
	for k, v in pairs(opts) do
		M.options[k] = v
	end

	-- Set up project-specific ShaDa file immediately
	setup_project_shada()

	-- Create user commands
	vim.api.nvim_create_user_command("MarkoInfo", function()
		local cwd = vim.fn.getcwd()
		local shada_path = M.get_shada_path(cwd)
		local exists = vim.fn.filereadable(shada_path) == 1

		local info = {
			"=== Marko Info ===",
			"Current directory: " .. cwd,
			"ShaDa file: " .. shada_path,
			"ShaDa exists: " .. (exists and "yes" or "no"),
			"",
			"Active global marks:",
		}

		-- List all global marks
		local mark_count = 0
		for i = 65, 90 do -- A-Z
			local mark = string.char(i)
			local pos = vim.api.nvim_get_mark(mark, {})
			if pos[1] > 0 and pos[4] and pos[4] ~= "" then
				table.insert(info, string.format("  '%s -> %s:%d:%d", mark, pos[4], pos[1], pos[2]))
				mark_count = mark_count + 1
			end
		end

		if mark_count == 0 then
			table.insert(info, "  (no marks set)")
		end

		vim.notify(table.concat(info, "\n"), vim.log.levels.INFO, { title = "marko.nvim" })
	end, { desc = "Show Marko project info and marks" })

	vim.api.nvim_create_user_command("MarkoClean", function()
		local cwd = vim.fn.getcwd()
		local shada_path = M.get_shada_path(cwd)

		if vim.fn.filereadable(shada_path) == 0 then
			vim.notify("No ShaDa file exists for this project", vim.log.levels.WARN, { title = "marko.nvim" })
			return
		end

		vim.ui.select({ "Yes", "No" }, {
			prompt = "Delete ShaDa file for this project? (This will clear all marks, history, registers)",
		}, function(choice)
			if choice == "Yes" then
				local success = os.remove(shada_path)
				if success then
					-- Clear all marks in current session
					for i = 65, 90 do
						vim.api.nvim_del_mark(string.char(i))
					end
					vim.notify("Deleted ShaDa file and cleared marks", vim.log.levels.INFO, { title = "marko.nvim" })
				else
					vim.notify("Failed to delete ShaDa file", vim.log.levels.ERROR, { title = "marko.nvim" })
				end
			else
				vim.notify("Cancelled", vim.log.levels.INFO, { title = "marko.nvim" })
			end
		end)
	end, { desc = "Delete ShaDa file for current project" })

	vim.api.nvim_create_user_command("MarkoList", function()
		local shada_dir = get_shada_dir()
		local files = vim.fn.globpath(shada_dir, "*.shada", false, true)

		if #files == 0 then
			vim.notify("No project ShaDa files found", vim.log.levels.INFO, { title = "marko.nvim" })
			return
		end

		local info = { "=== Marko Projects ===" }
		for _, file in ipairs(files) do
			local filename = vim.fn.fnamemodify(file, ":t:r")
			local size = vim.fn.getfsize(file)
			table.insert(info, string.format("  %s (%d bytes)", filename, size))
		end

		vim.notify(table.concat(info, "\n"), vim.log.levels.INFO, { title = "marko.nvim" })
	end, { desc = "List all project ShaDa files" })

	vim.api.nvim_create_user_command("MarkoSave", function()
		local ok, err = pcall(function()
			vim.cmd("wshada!")
		end)
		if ok then
			vim.notify("Saved ShaDa for current project", vim.log.levels.INFO, { title = "marko.nvim" })
		else
			vim.notify("Failed to save ShaDa: " .. tostring(err), vim.log.levels.ERROR, { title = "marko.nvim" })
		end
	end, { desc = "Manually save ShaDa for current project" })

	vim.api.nvim_create_user_command("MarkoMark", function(args)
		local mark = args.args

		-- Validate mark is provided and is a capital letter
		if not mark or not mark:match("^%u$") then
			vim.notify("Please provide a valid mark (A-Z)", vim.log.levels.ERROR, { title = "marko.nvim" })
			return
		end

		-- Get current cursor position
		local cursor = vim.api.nvim_win_get_cursor(0)
		local row = cursor[1]
		local col = cursor[2]

		-- Set the mark using vim command (simplest and most reliable)
		vim.cmd("normal! m" .. mark)

		vim.notify(
			string.format("Set mark '%s at line %d, col %d", mark, row, col),
			vim.log.levels.INFO,
			{ title = "marko.nvim" }
		)
	end, { nargs = 1, desc = "Set a global mark (A-Z)" })

	-- Auto-save ShaDa when Neovim exits
	vim.api.nvim_create_autocmd("VimLeavePre", {
		callback = function()
			local ok, err = pcall(function()
				vim.cmd("wshada!")
			end)
			if not ok and M.options.debug then
				vim.notify("Failed to save ShaDa on exit: " .. tostring(err), vim.log.levels.WARN, { title = "marko.nvim" })
			end
		end,
		group = vim.api.nvim_create_augroup("MarkoAutoSave", { clear = true }),
	})

	return M
end

return M
