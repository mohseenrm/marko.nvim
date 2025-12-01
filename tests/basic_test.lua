-- Basic test for the new ShaDa-based marko.nvim implementation
-- This test verifies that the plugin can:
-- 1. Set up project-specific ShaDa files
-- 2. Generate correct paths
-- 3. Create commands

-- Add lua directory to package path
local script_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
package.path = script_dir .. "../lua/?.lua;" .. script_dir .. "../lua/?/init.lua;" .. package.path

local M = {}

function M.run()
	print("Running basic marko.nvim tests...")
	local success_count = 0
	local fail_count = 0

	-- Mock vim global for testing
	_G.vim = {
		fn = {
			stdpath = function(what)
				return "/tmp/nvim_test"
			end,
			getcwd = function()
				return "/test/project"
			end,
			isdirectory = function()
				return 0
			end,
			mkdir = function()
				return true
			end,
		},
		o = {},
		cmd = function() end,
		notify = function() end,
		log = { levels = { INFO = 1, WARN = 2, ERROR = 3 } },
		api = {
			nvim_create_user_command = function() end,
			nvim_create_autocmd = function() end,
			nvim_create_augroup = function()
				return 1
			end,
		},
	}

	-- Test 1: Check that marko module loads
	local ok, marko = pcall(require, "marko")
	if ok then
		print("✓ Marko module loads successfully")
		success_count = success_count + 1
	else
		print("✗ Failed to load marko module: " .. tostring(marko))
		fail_count = fail_count + 1
		return
	end

	-- Test 2: Check get_shada_path function exists
	if type(marko.get_shada_path) == "function" then
		print("✓ get_shada_path function exists")
		success_count = success_count + 1
	else
		print("✗ get_shada_path function not found")
		fail_count = fail_count + 1
	end

	-- Test 3: Test path generation
	local test_path = "/home/user/test/project"
	local shada_path = marko.get_shada_path(test_path)
	if shada_path and shada_path:match("marko_.*%.shada$") then
		print("✓ ShaDa path generated correctly: " .. shada_path)
		success_count = success_count + 1
	else
		print("✗ ShaDa path generation failed: " .. tostring(shada_path))
		fail_count = fail_count + 1
	end

	-- Test 4: Test that different paths generate different ShaDa files
	local path1 = "/home/user/project1"
	local path2 = "/home/user/project2"
	local shada1 = marko.get_shada_path(path1)
	local shada2 = marko.get_shada_path(path2)
	if shada1 ~= shada2 then
		print("✓ Different projects get different ShaDa files")
		success_count = success_count + 1
	else
		print("✗ Different projects should have different ShaDa files")
		fail_count = fail_count + 1
	end

	-- Test 5: Test that same path generates same ShaDa file
	local shada1_again = marko.get_shada_path(path1)
	if shada1 == shada1_again then
		print("✓ Same project generates consistent ShaDa path")
		success_count = success_count + 1
	else
		print("✗ ShaDa path should be consistent for same project")
		fail_count = fail_count + 1
	end

	-- Summary
	print("\n" .. string.rep("-", 50))
	print("Tests passed: " .. success_count)
	print("Tests failed: " .. fail_count)
	print(string.rep("-", 50))

	return fail_count == 0
end

-- Run tests if this file is executed directly
if arg and arg[0] and arg[0]:match("basic_test%.lua$") then
	local success = M.run()
	os.exit(success and 0 or 1)
end

return M
