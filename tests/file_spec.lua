-- Tests for the file.lua module

describe("file", function()
	local test_init = require("tests.init")
	local test_utils = require("tests.utils")
	local mock_files = test_init.mock_files

	-- Global references for tests
	local file

	before_each(function()
		-- Load clean modules for each test
		package.loaded["marko.file"] = nil
		file = require("marko.file")

		-- Set up mock mark data
		test_utils.setup_mock_marks()
	end)

	describe("filter_marks", function()
		it("should return marks that belong to the project path", function()
			local filtered = file.filter_marks("/test/project")
			assert.are.same(#filtered, 3) -- Now 3 marks with the tilde path
			assert.is_true(vim.tbl_contains(filtered, "A"))
			assert.is_true(vim.tbl_contains(filtered, "B"))
			assert.is_true(vim.tbl_contains(filtered, "D")) -- The tilde path mark
			assert.is_false(vim.tbl_contains(filtered, "C"))
			assert.is_false(vim.tbl_contains(filtered, "E"))
		end)

		it("should handle paths with and without trailing slash", function()
			local filtered1 = file.filter_marks("/test/project")
			local filtered2 = file.filter_marks("/test/project/")

			assert.are.same(#filtered1, 3) -- Now 3 marks with the tilde path
			assert.are.same(#filtered2, 3) -- Now 3 marks with the tilde path
		end)

		it("should not include marks from other projects", function()
			local filtered = file.filter_marks("/another/project")
			assert.are.same(#filtered, 2) -- Now 2 marks with the tilde path
			assert.is_true(vim.tbl_contains(filtered, "C"))
			assert.is_true(vim.tbl_contains(filtered, "E")) -- The tilde path mark
			assert.is_false(vim.tbl_contains(filtered, "A"))
			assert.is_false(vim.tbl_contains(filtered, "B"))
			assert.is_false(vim.tbl_contains(filtered, "D"))
		end)
	end)

	describe("parse_config", function()
		it("should parse YAML config correctly", function()
			local config = file.parse_config(test_utils.create_test_config())

			assert.is_table(config)
			assert.is_table(config["/test/project"])
			assert.is_table(config["/another/project"])

			assert.are.same(#config["/test/project"], 3) -- Now 3 with tilde path
			assert.are.same(#config["/another/project"], 2) -- Now 2 with tilde path

			-- Check specific mark data
			local mark_a = config["/test/project"][1]
			assert.are.same(mark_a.mark, "A")
			assert.are.same(mark_a.row, 10)
			assert.are.same(mark_a.col, 0)
			assert.are.same(mark_a.filename, "/test/project/test.lua")

			-- Check tilde path mark
			local mark_d = config["/test/project"][3]
			assert.are.same(mark_d.mark, "D")
			assert.are.same(mark_d.row, 30)
			assert.are.same(mark_d.col, 0)
			assert.are.same(mark_d.filename, "~/test/project/tilde_path.lua")
		end)

		it("should handle empty input", function()
			local config = file.parse_config("")
			assert.is_table(config)
			assert.are.same(next(config), nil) -- Empty table
		end)
	end)

	describe("file operations", function()
		it("should check if a file exists", function()
			-- Set up mock file
			mock_files["/test/file.txt"] = "content"

			assert.is_true(file.check_path("/test/file.txt"))
			assert.is_false(file.check_path("/nonexistent/file.txt"))
		end)

		it("should read and write files", function()
			local content = "test content"

			-- Write content
			local success = file.write_file("/test/write.txt", content)
			assert.is_true(success)

			-- Read content back
			local read_content = file.read_file("/test/write.txt")
			assert.are.same(read_content, content)
		end)
	end)

	describe("save_directory_marks", function()
		it("should save marks for the current directory", function()
			local marks_path = "/test/home/.local/share/nvim/marko/config.yaml"
			local result = file.save_directory_marks(marks_path, "/test/project")

			-- Verify the file was written
			assert.is_not_nil(mock_files[marks_path])

			-- Verify the config contains the expected marks
			assert.is_table(result)
			assert.is_table(result["/test/project"])
			assert.are.same(#result["/test/project"], 3) -- Now 3 with tilde path
		end)

		it("should preserve existing marks for other directories", function()
			local marks_path = "/test/home/.local/share/nvim/marko/config.yaml"

			-- Create a file with existing content
			mock_files[marks_path] = test_utils.create_test_config()

			-- Save new marks for test project
			local result = file.save_directory_marks(marks_path, "/test/project")

			-- Verify both directories were preserved
			assert.is_table(result)
			assert.is_table(result["/test/project"])
			assert.is_table(result["/another/project"])
		end)
	end)
end)
