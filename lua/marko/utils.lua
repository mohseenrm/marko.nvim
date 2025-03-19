local M = {}

-- Get a value from a table, with an optional default value if the key doesn't exist
-- @param tbl The table to get the value from
-- @param key The key to look up
-- @param default Optional default value to return if the key doesn't exist
-- @return The value at tbl[key] if it exists, otherwise the default value (or nil)
function M.get(tbl, key, default)
	if tbl == nil then
		return default
	end

	local value = tbl[key]
	if value == nil then
		return default
	end

	return value
end

-- Safely navigate a nested table structure using a list of keys
-- @param tbl The table to traverse
-- @param keys A list of keys to navigate through the table
-- @param default Optional default value to return if any key in the path doesn't exist
-- @return The value at the end of the path if it exists, otherwise the default value (or nil)
function M.get_nested(tbl, keys, default)
	if tbl == nil then
		return default
	end

	local current = tbl
	for _, key in ipairs(keys) do
		if type(current) ~= "table" then
			return default
		end

		current = current[key]
		if current == nil then
			return default
		end
	end

	return current
end

return M
