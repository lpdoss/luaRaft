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
  SuspendNode = function(proxy, message)
    suspendNodeFlag = true
    -- Send back timeout for the sender to know when the message was expected to timeout
    respMessage = { timeout=message.timeout, node = port, type = "SuspendNodeResp", value = "ok"}
    resp = proxy.SendMessage(respMessage)
    if (resp ~= "Message Received") then
      print("Couldn`t send message ", respMessage)
    end
  end,
  SuspendNodeResp = function(proxy, message)
    print("Node " .. message.node .. " was successfully suspended.")
    if sentMessagesLine[message.timeout] ~= nil then
      table.remove(sentMessagesLine[message.timeout], message)
    end
  end
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
  print("[NODE " .. port ..  "] Processing message")
  for k,v in pairs(message) do
    print(k,v)
  end
  local nodeProxy = clusterNodesProxies[message.node]
  if (messageTypes[message.type] ~= nil) then
    messageTypes[message.type](nodeProxy, message)
  end  
  print("[NODE " .. port ..  "] Processed message")
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
    message = { timeout=messageTimeout, node=port, type="SuspendNode", value="" }
    local resp = proxy.SendMessage(message)
    print ("[NODE " .. port .. "] Return message: " .. resp)
    if (resp ~= "Message Received") then
      print ("Couldn`t send message " .. message.type .. " to node " .. message.node)
      return 
    end
    addSentMessage(message)
    print("Sent suspend message")
  end,
  -- 
  SendMessage = function (messageStruct)
    print("[NODE " .. port .. "] Message received:")
    for k,v in pairs(messageStruct) do
      print("[NODE " .. port .. "] " .. k .. ": " .. v .. ".")
    end
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
    print("[NODE " .. port .. "] Initializing node ")
    tick = 0
    suspendNodeFlag = false
    clusterNodesProxies = {}
    print("[NODE " .. port .. "] Initialized node ")
    -- create proxies to other nodes
    print("[NODE " .. port ..  "] Creating clusters")
    for _,node in ipairs(clusterNodes) do
        clusterNodesProxies[node] = luarpc.createProxy(IP, node, arq_interface)
    end
    print("[NODE " .. port ..  "] Created clusters")
    --
    while true do
      print("[NODE " .. port ..  "] Executing cycle " .. tick)
      -- Check if there are any received messages to be treated
      while #receivedMessagesLine > 0 do
        processMessage(receivedMessagesLine[1])
        table.remove(receivedMessagesLine, 1)
      end
      -- Check if there are any sent messages waiting a returning call
      if #sentMessagesLine > 0 and sentMessagesLine[tick] ~= nil  then
        for _, message in ipairs(sentMessagesLine[tick]) do
          print("[NODE" .. port .. "] Timeout reached for node " .. message.node .. ", message " .. message.type)
        end
      end
      -- Increment server clock
      if suspendNodeFlag then break end
      print("[NODE " .. port ..  "] Finished executing cycle " .. tick)
      luarpc.wait(cycleTimeout)
      tick = tick + 1
    end
    print("[NODE ", port, "] lifecycle suspendend")
  end
}

luarpc.createServant(nodeImpl, arq_interface, port)
luarpc.waitIncoming()
