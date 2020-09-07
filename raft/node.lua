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
local tick = 0
local suspendNodeFlag = false
local receivedMessagesLine = {}   
local sentMessagesLine = {}   
local messageTypes = 
{
  SuspendNode = SuspendNodeAction,
  SuspendNodeResp = SuspendNodeRespAction
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

--[[
   The sentMessagesLine is a table. 
   The key is the server clock when the messages will timeout.
   The value is a list of messages that will timeout in the key value.
]]--
function addSentMessage(message)
  if (sentMessagesLine[message.timeout] ~= nil) then
    table.insert(sentMessagesLine[message.timeout], message)
  else
    sentMessagesLine[message.timeout] = { message }
  end
end

--[[
    Each valid message type has a related message action that is triggered when the message is received.
]]--
local function processMessage(message)
  nodeProxy = clusterNodesProxies[message.node]
  messageAction = messageTypes[message.type]
  if (messageAction ~= nil) then
    messageAction(nodeProxy, message)
  end  
end
-- Set the suspend flag to true and send the SuspendNodeResp to the original node
local function SuspendNodeAction(proxy, message)
    suspendNodeFlag = true
    -- Send back timeout for the sender to know when the message was expected to timeout
    respMessage = { timeout=message.timeout, node = port, type = "SuspendNodeResp", value = "ok"}
    resp = proxy.SendMessage(respMessage)
    if (resp ~= "Message Received") then
      print ("Couldn`t send message ", respMessage)
    end
end
-- Acknowledge the conclusion of the suspension
local function SuspendNodeRespAction(proxy, message)
  print ("Node " .. message.node .. " was successfully suspended.")
  if sentMessagesLine[message.timeout] ~= nil then
    table.remove(sentMessagesLine[message.timeout], message)
  end
end

-- Create the node methods implementation 
local nodeImpl = {
  StartTest1 = function(node)
    local proxy = clusterNodesProxies[node]
    if (proxy == nil) then
      print("Node " .. node .. " is not in the cluster.")
      return
    end
    print ("Beginning test 1")
    messageTimeout = tick + 5
    message = { timeout=messageTimeout, node=node, type="SuspendNode", value="" }
    local resp = proxy.SendMessage(message)
    if (resp ~= "Message Received") then
      print ("Couldn`t send message " .. message.type .. " to node " .. message.node)
      return 
    end
    addSentMessage(message)
    print("Sent suspend message")
  end
  -- 
  SendMessage = function (messageStruct)
    print("Message received: ", messageStruct)
    local nodeProxy = clusterNodesProxies[messageStruct.node]
    if (nodeProxy == nil) then
      return "Calling node is not in the cluster."
    end

    if messageTypes[messageStruct.type] ~= nil then
      table.insert(receivedMessagesLine, messageStruct)
      return "Message Received"
    end
    return "Invalid Message Type"
  end,
  --
  InitializeNode = function (cycleTimeout)
    -- reinitialize node properties
    tick = 0
    suspendNodeFlag = false
    clusterNodesProxies = {}
    -- create proxies to other nodes
    for _,node in clusterNodes do
        clusterNodesProxies[node] = luarpc.CreateProxy(IP, node, arq_interface))
    end
    --
    while true do
      print("Executing node ", node, " cycle ", tick)
      -- Check if there are any received messages to be treated
      while #receivedMessagesLine > 0 do
        print("Processing message: ", messageStruct)
        processMessage(receivedMessagesLine[1])
        table.remove(receivedMessagesLine, 1)
        print("Processed message: ", messageStruct)
      end
      -- Check if there are any sent messages waiting a returning call
      if #sentMessagesLine > 0 and sentMessagesLine[tick] ~= nil  then
        for _, message in sentMessagesLine[tick] do
          print("Timeout reached for node " .. message.node .. ", message " .. message.type)
        end
      end
      -- Increment server clock
      luarpc.wait(cycleTimeout)
      tick += 1
      if suspendNodeFlag then break end
    end
    print("Node ", node, " lifecycle suspendend")
  end
}

luarpc.createServant(nodeImpl, arq_interface, port)
luarpc.waitIncoming()
