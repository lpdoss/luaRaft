package.path = "../?.lua;" .. package.path
local luarpc = require("luarpc")
local utils = require("utils")
local messageTypes = require("messageTypes")
local nodeProperties = require("nodeProperties")
local arq_interface = "interface.lua"

-- Initialize
for i, value in ipairs(arg) do
    if i == 1 then
        nodeProperties.port = tonumber(value)
    else
        table.insert(nodeProperties.clusterNodes, tonumber(value))
    end
end

-- Create the node methods implementation 
local nodeImpl = {
  TestSendMessage = function(messageStruct)
    print("[NODE " .. nodeProperties.port .. "] TestSendMessage - enter")
    local proxy = nodeProperties.clusterNodesProxies[messageStruct.toNode]
    if (proxy == nil) then
      print("Node " .. messageStruct.toNode .. " is not in the cluster.")
      return
    end
    --
    messageStruct.timeout = nodeProperties.tick + 5
    local resp = proxy.ReceiveMessage(messageStruct)
    print ("[NODE " .. nodeProperties.port .. "] Return message: " .. resp)
    if (resp ~= "Message Received") then
      print ("Couldn`t send message " .. messageStruct.type .. " to node " .. messageStruct.toNode)
      return 
    end
    utils.addSentMessage(nodeProperties, messageStruct)
    print("Sent suspend message")
    print("[NODE " .. nodeProperties.port .. "] TestSendMessage - left")
  end,
  -- 
  ReceiveMessage = function (messageStruct)
    print("[NODE " .. nodeProperties.port .. "] Message received:")
    for k,v in pairs(messageStruct) do
      print("[NODE " .. nodeProperties.port .. "] " .. k .. ": " .. v .. ".")
    end
    local nodeProxy = nodeProperties.clusterNodesProxies[messageStruct.fromNode]
    if (nodeProxy == nil) then
      return "Calling node is not in the cluster."
    end

    if messageTypes[messageStruct.type] ~= nil then
      table.insert(nodeProperties.receivedMessagesLine, messageStruct)
      return "Message Received"
    end
    return "Invalid Message Type"
  end,
  --
  InitializeNode = function (cycleTimeout)
    -- reinitialize node properties
    print("[NODE " .. nodeProperties.port .. "] Initializing node ")
    nodeProperties.tick = 0
    nodeProperties.suspendNodeFlag = false
    nodeProperties.clusterNodesProxies = {}
    print("[NODE " .. nodeProperties.port .. "] Initialized node ")
    -- create proxies to other nodes
    print("[NODE " .. nodeProperties.port ..  "] Creating clusters")
    for _,node in ipairs(nodeProperties.clusterNodes) do
      nodeProperties.clusterNodesProxies[node] = luarpc.createProxy(nodeProperties.IP, node, arq_interface)
    end
    
    print("[NODE " .. nodeProperties.port ..  "] Created clusters")
    --
    while true do
      print("[NODE " .. nodeProperties.port ..  "] Executing cycle " .. nodeProperties.tick)
      -- Check if there are any received messages to be treated
      while #nodeProperties.receivedMessagesLine > 0 do
        local messageToProcess = table.remove(nodeProperties.receivedMessagesLine, 1)
        utils.processReceivedMessage(nodeProperties, messageTypes, messageToProcess)
      end
      -- Check if there are any sent messages waiting a returning call
      if nodeProperties.sentMessagesLine[nodeProperties.tick] ~= nil  then
        for _, nodeList in pairs(nodeProperties.sentMessagesLine[nodeProperties.tick]) do
          for _, message in ipairs(nodeList) do
            print("[NODE" .. nodeProperties.port .. "] Timeout reached for node ", message.fromNode, ", message ", message.type)
          end
        end
      end
      -- Increment server clock
      if nodeProperties.suspendNodeFlag then break end
      print("[NODE " .. nodeProperties.port ..  "] Finished executing cycle " .. nodeProperties.tick)
      luarpc.wait(cycleTimeout)
      nodeProperties.tick = nodeProperties.tick + 1
    end
    print("[NODE ", nodeProperties.port, "] lifecycle suspendend")
  end
}

luarpc.createServant(nodeImpl, arq_interface, nodeProperties.port)
luarpc.waitIncoming()
