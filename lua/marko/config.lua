local M = {}

local marks = {"A", "B", "C", "D", "E", "F", "G", "H"}

function M.filter_marks(project_path)
  -- enumerate over marks, check if valid and if starts with project_path
  print("PROJECT_PATH: " .. project_path)
  local filtered_marks = {}
  for _, mark in ipairs(marks) do
    print("MARK: " .. mark)
    local content = vim.api.nvim_get_mark("C", {})
    local valid = content and content[1] > 0 and content[2] > 0 and content[3] > 0 and content[4] ~= ""
    local mark_path = content[4]
    print("MARK_PATH: " .. content[1])
    print("MARK_PATH: " .. content[2])
    print("MARK_PATH: " .. content[3])
    print("MARK_PATH: " .. mark_path)
    local in_project = mark_path:match(project_path) ~= nil

    if valid and in_project then
      print("MARK: " .. mark .. " " .. mark_path)
      table.insert(filtered_marks, mark)
    end
  end
  return filtered_marks
end

return M
