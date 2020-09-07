package.path = "../?.lua;" .. package.path
local luarpc = require("luarpc")
local arq_interface = "interface.lua"

-- Initialize default port and empty cluster.
-- Should receive in the arguments the port to listen and the ports of all nodes in the cluster.
local IP = "127.0.0.1"
local port = 8000 
local clusterNodes = {}
local clusterNodesProxies = {}
for i, value in ipairs(arg) do
    if i == 1 then
        port = tonumber(value)
    else
        table.insert(clusterNodes, tonumber(value))
    end
end

-- 
local suspendNodeFlag = false
local receivedMessagesLine = {}   
local sentMessagesLine = {}   
local messageTypes = 
{
  "SuspendNode",
  "SuspendNodeResp"
}
-- create local methods implementation
function containsElement(list, element)
  for _, value in pairs(list) do
    if value == element then
      return true
    end
  end
  return false
end

local function processMessage(message)
  nodeProxy = clusterNodesProxies[message.node] -- already checked that exist when receiving the message
  if (message.type == "SuspendNode") then
    suspendNodeFlag = true
    respMessage = { node = port, type = "SuspendNodeResp", value = "ok"}
    resp = nodeProxy.SendMessage(respMessage)
    if (resp ~= "Message Received") then
      print ("Couldn`t send message ", respMessage)
    return
  end
  --[[
  if (message.type == "SuspendNodeResp") then
     if containsElement(sentMessagesLine, { node = message.node, type = message.type}) then
      return
     end
  ]]--
end



-- Create the node methods implementation 
local nodeImpl = {
  SendMessage = function (messageStruct)
    print("Message received: ", messageStruct)
    local nodeProxy = clusterNodesProxies[messageStruct.node]
    if (nodeProxy == nil) then
      return "Calling node is not in the cluster."
    end
    if containsElement(messageTypes, messageStruct.type) then
      table.insert(receivedMessagesLine, messageStruct)
      return "Message Received"
    end
    return "Invalid Message Type"
  end,
  InitializeNode = function (cycleTimeout)
    -- reinitialize node properties
    tick = 0
    suspendNodeFlag = false
    -- create proxies to other nodes
    for _,node in clusterNodes do
        clusterNodesProxies[node] = luarpc.CreateProxy(IP, node, arq_interface))
    end
    -- lifecycle loop
    while true do
      print("Executing node ", node, " cycle ", tick)
      while #receivedMessagesLine > 0 do
        print("Processing message: ", messageStruct)
        processMessage(receivedMessagesLine[1])
        table.remove(receivedMessagesLine, 1)
        print("Processed message: ", messageStruct)
      end
      luarpc.wait(cycleTimeout)
      tick += 1
      if suspendNodeFlag then break end
    end
    print("Node ", node, " lifecycle suspendend")
  end
}

luarpc.createServant(nodeImpl, arq_interface, port)
luarpc.waitIncoming()
