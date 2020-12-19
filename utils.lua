local math = require("math")
math.randomseed(os.time()) -- random initialize
math.random(); math.random(); math.random() -- warming up

local Utils = {}

function Utils.isEmpty(s)
  return s == nil or s == ''
end
--[[
   Calculates the time to wait before starting new election
   Params: 
      Table - Raft Node properties 
   Returns:
      Integer with the nexElection wait time in digital clocks
]]--
function Utils.getElectionTime(nodeProperties)
  return nodeProperties.heartbeat + math.random(nodeProperties.electionTimeoutMin, nodeProperties.electionTimeoutMax)
end

--[[
   Include a message in the sentMessagesLine.
   If there is a line at the message timeout, append to the line. Else create the line.
   Params: 
      Table - Raft Node properties 
      Table - Message to add to the sent line. Message format is defined on interface.lua
   Returns:
      Nothing
]]--
function Utils.addSentMessage(nodeProperties, message)
  if (nodeProperties.sentMessagesLine[message.timeout] ~= nil) then
    if nodeProperties.sentMessagesLine[message.timeout][message.toNode] ~= nil then
      table.insert(nodeProperties.sentMessagesLine[message.timeout][message.toNode], message)
    else
      nodeProperties.sentMessagesLine[message.timeout][message.toNode] = { message }
    end
  else
    nodeProperties.sentMessagesLine[message.timeout] = {}
    nodeProperties.sentMessagesLine[message.timeout][message.toNode] = { message }
  end
end

--[[
   Remove a message in the sentMessagesLine.
   If there is a line at the message timeout, search the message in this line.
   Params: 
      Table - Raft Node properties 
      Table - Message to remove from the sent line. Message format is defined on interface.lua
   Returns:
      Nothing
]]--
function Utils.removeSentMessage(nodeProperties, message)
  if (nodeProperties.sentMessagesLine[message.timeout] ~= nil) then
    if (nodeProperties.sentMessagesLine[message.timeout][message.fromNode] ~= nil) then
      for  k,v in pairs(nodeProperties.sentMessagesLine[message.timeout][message.fromNode]) do
        if v.type == message.type then
          table.remove(nodeProperties.sentMessagesLine[message.timeout][message.fromNode], k)
        end
      end
    end
  end
end

--[[
    Process the message in the line.
    If the received message type exist on the valid messages table, execute the related callback.
    Params:
      Table - Raft Node properties
      Table - Valid Message types. Table has the message type for key and the message callback for the value.
      Table - Received message to process. Message format is defined on interface.lua
    Returns:
      Nothing
]]--
function Utils.processReceivedMessage(nodeProperties, messageTypes, message, generalRules, logReplicationRules, leaderElectionRules)
  if (nodeProperties.verbose) then
    print("[NODE " .. nodeProperties.port ..  "] Processing message")
    for k,v in pairs(message) do
      print(k,v)
    end
  end
  if (messageTypes[message.type] ~= nil) then
    messageTypes[message.type](nodeProperties, message, generalRules, logReplicationRules, leaderElectionRules)
  end
  if (nodeProperties.verbose) then  
    print("[NODE " ..  nodeProperties.port ..  "] Processed message")
  end
end

--[[ 
  Check if the received list contains the element. 
  Params:
    Table - list of values to be checked.
    Element - element to be found in the list.
  Returns:
    bool indicating if element exist or not in the list.
]]--
function Utils.containsElement(list, element)
  for _, value in pairs(list) do
    if value == element then
      return true
    end
  end
  return false
end

--[[ 
  Build and send a message through a proxy
  Params:
    
  Returns:
    bool indicating if message was sent successfully
]]--
function Utils.BuildAndSendMessage(tout, from, to, type, vl, proxy)
  local message = { 
    timeout = tout, 
    fromNode = from,
    toNode = to, 
    type = type, 
    value = vl
  }
  resp = proxy.ReceiveMessage(message)
  if (resp ~= "Message Received") then
    print("[NODE " .. from .. "] Unable to send message", type, "to", to)
    return false
  end
  return true
end

function Utils.ProcessReceivedMessages(nodeProperties, messageTypes, generalRules, logReplicationRules, leaderElectionRules)
  while #nodeProperties.receivedMessagesLine > 0 do
    local messageToProcess = table.remove(nodeProperties.receivedMessagesLine, 1)
    Utils.processReceivedMessage(nodeProperties, messageTypes, messageToProcess, generalRules, logReplicationRules, leaderElectionRules)
  end
end

function Utils.ProcessSentMessages(nodeProperties)
  if nodeProperties.sentMessagesLine[nodeProperties.heartbeat] ~= nil  then
    for _, nodeList in pairs(nodeProperties.sentMessagesLine[nodeProperties.heartbeat]) do
      for _, message in ipairs(nodeList) do
        print("[NODE" .. nodeProperties.port .. "] Timeout reached for node ", message.fromNode, ", message ", message.type)
      end
    end
  end
end

return Utils
