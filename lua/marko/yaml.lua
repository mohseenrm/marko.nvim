local M = {}

-- Parse a value to its native type (number, boolean, etc.)
local function parse_value(value)
	if not value then
		return nil
	end

	if value == "true" then
		return true
	elseif value == "false" then
		return false
	elseif value == "null" or value == "~" or value == "" then
		return nil
	elseif value:match("^%s*%d+%s*$") then
		-- Integer value
		return tonumber(value)
	elseif value:match("^%s*%d+%.%d+%s*$") then
		-- Float value
		return tonumber(value)
	else
		-- String value
		return value
	end
end

-- Tokenize YAML content
function M.tokenize(content)
	local tokens = {}
	local lines = {}

	-- Split content into lines
	for line in content:gmatch("[^\r\n]+") do
		table.insert(lines, line)
	end

	for idx, line in ipairs(lines) do
		-- Skip empty lines and comments
		if not (line:match("^%s*$") or line:match("^%s*#")) then
			local indent = line:match("^(%s*)")
			local stripped = line:match("^%s*(.*)$")
			local key, value = stripped:match("^([^:]+):%s*(.*)$")

			-- Process key-value pairs
			if key and value then
				-- Trim the key and remove any "- " prefix
				key = key:match("^%s*(.-)%s*$")
				if key:match("^-%s") then
					key = key:match("^-%s+(.+)$")
				end

				-- Parse the value to its native type
				local trimmed_value = value:match("^%s*(.-)%s*$")
				local parsed_value = parse_value(trimmed_value)

				table.insert(tokens, {
					"KEY_VALUE",
					key = key,
					value = parsed_value,
					raw_value = trimmed_value,
					indent = #indent,
					line = idx,
					raw = line,
				})
			elseif stripped:match("^-%s+(.+)$") then
				-- List item
				local item = stripped:match("^-%s+(.+)$")
				local trimmed_item = item:match("^%s*(.-)%s*$")
				local parsed_item = parse_value(trimmed_item)

				table.insert(tokens, {
					"LIST_ITEM",
					value = parsed_item,
					raw_value = trimmed_item,
					indent = #indent,
					line = idx,
					raw = line,
				})
			elseif stripped:match("^-$") then
				-- Empty list item
				table.insert(tokens, {
					"LIST_ITEM",
					value = nil,
					raw_value = "",
					indent = #indent,
					line = idx,
					raw = line,
				})
			else
				-- Handle other patterns
				local parsed_value = parse_value(stripped)
				table.insert(tokens, {
					"TEXT",
					value = parsed_value,
					raw_value = stripped,
					indent = #indent,
					line = idx,
					raw = line,
				})
			end
		end
	end

	return tokens
end

-- Parse tokenized YAML into Lua table
function M.eval(content)
	local tokens = M.tokenize(content)
	local result = {}
	local stack = { { table = result, key = nil } }
	local levels = { 0 }
	local current_level = 0
	local current_table = result
	local list_mode = false
	local list_key = nil

	for _, token in ipairs(tokens) do
		local token_type = token[1]

		if token_type == "KEY_VALUE" then
			if token.indent > current_level then
				-- New indentation level
				current_level = token.indent
				local new_table = {}
				current_table[stack[#stack].key] = new_table
				table.insert(stack, { table = new_table, key = nil })
				table.insert(levels, current_level)
				current_table = new_table
				list_mode = false
			elseif token.indent < current_level then
				-- Return to previous indentation level
				while #levels > 1 and token.indent < levels[#levels] do
					table.remove(stack)
					table.remove(levels)
				end
				current_level = levels[#levels]
				current_table = stack[#stack].table
				list_mode = false
			end

			if token.value == "" then
				-- Key with empty value (will be a table)
				stack[#stack].key = token.key
				current_table[token.key] = {}
			else
				-- Simple key-value
				current_table[token.key] = token.value
				stack[#stack].key = token.key
			end
		elseif token_type == "LIST_ITEM" then
			if not list_mode then
				-- First list item
				list_mode = true
				list_key = stack[#stack].key
				current_table[list_key] = {}
			end

			-- Add item to list
			table.insert(current_table[list_key], token.value)
		end
	end

	return result
end

-- Dump a Lua table (for debugging)
function M.dump(tbl, indent)
	if not indent then
		indent = 0
	end
	local indent_str = string.rep("  ", indent)

	for k, v in pairs(tbl) do
		if type(v) == "table" then
			print(indent_str .. tostring(k) .. ":")
			M.dump(v, indent + 1)
		else
			print(indent_str .. tostring(k) .. ": " .. tostring(v))
		end
	end
end

-- Parse YAML file and return Lua table
function M.parse_file(file_path)
	local file = io.open(file_path, "rb")
	if not file then
		return nil, "Failed to open file: " .. file_path
	end

	local content = file:read("*all")
	file:close()

	return M.eval(content)
end

-- Parse YAML string and return Lua table
function M.parse_string(yaml_string)
	if not yaml_string then
		return nil, "No YAML string provided"
	end

	return M.eval(yaml_string)
end

return M

