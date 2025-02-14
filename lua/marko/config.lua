local M = {}

local marks = {"A", "B", "C", "D", "E", "F", "G", "H"}

function M.filter_marks(project_path)
  -- enumerate over marks, check if valid and if starts with project_path
  print("PROJECT_PATH: " .. project_path)
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

function M.setup()
  vim.api.nvim_create_autocmd("UIEnter", {
    callback = function()
      local project_path = vim.fn.getcwd()
      local filtered_marks = M.filter_marks(project_path)
      print("FILTERED_MARKS: " .. vim.inspect(filtered_marks))
    end,
  })
end

return M

