package.path = "../?.lua;" .. package.path
local utils = require("utils")
local messageTypes = 
{
  SuspendNode = function(nodeProperties, message)
    local proxy = nodeProperties.clusterNodesProxies[message.fromNode]
    if proxy == nil then
      print("There is no proxy for node " .. message.fromNode)
      return
    end
    nodeProperties.suspendNodeFlag = true
    -- Send back timeout for the sender to know when the message was expected to timeout
    respMessage = { 
      timeout = message.timeout, 
      fromNode = nodeProperties.port,
      toNode = message.fromNode, 
      type = "SuspendNodeResp", 
      value = "ok"
    }
    resp = proxy.SendMessage(respMessage)
    if (resp ~= "Message Received") then
      print("Couldn`t send message ", respMessage)
    end
  end,
  SuspendNodeResp = function(nodeProperties, message)
    print("Node " .. message.fromNode .. " was successfully suspended.")
    utils.removeSentMessage(nodeProperties, message)
  end,
  BroadcastMessage = function(nodeProperties, message)
    print("[NODE " .. nodeProperties.port .. "] BroadcastMessage - entered")
    local proxy = nodeProperties.clusterNodesProxies[message.fromNode]
    if proxy == nil then
      print("There is no proxy for node " .. message.fromNode)
      return
    end
    -- Expected value is a semicolon separated list
    callerLevel, maxLevel = string.match(message.value, "(.-);(.*)")
    print("[NODE " .. nodeProperties.port .. "] BroadcastMessage - Parsed message parameters: callerLevel = " .. callerLevel .. ", maxLevel = " .. maxLevel)
    -- if necessary send the messages
    callerLevel = tonumber(callerLevel)
    maxLevel = tonumber(maxLevel)
    local currentLevel = callerLevel + 1
    if (currentLevel <= maxLevel) then
      print("[NODE " .. nodeProperties.port .. "] BroadcastMessage - forwarding broadcast")
      local msgTimeout = nodeProperties.tick + 5
      for clusterNode,clusterProxy in pairs(nodeProperties.clusterNodesProxies) do
        if clusterNode ~= message.fromNode then        
            print("[NODE " .. nodeProperties.port .. "] BroadcastMessage - forwarding to cluster ", clusterNode, clusterProxy)
            fwdMessage = { 
              timeout = msgTimeout, 
              fromNode = nodeProperties.port,
              toNode = clusterNode, 
              type = "BroadcastMessage", 
              value = currentLevel .. ";" .. maxLevel
            }
            resp = clusterProxy.SendMessage(fwdMessage)
            if (resp ~= "Message Received") then
              print("[NODE " .. nodeProperties.port .. "] BroadcastMessage - Unable to forward to node ", clusterNode)
            else
              print("[NODE " .. nodeProperties.port .. "] BroadcastMessage - adding to sent list for node ", clusterNode)
              utils.addSentMessage(nodeProperties, fwdMessage)
            end
        end
      end
    end
    -- respond original message
    print("[NODE " .. nodeProperties.port .. "] BroadcastMessage - responding original call")
    respMessage = { 
      timeout = message.timeout, 
      fromNode = nodeProperties.port,
      toNode = message.fromNode, 
      type = "BroadcastMessageResp", 
      value = "ok"
    }
    resp = proxy.SendMessage(respMessage)
    if (resp ~= "Message Received") then
      print("[NODE " .. nodeProperties.port .. "] BroadcastMessage - couldn't send resp to ", message.fromNode)
    end
    print("[NODE " .. nodeProperties.port .. "] BroadcastMessage - left")
  end,
  BroadcastMessageResp = function(nodeProperties, message)
    print("[NODE " .. nodeProperties.port .. "] BroadcastMessageResp - broadcast to " .. message.fromNode .. " was successfully executed.")
    utils.removeSentMessage(nodeProperties, message)
  end,
  TestTimeout = function(nodeProperties, message) {
    print("[NODE " .. nodeProperties.port .. "] TestTimeout - enter")
    print("[NODE " .. nodeProperties.port .. "] TestTimeout - left")
  }
}

return messageTypes