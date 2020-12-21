package.path = "../?.lua;" .. package.path
local utils = require("utils")
local generalRules = require("generalRules")
local nodeStates = require("nodeStates")
local math = require("math")
local LogReplication = {}

function LogReplication.LeaderUpdateCommitIndex(nodeProperties)
  if (nodeProperties.verbose) then
    print("[NODE " .. nodeProperties.port .. "] Leader - Updating commit index")
  end
  if (nodeProperties.commitIndex < nodeProperties.lastLogIndex) then
    local newCommitIndex = nodeProperties.commitIndex
    for i = (nodeProperties.commitIndex + 1), nodeProperties.lastLogIndex do
      if (nodeProperties.log[i].term == nodeProperties.term) then
        local countReplicas = 1 -- Self has this log entry
        for k,v in pairs(nodeProperties.nodeMatchIndex) do
          if (v == i) then
            countReplicas = countReplicas + 1
          end
        end
        if (countReplicas >= ((#nodeProperties.clusterNodes)//2) + 1) then
          newCommitIndex = i
        end
      end
    end
    if (newCommitIndex > nodeProperties.commitIndex) then
      nodeProperties.commitIndex = newCommitIndex
      print("New leader commitIndex", nodeProperties.commitIndex)
    end
  end
  if (nodeProperties.verbose) then
    print("[NODE " .. nodeProperties.port .. "] Leader - Updated commit index")
  end
end

function LogReplication.SendAppendEntry(nodeProperties)
  if (nodeProperties.verbose) then
    print("[NODE " .. nodeProperties.port .. "] Leader - Sending append entries")
  end
  for clusterNode,clusterProxy in pairs(nodeProperties.clusterNodesProxies) do
    local nodeNextLogEntryId = nodeProperties.nodeNextIndex[clusterNode]
    local prevLogIndex = nodeNextLogEntryId - 1
    local prevLogTerm = ""
    if prevLogIndex >= 0 then prevLogTerm = nodeProperties.log[prevLogIndex].term end
    -- New entry
    if (nodeProperties.lastLogIndex >= nodeNextLogEntryId) then
      local value = nodeProperties.term .. ";" .. prevLogIndex .. ";" .. prevLogTerm .. ";" .. nodeProperties.commitIndex .. ";" .. nodeProperties.log[nodeNextLogEntryId].term .. ";" .. nodeProperties.log[nodeNextLogEntryId].value .. ";" 
      print("=== AppendEntry NEW to", clusterNode, "===")
      print(value)
      utils.BuildAndSendMessage(nodeProperties.heartbeat, nodeProperties.port, clusterNode, "AppendEntries", value, clusterProxy)
    -- Empty entry
    else
      if (nodeProperties.verbose) then
        print("[NODE " .. nodeProperties.port .. "] Send empty heartbeat to", clusterNode)
      end
      local value = nodeProperties.term .. ";" .. prevLogIndex .. ";" .. prevLogTerm .. ";" .. nodeProperties.commitIndex .. ";;;"
      utils.BuildAndSendMessage(nodeProperties.heartbeat, nodeProperties.port, clusterNode, "AppendEntries", value, clusterProxy)
    end
  end
  if (nodeProperties.verbose) then
    print("[NODE " .. nodeProperties.port .. "] Leader - Sent append entries")
  end
end

--[[
  Add the received entry to the log
  Params:
    nodeProperties: the state of the caller node
    entryTerm: term of the new entry
    entryValue: value of the new entry
  Returns:
    The Index of the new entry in the log
]]--
function LogReplication.AddEntryToLog(nodeProperties, entryTerm, entryValue)
  nodeProperties.lastLogIndex = nodeProperties.lastLogIndex + 1
  nodeProperties.log[nodeProperties.lastLogIndex] = {
    term = entryTerm,
    value = entryValue
  }
  return nodeProperties.lastLogIndex
end

function LogReplication.AcceptAppend(nodeProperties, timeout, appendNode, appendTerm, isEmpty, proxy)
  value = appendTerm .. ";" .. tostring(isEmpty) .. ";".. tostring(true)
  utils.BuildAndSendMessage(timeout, nodeProperties.port, appendNode, "AppendEntriesResp", value, proxy)
end

function LogReplication.RejectAppend(nodeProperties, timeout, appendNode, appendTerm, isEmpty, proxy)
  value = appendTerm .. ";" .. tostring(isEmpty) .. ";".. tostring(false)
  utils.BuildAndSendMessage(timeout, nodeProperties.port, appendNode, "AppendEntriesResp", value, proxy)
end


--[[
  A2 | Implements second rule of the AppendEntries message.
  Accept leader and update self.
  Params:
    nodeProperties: the state of the caller node
    appendTerm: the term of the sender node
    appendNode: the id of the sender node
]]--
function LogReplication.AcceptLeader(nodeProperties, appendTerm, appendNode)
  nodeProperties.term = appendTerm
  nodeProperties.nextElection = utils.getElectionTime(nodeProperties)
  nodeProperties.leaderId = appendNode
  nodeProperties.state = nodeStates.Follower
end

--[[
  A3 | Implements third rule of the AppendEntries message.
  Check if message is an empty heartbeat
  Params:
    entryTerm: the term of the entry
    entryValue: the value of the entry
  Returns: 
    true: if append message is empty
    false: if not
]]--
function LogReplication.AppendIsEmpty(entryTerm, entryValue)
  return utils.isEmpty(entryTerm) or utils.isEmpty(entryValue)
end

--[[
  A4 | Implements fourth rule of the AppendEntries message.
  Check if the logs previous item match.
  The check is made only on the term and index as explained in the Log Matching Property.
  Params:
    nodeProperties: the state of the caller node
    previousLogIndex: the id of the entry preceding the new one
    previousLogTerm: the term of the entry preceding the new one
  Returns:
    true: if the logs are consistent
    false: if not
]]--
function LogReplication.LogsAreConsistent(nodeProperties, previousLogIndex, previousLogTerm)
  return previousLogIndex < 0 or previousLogTerm == nodeProperties.log[previousLogIndex].term
end

--[[
  A5 | Implements fifth rule of the AppendEntries message.
  Check if there is a different entry on the current position.
  Remove the entry and all following entries if the entry does not match the entry received on append.
  Params:
    nodeProperties: the state of the caller node
    previousLogIndex: the id of the entry preceding the new one
    previousLogTerm: the term of the entry preceding the new one
    entryTerm: the new entry term
]]--
function LogReplication.ClearDirtyEntries(nodeProperties, previousLogIndex, previousLogTerm, entryTerm)
  if (nodeProperties.log[previousLogIndex + 1] ~= nil and nodeProperties.log[previousLogIndex + 1].term ~= entryTerm) then
    for i=(previousLogIndex+1), nodeProperties.lastLogIndex do
      nodeProperties.log[i] = nil
    end
    nodeProperties.lastLogIndex = previousLogIndex
  end
end

--[[
  A6 | Implements sixth rule of the AppendEntries message.
  Update the follower commit index if possible.
  Update to the highest value between last follower item and leader last commited entry
  Params:
    nodeProperties: the state of the caller node
    leaderCommitIndex: the id of the leader commited entry
]]--
function LogReplication.FollowerUpdateCommitIndex(nodeProperties, leaderCommitIndex)
  if (leaderCommitIndex ~= nil and leaderCommitIndex > nodeProperties.commitIndex) then
    nodeProperties.commitIndex = math.min(nodeProperties.lastLogIndex, leaderCommitIndex)
    print("New follower commitIndex", nodeProperties.commitIndex)
  end
end

--[[
  AR1 | Implements first rule of the AppendEntriesResp message.
  Check if should ignore reply.
  If the reply is from an stale append or if the node is no longer leader.
  Params:
    nodeProperties: the state of the caller node
    appendTerm: the id of the leader commited entry
]]--
function LogReplication.RefuseStaleAppendResp(nodeProperties, appendTerm)
  return nodeProperties.term > appendTerm or nodeProperties.state ~= nodeStates.Leader
end

--[[
  AR2 | Implements second rule of the AppendEntriesResp message.
  Check if should update self.
  reply is from a node with bigger term should update term and convert to follower until new election or another leader is established.
  Params:
    nodeProperties: the state of the caller node
    appendTerm: the id of the leader commited entry
]]--
function LogReplication.AcceptBiggerFollowerTerm(nodeProperties, appendTerm)
  if (nodeProperties.term < appendTerm) then
    nodeProperties.term = appendTerm
    nodeProperties.State = nodeStates.Follower
    return true
  end
  return false
end

--[[
  AR3 | Implements third rule of the AppendEntriesResp message.
  Check if message was an empty heartbeat
  Params:
    wasEmpty: the indicator if the AppendEntries was empty
  Returns: 
    true: if append message is empty
    false: if not
]]--
function LogReplication.AppendRespIsEmpty(wasEmpty)
  return wasEmpty == "true"
end

--[[
  AR4 | Implements fourth rule of the AppendEntriesResp message.
  Update node next entry index after failed append attempt.
  This is used only on fails over log inconsistency.
  Params:
    nodeProperties: the state of the caller node
    followerNode: id of the resp sender node
]]--
function LogReplication.UpdateNodeFailedAppend(nodeProperties, followerNode)
  nodeProperties.nodeNextIndex[followerNode] = nodeProperties.nodeNextIndex[followerNode] -1
end

--[[
  AR5 | Implements fifth rule of the AppendEntries message.
  Update node next entry and match entry after succesfull append attempt.
  Params:
    nodeProperties: the state of the caller node
    followerNode: id of the resp sender node
]]--
function LogReplication.UpdateNodeSuccessfullAppend(nodeProperties, followerNode, wasEmpty)
  if (wasEmpty == "false") then
    nodeProperties.nodeMatchIndex[followerNode] = nodeProperties.nodeNextIndex[followerNode] 
    nodeProperties.nodeNextIndex[followerNode] = nodeProperties.nodeNextIndex[followerNode] + 1
  else
    nodeProperties.nodeMatchIndex[followerNode] = nodeProperties.nodeNextIndex[followerNode] - 1
  end
end

return LogReplication