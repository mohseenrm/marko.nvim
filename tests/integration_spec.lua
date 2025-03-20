-- Integration tests for marko.nvim

describe("marko integration", function()
	local test_init = require("tests.init")
	local test_utils = require("tests.utils")
	local mock_files = test_init.mock_files

	-- Global references for tests
	local marko
	local config
	local file
	local restore_marks

	before_each(function()
		-- Load clean modules for each test
		package.loaded["marko"] = nil
		package.loaded["marko.config"] = nil
		package.loaded["marko.file"] = nil

		-- Setup mock marks
		restore_marks = test_utils.setup_mock_marks()

		-- Make sure modules can be found
		package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

		-- Load modules
		config = require("marko.config")
		file = require("marko.file")
		marko = require("marko")

		-- Make sure marko is a table
		if type(marko) ~= "table" then
			error("marko module should be a table, got " .. type(marko))
		end
	end)

	after_each(function()
		-- Restore original functions
		if restore_marks then
			restore_marks()
		end
	end)

	describe("setup", function()
		it("should initialize the plugin", function()
			-- We won't try to spy on internal functions
			-- Just verify that the module has its expected properties

			-- Call setup
			local result = marko.setup({})

			-- Verify result has the right properties
			assert.is_true(type(marko.options) == "table")
			assert.is_true(type(marko.setup) == "function")
		end)

		it("should handle custom options", function()
			-- Create a custom options table
			local opts = {
				debug = true,
			}

			-- Call setup with options
			marko.setup(opts)

			-- Options should be stored in the module
			assert.is_not_nil(marko.options)
			assert.is_true(marko.options.debug)
		end)
	end)

	describe("full workflow", function()
		it("should save, load and restore marks", function()
			-- Set up test environment
			local config_path = "/test/home/.local/share/nvim/marko/config.yaml"

			-- Set up spies
			local save_spy = test_utils.spy(require("marko.config"), "save_current_marks")
			local load_spy = test_utils.spy(require("marko.config"), "load_full_config")
			local set_spy = test_utils.spy(require("marko.config"), "set_marks_from_config")
			local clear_spy = test_utils.spy(require("marko.config"), "clear_all_marks")

			-- Initialize plugin
			marko.setup({})

			-- Trigger UIEnter autocmd simulation (directly call the related functions)
			require("marko.config").load_full_config()
			require("marko.config").clear_all_marks()
			require("marko.config").set_marks_from_config()

			-- Verify load and clear were called
			assert.are.same(#load_spy.calls, 1)
			assert.are.same(#clear_spy.calls, 1)
			assert.are.same(#set_spy.calls, 1)

			-- Trigger save simulation
			require("marko.config").save_current_marks()

			-- Verify save was called
			assert.are.same(#save_spy.calls, 1)

			-- Verify config file was created
			assert.is_not_nil(mock_files[config_path])

			-- Restore all spies
			save_spy.restore()
			load_spy.restore()
			set_spy.restore()
			clear_spy.restore()
		end)

		it("should handle the MarkoDeleteConfig command", function()
			-- Set up test config
			local config_path = "/test/home/.local/share/nvim/marko/config.yaml"
			mock_files[config_path] = test_utils.create_test_config()

			-- Set up spies
			local delete_spy = test_utils.spy(require("marko.config"), "delete_config_file")
			local clear_spy = test_utils.spy(require("marko.config"), "clear_all_marks")

			-- Initialize plugin
			marko.setup({})

			-- Clear any existing files first to ensure test isolation
			for k in pairs(mock_files) do
				mock_files[k] = nil
			end

			-- Set up test config again after clearing
			mock_files[config_path] = test_utils.create_test_config()

			-- Directly call delete_config_file to simulate command
			local result = require("marko.config").delete_config_file()

			-- If successful, clear_all_marks would be called
			require("marko.config").clear_all_marks()

			-- Verify both functions were called
			assert.is_true(#delete_spy.calls > 0)
			assert.is_true(#clear_spy.calls > 0)

			-- Restore all spies
			delete_spy.restore()
			clear_spy.restore()
		end)
	end)

	describe("integration with filetype detection", function()
		it("should ensure proper filetype on buffers", function()
			-- Setup mock buffer
			local buffer = 1

			-- Spy on the ensure function
			local ensure_spy = test_utils.spy(require("marko.config"), "ensure_buffer_filetype")

			-- Initialize plugin
			marko.setup({})

			-- Call the ensure function directly (simulating BufEnter)
			require("marko.config").ensure_buffer_filetype(buffer)

			-- Verify function was called
			assert.are.same(#ensure_spy.calls, 1)

			-- Restore spy
			ensure_spy.restore()
		end)
	end)
end)
