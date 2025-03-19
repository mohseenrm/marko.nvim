#\!/usr/bin/env lua

-- Add current directory and project paths to package path
package.path = package.path .. ";./?.lua;./lua/?.lua;./lua/?/init.lua"

-- Try to load the marko module
print("Loading marko.lua")
local ok, marko = pcall(require, "marko")
print("Load result:", ok)
print("Type of marko:", type(marko))

if ok then
    -- Try to inspect marko
    if type(marko) == "table" then
        print("marko.setup:", type(marko.setup))
        print("Keys in marko:")
        for k, v in pairs(marko) do
            print("", k, type(v))
        end
    else
        print("marko value:", marko)
    end
end

-- Try to load marko.config directly
print("\nLoading marko.config")
local ok2, config = pcall(require, "marko.config")
print("Load result:", ok2)
print("Type of config:", type(config))

if ok2 then
    -- Try to inspect config
    if type(config) == "table" then
        print("Keys in config:")
        for k, v in pairs(config) do
            print("", k, type(v))
        end
    else
        print("config value:", config)
    end
end
