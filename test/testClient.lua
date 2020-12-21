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
  p.InitializeNode(5)

-- Broadcast
elseif test == 1 then -- server calls itself
  local porta2 = tonumber(arg[4])
  local p = luarpc.createProxy(IP, porta, arq_interface, true)
  print(p.ReceiveMessage({timeout= 10, fromNode=porta2, toNode=porta, type="BroadcastMessage", value="0;2"}))

  -- Test send message
elseif test == 2 then -- server calls itself
  local p = luarpc.createProxy(IP, porta, arq_interface, false)
  local porta2 = tonumber(arg[4])
  print(p.TestSendMessage({timeout= 5, fromNode=porta, toNode=porta2, type="TestTimeout", value=""}))

end