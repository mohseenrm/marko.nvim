-- Define global variables to avoid Luacheck warnings
-- These are standard Lua globals and APIs

-- Lua standard library
_G.arg = arg
_G.io = io
_G.os = os
_G.string = string
_G.table = table
_G.math = math
_G.type = type
_G.tostring = tostring
_G.tonumber = tonumber
_G.pairs = pairs
_G.ipairs = ipairs
_G.error = error
_G.pcall = pcall
_G.print = print
_G.require = require
_G.package = package

return {}


