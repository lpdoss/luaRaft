package.path = "../?.lua;" .. package.path
local utils = require("utils")
local luarpc = require("luarpc")
local nodeStates = require("nodeStates")

local GeneralRules = {}

--[[
  G1 | Implements first rule for All Servers
  Rejects all messages with stale terms and send back current term for the sender node to update.
  Params:
    nodeProperties: the state of the caller node
    term: the term of the sender node
  Returns:
    true: if has refused
    false: if not
]]--
function GeneralRules.RefuseStaleTerm(nodeProperties, term)
  return term < nodeProperties.term
end

function GeneralRules.CheckNodeBelongsInCluster(nodeProperties, callingNode)
  local proxy = nodeProperties.clusterNodesProxies[callingNode]
  if proxy == nil then
    print("There is no proxy for node " .. callingNode)
    return false
  end
  return true, proxy
end

function GeneralRules.InitializeNodeState(nodeProperties, arq_interface)
  if (nodeProperties.verbose) then
    print("[NODE " .. nodeProperties.port .. "] Initializing node ")
  end
  nodeProperties.keepAlive = true
  nodeProperties.state = nodeStates.Follower
  nodeProperties.heartbeat = 0
  nodeProperties.nextElection = utils.getElectionTime(nodeProperties)
  nodeProperties.clusterNodesProxies = {}
  nodeProperties.receivedMessagesLine = {}
  nodeProperties.sentMessagesLine = {}
  -- create proxies to other nodes
  for _,node in ipairs(nodeProperties.clusterNodes) do
    nodeProperties.clusterNodesProxies[node] = luarpc.createProxy(nodeProperties.IP, node, arq_interface, nodeProperties.verbose)
  end
  if (nodeProperties.verbose) then
    print("[NODE " .. nodeProperties.port .. "] Initialized node ")
  end
end

function GeneralRules.TickNodeClock(nodeProperties)
  nodeProperties.heartbeat = nodeProperties.heartbeat + 1
end

function GeneralRules.SendAllEmptyHeartbeat(nodeProperties)
  if (nodeProperties.verbose) then
    print("[NODE " .. nodeProperties.port .. "] Sending empty heartbeats")
  end
  local prevLogIndex = nodeProperties.lastLogIndex - 1
  local prevLogTerm = ""
  if prevLogIndex >= 0 then prevLogTerm = nodeProperties.log[prevLogIndex].term end
  local value = nodeProperties.term .. ";" .. prevLogIndex .. ";" .. prevLogTerm .. ";" .. nodeProperties.commitIndex .. ";;;"
  for clusterNode,clusterProxy in pairs(nodeProperties.clusterNodesProxies) do
    utils.BuildAndSendMessage(nodeProperties.heartbeat, nodeProperties.port, clusterNode, "AppendEntries", value, clusterProxy)
  end
  if (nodeProperties.verbose) then
    print("[NODE " .. nodeProperties.port .. "] Sent empty heartbeats")
  end
end

function GeneralRules.SendEmptyHeartbeat(nodeProperties, clusterNode, clusterProxy)
  if (nodeProperties.verbose) then
    print("[NODE " .. nodeProperties.port .. "] Sending empty heartbeat to", clusterNode)
  end
  local prevLogIndex = nodeProperties.lastLogIndex - 1
  local prevLogTerm = ""
  if prevLogIndex >= 0 then prevLogTerm = nodeProperties.log[prevLogIndex].term end
  local value = nodeProperties.term .. ";" .. prevLogIndex .. ";" .. prevLogTerm .. ";" .. nodeProperties.commitIndex .. ";;;"
  utils.BuildAndSendMessage(nodeProperties.heartbeat, nodeProperties.port, clusterNode, "AppendEntries", value, clusterProxy)
  if (nodeProperties.verbose) then
    print("[NODE " .. nodeProperties.port .. "] Sent empty heartbeat to", clusterNode)
  end
end

return GeneralRules
