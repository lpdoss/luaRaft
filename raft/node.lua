package.path = "../?.lua;" .. package.path
local luarpc = require("luarpc")
local utils = require("utils")
local messageTypes = require("messageTypes")
local nodeProperties = require("nodeProperties")
local nodeStates = require("nodeStates")
local generalRules = require("generalRules")
local logReplicationRules = require("logReplicationRules")
local leaderElectionRules = require("leaderElectionRules")
local arq_interface = "interface.lua"

-- Initialize
for i, value in ipairs(arg) do
    if (value == "v" or value == "verbose") then
      nodeProperties.verbose = true
    elseif i == 1 then
        nodeProperties.port = tonumber(value)
    else
        table.insert(nodeProperties.clusterNodes, tonumber(value))
    end
end

-- Create the node methods implementation 
local nodeImpl = {
  ApplyEntry = function(entry)
    if (nodeProperties.verbose) then
      print("----------Apply Entry - enter----------")
    end
    -- If not leader, redirect to leader
    if (nodeProperties.state ~= nodeStates.Leader) then
      -- Must use another proxy to avoid connection being closed
      local tempProxy = luarpc.createProxy(nodeProperties.IP, nodeProperties.leaderId, arq_interface, nodeProperties.verbose)
      local r= tempProxy.ApplyEntry(entry)
      return r
    end
    local messageCommitIndex = logReplicationRules.AddEntryToLog(nodeProperties, nodeProperties.term, entry)
    while (nodeProperties.commitIndex < messageCommitIndex) do 
      if (nodeProperties.verbose) then
        print("Node commit index:", nodeProperties.commitIndex)
        print("Append entry index:", messageCommitIndex)
      end
      if (nodeProperties.state ~= nodeStates.Leader) then
        return "Error: Node lost leadership before commiting entry. try again..."
      end
      luarpc.wait(nodeProperties.heartbeatTimeout, nodeProperties.verbose)
    end
    if (nodeProperties.verbose) then
      print("Apply Entry - left")
    end
    return "Entry successfully commited"
  end,
  StopNode = function()
    nodeProperties.keepAlive = false
  end,
  Snapshot = function()
    print("[NODE" .. nodeProperties.port .. "] State Snapshot")
    print("State: ", nodeProperties.state)
    print("Term: ", nodeProperties.term)
    print("Leader: ", nodeProperties.leaderId)
    print("VotedFor: ", nodeProperties.votedFor)
    print("Last log ID: ", nodeProperties.lastLogIndex)
    print("Commit ID: ", nodeProperties.commitIndex)
    if (nodeProperties.state == nodeStates.Leader) then
      print("Node next ID:")
      for k,v in pairs(nodeProperties.nodeNextIndex) do
        print(k, "-", v)
      end
      print("Node match ID:")
      for k,v in pairs(nodeProperties.nodeMatchIndex) do
        print(k, "-", v)
      end
    end
    print("Log:")
    for k,v in pairs(nodeProperties.log) do
      print(k, "- Term:", v.term, "Value:", v.value)
    end
  end,
  -- 
  ReceiveMessage = function (messageStruct)
    if (nodeProperties.verbose) then
      print("[NODE " .. nodeProperties.port .. "] Message received")
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
  InitializeNode = function ()
    generalRules.InitializeNodeState(nodeProperties, arq_interface)
    while nodeProperties.keepAlive do
      if (nodeProperties.verbose) then
        print("[NODE " .. nodeProperties.port ..  "] Executing cycle " .. nodeProperties.heartbeat .. " as " .. nodeProperties.state)
      end
      if (nodeProperties.verbose) then
        print("[NODE " .. nodeProperties.port ..  "] Processing received messages ")
      end
      utils.ProcessReceivedMessages(nodeProperties, messageTypes, generalRules, logReplicationRules, leaderElectionRules)
      if (nodeProperties.verbose) then
        print("[NODE " .. nodeProperties.port ..  "] Processing sent messages")
      end
      utils.ProcessSentMessages(nodeProperties)
      -- Leader
      if (nodeProperties.verbose) then
        print("[NODE " .. nodeProperties.port ..  "] Executing leader flow")
      end
      if (nodeProperties.state == nodeStates.Leader) then
        logReplicationRules.LeaderUpdateCommitIndex(nodeProperties)
        logReplicationRules.SendAppendEntry(nodeProperties)
      end
      -- Candidate or Follower | Check if should start election
      if (nodeProperties.verbose) then
        print("[NODE " .. nodeProperties.port ..  "] Executing candidate or follower flow")
      end
      leaderElectionRules.StartElection(nodeProperties)
      -- Wait 1 cycle and update node state
      if (nodeProperties.verbose) then
        print("[NODE " .. nodeProperties.port ..  "] Finished executing cycle " .. nodeProperties.heartbeat)
      end
      luarpc.wait(nodeProperties.heartbeatTimeout, nodeProperties.verbose)
      generalRules.TickNodeClock(nodeProperties)
    end
    if (nodeProperties.verbose) then
      print("[NODE ", nodeProperties.port, "] lifecycle suspendend")
    end
  end
}

luarpc.createServant(nodeImpl, arq_interface, nodeProperties.port, nodeProperties.verbose)
luarpc.waitIncoming(nodeProperties.verbose)
