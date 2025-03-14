local file = require("marko.file")
local utils = require("marko.utils")

local M = {}

local marks_path = os.getenv("HOME") .. "/.local/share/nvim/marko/config.yaml"

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

-- iterate over marks, skips mark if part of table skip, else calls vim.api.nvim_del_mark
function M.del_marks(skipped_marks)
	print("SKIPPED_MARKS: " .. vim.inspect(skipped_marks))
	for _, mark in ipairs(marks) do
		if not vim.tbl_contains(skipped_marks, mark) then
			vim.api.nvim_del_mark(mark)
		end
	end
end

-- Function to save the current directory's marks
function M.save_current_marks()
	local cwd = vim.fn.getcwd()
	vim.notify("Saving marks for: " .. cwd, vim.log.levels.INFO, { title = "marko.nvim" })

	-- Use our improved filter_marks function to get current marks
	local curr_marks = file.filter_marks(cwd)

	-- Debug what we found
	if #curr_marks > 0 then
		vim.notify("Found " .. #curr_marks .. " marks to save", vim.log.levels.INFO, { title = "marko.nvim" })

		-- List each mark for debugging
		for _, mark in ipairs(curr_marks) do
			local content = vim.api.nvim_get_mark(mark, {})
			if content and content[4] then
				vim.notify("Mark " .. mark .. " at " .. content[4], vim.log.levels.DEBUG, { title = "marko.nvim" })
			end
		end
	else
		vim.notify("No marks found to save", vim.log.levels.WARN, { title = "marko.nvim" })
	end

	-- Force save all marks for this directory
	local result = file.save_directory_marks(marks_path, cwd)

	-- Verify what was saved
	if result and result[cwd] then
		local saved_count = #result[cwd]
		vim.notify(
			"Successfully saved " .. saved_count .. " marks for " .. cwd,
			vim.log.levels.INFO,
			{ title = "marko.nvim" }
		)
		return true
	else
		vim.notify("No marks saved for " .. cwd, vim.log.levels.WARN, { title = "marko.nvim" })
		return false
	end
end

function M.setup()
	-- Create user command to manually save marks
	vim.api.nvim_create_user_command("MarkoSave", function()
		M.save_current_marks()
	end, { desc = "Save marks for current directory" })

	-- Load marks when Neovim starts and save any current marks
	vim.api.nvim_create_autocmd("UIEnter", {
		callback = function()
			vim.notify(
				"Initializing marko.nvim for directory: " .. vim.fn.getcwd(),
				vim.log.levels.INFO,
				{ title = "marko.nvim" }
			)

			-- Force save current marks
			M.save_current_marks()
		end,
	})

	-- Save marks when Neovim exits
	vim.api.nvim_create_autocmd("VimLeavePre", {
		callback = function()
			M.save_current_marks()
		end,
	})

	-- Also save marks on buffer write
	vim.api.nvim_create_autocmd("BufWritePost", {
		callback = function()
			M.save_current_marks()
		end,
	})
end

return M
