-- Tests for the config.lua module

describe("config", function()
	local test_init = require("tests.init")
	local test_utils = require("tests.utils")
	local mock_files = test_init.mock_files

	-- Global references for tests
	local config
	local marko
	local restore_marks

	before_each(function()
		-- Load clean modules for each test
		package.loaded["marko.config"] = nil
		package.loaded["marko"] = nil

		-- Setup mock marks
		restore_marks = test_utils.setup_mock_marks()

		config = require("marko.config")
		marko = require("marko")
	end)

	after_each(function()
		-- Restore original functions
		if restore_marks then
			restore_marks()
		end
	end)

	describe("clear_all_marks", function()
		it("should delete all marks", function()
			-- Spy on the del_mark function
			local spy = test_utils.spy(vim.api, "nvim_del_mark")

			config.clear_all_marks()

			-- Should have 26 calls (A-Z)
			assert.are.same(#spy.calls, 26)

			-- Restore original function
			spy.restore()
		end)
	end)

	describe("del_marks", function()
		it("should delete all marks except skipped ones", function()
			-- Spy on the del_mark function
			local spy = test_utils.spy(vim.api, "nvim_del_mark")

			-- Skip marks A and B
			config.del_marks({ "A", "B" })

			-- Should have 24 calls (26 marks - 2 skipped)
			assert.are.same(#spy.calls, 24)

			-- Verify A and B were not deleted
			local deleted_marks = {}
			for _, call in ipairs(spy.calls) do
				table.insert(deleted_marks, call[1])
			end

			assert.is_false(vim.tbl_contains(deleted_marks, "A"))
			assert.is_false(vim.tbl_contains(deleted_marks, "B"))

			-- Restore original function
			spy.restore()
		end)
	end)

	describe("save_current_marks", function()
		it("should save marks for the current directory", function()
			-- Set up spies
			local notify_spy = test_utils.spy(vim, "notify")

			-- Prepare mock config path
			local config_path = "/test/home/.local/share/nvim/marko/config.yaml"

			-- Call the function
			local result = config.save_current_marks()

			-- Verify result
			assert.is_true(result)

			-- Verify the config file was created
			assert.is_not_nil(mock_files[config_path])

			-- Cleanup
			notify_spy.restore()
		end)
	end)

	describe("load_full_config", function()
		it("should load and parse the config file", function()
			-- Set up test config
			local config_path = "/test/home/.local/share/nvim/marko/config.yaml"
			mock_files[config_path] = test_utils.create_test_config()

			-- Load the config
			local result = config.load_full_config()

			-- Verify the config was loaded
			assert.is_table(result)
			assert.is_table(result["/test/project"])
			assert.is_table(result["/another/project"])

			-- Check specific content
			assert.are.same(#result["/test/project"], 2)
			assert.are.same(#result["/another/project"], 1)
		end)

		it("should handle empty or missing config", function()
			-- Clear any existing config files
			for k in pairs(mock_files) do
				mock_files[k] = nil
			end

			-- No config file
			local result = config.load_full_config()

			-- Should return empty table
			assert.is_table(result)
			-- Check if the table is empty
			local is_empty = true
			for _ in pairs(result) do
				is_empty = false
				break
			end
			assert.is_true(is_empty)
		end)
	end)

	describe("set_marks_from_config", function()
		it("should set marks from the config", function()
			-- Set up test config
			local config_path = "/test/home/.local/share/nvim/marko/config.yaml"
			mock_files[config_path] = test_utils.create_test_config()

			-- Override the getcwd function to match our test project path
			local orig_getcwd = vim.fn.getcwd
			vim.fn.getcwd = function()
				return "/test/project"
			end

			-- Load the config first (required for set_marks_from_config)
			config.load_full_config()

			-- Spy on the set_mark function
			local spy = test_utils.spy(vim.api, "nvim_buf_set_mark")

			-- Call the function
			local result = config.set_marks_from_config()

			-- Verify result
			assert.is_true(result)

			-- Verify marks were set
			assert.are.same(#spy.calls, 2) -- Two marks for /test/project

			-- Cleanup
			spy.restore()
			vim.fn.getcwd = orig_getcwd
		end)
	end)

	describe("delete_config_file", function()
		it("should delete the config file", function()
			-- Set up test config
			local config_path = "/test/home/.local/share/nvim/marko/config.yaml"
			mock_files[config_path] = test_utils.create_test_config()

			-- Spy on os.remove
			local orig_remove = os.remove
			local remove_called = false
			os.remove = function(path)
				remove_called = true
				mock_files[path] = nil
				return true
			end

			-- Call the function
			local result = config.delete_config_file()

			-- Verify result
			assert.is_true(result)
			assert.is_true(remove_called)
			assert.is_nil(mock_files[config_path])

			-- Restore original function
			os.remove = orig_remove
		end)
	end)

	describe("ensure_buffer_filetype", function()
		it("should set filetype for buffers without one", function()
			-- Set up a buffer with no filetype
			local get_option_spy = test_utils.spy(vim.api, "nvim_get_option_value")
			local set_option_spy = test_utils.spy(vim.api, "nvim_set_option_value")

			-- Override get_option to return empty string (no filetype)
			vim.api.nvim_get_option_value = function(option, opts)
				return ""
			end

			-- Call the function
			local result = config.ensure_buffer_filetype(1)

			-- Verify result
			assert.is_true(result)

			-- Verify set_option was called with filetype
			assert.are.same(#set_option_spy.calls, 1)
			assert.are.same(set_option_spy.calls[1][1], "filetype")
			assert.are.same(set_option_spy.calls[1][2], "lua") -- From the mock

			-- Restore original functions
			get_option_spy.restore()
			set_option_spy.restore()
		end)
	end)

	describe("setup", function()
		it("should create user commands", function()
			-- Spy on create_user_command
			local spy = test_utils.spy(vim.api, "nvim_create_user_command")

			-- Call setup
			config.setup()

			-- Verify commands were created
			assert.are.same(#spy.calls, 3) -- MarkoSave, MarkoReload, MarkoDeleteConfig

			-- Check specific commands
			local command_names = {}
			for _, call in ipairs(spy.calls) do
				table.insert(command_names, call[1])
			end

			assert.is_true(vim.tbl_contains(command_names, "MarkoSave"))
			assert.is_true(vim.tbl_contains(command_names, "MarkoReload"))
			assert.is_true(vim.tbl_contains(command_names, "MarkoDeleteConfig"))

			-- Restore original function
			spy.restore()
		end)

		it("should create autocmds", function()
			-- Spy on create_autocmd
			local spy = test_utils.spy(vim.api, "nvim_create_autocmd")

			-- Call setup
			config.setup()

			-- Verify autocmds were created
			assert.are.same(#spy.calls, 3) -- UIEnter, BufEnter, QuitPre

			-- Check specific events
			local events = {}
			for _, call in ipairs(spy.calls) do
				table.insert(events, call[1])
			end

			assert.is_true(vim.tbl_contains(events, "UIEnter"))
			assert.is_true(vim.tbl_contains(events, "BufEnter"))
			assert.is_true(vim.tbl_contains(events, "QuitPre"))

			-- Restore original function
			spy.restore()
		end)
	end)
end)
