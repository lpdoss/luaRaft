package.path = "../?.lua;" .. package.path
local luarpc = require("luarpc")
local sckt = require("socket")

local porta1 = 8000
local porta2 = 8001
local arq_interface = arg[1]
local test = tonumber(arg[2])

local IP = "127.0.0.1"


local p1 = luarpc.createProxy(IP, porta1, arq_interface)

local p2 = luarpc.createProxy(IP, porta2, arq_interface)

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 1 server
if test == 0 then -- server makes simple call like in our first RPC version
  local p1 = luarpc.createProxy(IP, porta1, arq_interface)
  p1.StartTest1(porta2)

elseif test == 1 then -- server calls itself
  local r = p1.call_yourself(3, 7)
  print("\n RES p1.call_yourself(3,7) = 3x10 + 7x7 =",r,"\n")

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 2 servers
elseif test == 2 then -- server 8000 makes RPC call to port 8001
  local r = p1.dummy(10)
  print("\n RES p1.dummy(10) = ",r, "\n")

  local r, s = p1.complex_foo(3, "alo", {nome = "ana", idade = 20, peso = 57.0}, 2)
  print("\n RES p1.complex_foo = ",r, s, "\n")

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 3 servers
elseif test == 3 then -- server 8000 makes call to 8001 and 8001 makes call to 8002
  local r = p1.dummy2(10)
  print("\n RES p1.dummy2(10) = ",r)

elseif test == 4 then
  local r, s = p1.complex_foo(3, "alo", {nome = "ana", idade = 20, peso = 57.0}, 2)
  print("\n RES p1.complex_foo = ",r, s, "\n")

elseif test == 5 then
  local r = p2.boo(25)
  print("\n RES p2.boo = ", r, "\n")

elseif test == 6 then
  local r = p1.call_yourself(5,4)
  print("\n RES p1.call_yourself = ", r, "\n")

elseif test == 7 then
  local r = p2.boo(1)
  print("\n RES p2.boo = ", r, "\n")  

elseif test == 8 then
  local r, s = p2.foo(3, "alo", {nome = "ana", idade = 20, peso = 57.0}, 2)
  print("\n RES p2.foo = ",r, s, "\n")
  local r = p2.boo2(1)
  print("\n RES p2.boo = ", r, "\n")  

else
  print("\n Please select a value between 0-3 to select the type of test you want to run")
end
