package.path = "../?.lua;" .. package.path
local luarpc = require("luarpc")
local socket = require("socket")

local porta0 = 8000
local porta1 = 8001
local porta2 = 8002
local IP = "127.0.0.1"
local arq_interface = "interface.lua"
local lock = false
local myobj2 = {
  foo = function (a, s, st, n)
    luarpc.wait(10)
    return a*2, string.len(s) + st.idade + n 
  end,
  boo = function (n)
    --print("\t>>> [SVR2] INSIDE BOO = ", n, "\n")
    lock = true
    lockCount = 0
    while lock do
      luarpc.wait(5)
      lockCount = lockCount + 1
    end
    return lockCount
    -- return 25
  end,
  boo2 = function (n)
    --local p = luarpc.createProxy(IP, porta2, arq_interface) -- never enters but never leaves ??
    --local r1 = p.easy(n)
    lock = false
    return n
  end
}

luarpc.createServant(myobj2, "interface.lua", porta1)
luarpc.waitIncoming()
