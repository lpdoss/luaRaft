package.path = "../?.lua;" .. package.path
local luarpc = require("luarpc")
local sckt = require("socket")

local arq_interface = arg[1]
local test = tonumber(arg[2])
local porta = tonumber(arg[3])

local IP = "127.0.0.1"
-- START NODE
if test == 0 then 
  local p = luarpc.createProxy(IP, porta, arq_interface, false)
  p.InitializeNode()

-- STOP NODE
elseif test == 1 then -- server calls itself
  local p = luarpc.createProxy(IP, porta, arq_interface, false)
  p.StopNode()

-- EXTERNAL APPEND ENTRIES
elseif test == 2 then
  local p = luarpc.createProxy(IP, porta, arq_interface, false)
  print(p.ApplyEntry(tonumber(arg[4])))

elseif test == 3 then
  local p = luarpc.createProxy(IP, porta, arq_interface, false)
  p.Snapshot()
end