package.path = "../?.lua;" .. package.path
local utils = require("utils")
local generalRules = require("generalRules")
local nodeStates = require("nodeStates")

local LeaderElection = {} 


function LeaderElection.StartElection(nodeProperties)
  if (nodeProperties.state == nodeStates.Leader or nodeProperties.heartbeat < nodeProperties.nextElection) then return end
  print("[NODE " .. nodeProperties.port .. "] Candidate or Follower - Starting Vote")
  nodeProperties.votedFor = nodeProperties.port
  nodeProperties.voteCount = 1
  nodeProperties.term = nodeProperties.term + 1
  nodeProperties.state = nodeStates.Candidate
  nodeProperties.nextElection = utils.getElectionTime(nodeProperties)
  local lastLogTerm = 0
  if (nodeProperties.log[nodeProperties.lastLogIndex] ~= nil) then
    lastLogTerm = nodeProperties.log[nodeProperties.lastLogIndex].term
  end
  for clusterNode,clusterProxy in pairs(nodeProperties.clusterNodesProxies) do
    local value = nodeProperties.term .. ";" .. nodeProperties.lastLogIndex .. ";" .. lastLogTerm
    utils.BuildAndSendMessage(nodeProperties.heartbeat, nodeProperties.port, clusterNode, "RequestVote", value, clusterProxy)
  end
  print("[NODE " .. nodeProperties.port .. "] Candidate or Follower - Started Vote")
end

function LeaderElection.EstablishLeadership(nodeProperties)
  print("[NODE " .. nodeProperties.port .. "] Establishing leadership")
  nodeProperties.term = nodeProperties.term + 1
  nodeProperties.state = nodeStates.Leader
  nodeProperties.leaderId = nodeProperties.port 
  for clusterNode,clusterProxy in pairs(nodeProperties.clusterNodesProxies) do
    nodeProperties.nodeNextIndex[clusterNode] = nodeProperties.lastLogIndex + 1
    nodeProperties.nodeMatchIndex[clusterNode] = -1
  end
  generalRules.SendAllEmptyHeartbeat(nodeProperties)
  print("[NODE " .. nodeProperties.port .. "] Established leadership")
end


--[[
  R2 | Implements second rule of the RequestVote message.
  Accepts all elections with future terms and grant vote to candidate. 
  This rule is derived from rules for all servers that state that calls with higher terms should update the called node.
  Params:
    nodeProperties: the state of the caller node
    candidateTerm: the term of the candidate node
  Returns:
    true: if has accepted the election
    false: if not
]]--
function LeaderElection.AcceptBiggerTermElection(nodeProperties, candidateTerm, candidateNode)
  if (candidateTerm > nodeProperties.term) then
    nodeProperties.nextElection = utils.getElectionTime(nodeProperties)
    nodeProperties.term = candidateTerm
    nodeProperties.state = nodeStates.Follower
    nodeProperties.votedFor = candidateNode
    return true
  end
  return false
end

--[[
  R3 | Implements third rule of the RequestVote message.
  Check if can grant vote to candidate.
  Params:
    nodeProperties: the state of the caller node
    candidateNode: id of the candidate node
  Returns:
    true: if can grant vote
    false: if not
]]--
function LeaderElection.CanGrantVote(nodeProperties, candidateNode)
  return nodeProperties.votedFor == nil or nodeProperties.votedFor == candidateNode
end

--[[
  R4 | Implements fourth rule of the RequestVote message.
  Check if can grant vote to candidate. Can only grant vote if candidate log is at least as up-to-date as voter.
  Up-to-date is defined by: 
    1. LastLogIndex entry term is the same and candidate log is bigger or same size as voter.
    2. LastLogIndex entry term is different and the candidate term is bigger
  Params:
    nodeProperties: the state of the caller node
    candidateNode: id of the candidate node
  Returns:
    true: if candidate log is at least as up to date as voter
    false: if not
]]--
function LeaderElection.LogIsUpToDate(nodeProperties, candidateLastLogIndex, candidateLastLogTerm)
  local isUpToDate = false
  if (nodeProperties.log[nodeProperties.lastLogIndex].term == candidateLastLogTerm
  and nodeProperties.lastLogIndex <= candidateLastLogIndex) then
    isUpToDate = true
  elseif (nodeProperties.log[nodeProperties.lastLogIndex].term ~= candidateLastLogTerm
      and nodeProperties.log[nodeProperties.lastLogIndex].term <= candidateLastLogTerm) then
    isUpToDate = true
  end
  return isUpToDate
end

function LeaderElection.AcceptVote(nodeProperties)
  nodeProperties.voteCount = nodeProperties.voteCount + 1
end

function LeaderElection.GrantVote(nodeProperties, timeout, candidateNode, electionTerm, proxy)
  nodeProperties.nextElection = utils.getElectionTime(nodeProperties)
  nodeProperties.votedFor = candidateNode
  local value = electionTerm .. ";" .. tostring(true)
  utils.BuildAndSendMessage(timeout, nodeProperties.port, candidateNode, "RequestVoteResp", value, proxy)
end

function LeaderElection.RejectVote(nodeProperties, timeout, candidateNode, electionTerm, proxy)
  local value = electionTerm .. ";" .. tostring(false)
  utils.BuildAndSendMessage(timeout, nodeProperties.port, candidateNode, "RequestVoteResp", value, proxy)
end

--[[
  R4 | Implements fourth rule of the RequestVote message.
  Check if can grant vote to candidate. Can only grant vote if candidate log is at least as up-to-date as voter.
  Up-to-date is defined by: 
    1. LastLogIndex entry term is the same and candidate log is bigger or same size as voter.
    2. LastLogIndex entry term is different and the candidate term is bigger
  Params:
    nodeProperties: the state of the caller node
    candidateNode: id of the candidate node
  Returns:
    true: if candidate log is at least as up to date as voter
    false: if not
]]--
function LeaderElection.LogIsUpToDate(nodeProperties, candidateLastLogIndex, candidateLastLogTerm)
  local isUpToDate = false
  if (nodeProperties.log[nodeProperties.lastLogIndex].term == candidateLastLogTerm
  and nodeProperties.lastLogIndex <= candidateLastLogIndex) then
    isUpToDate = true
  elseif (nodeProperties.log[nodeProperties.lastLogIndex].term ~= candidateLastLogTerm
      and nodeProperties.log[nodeProperties.lastLogIndex].term <= candidateLastLogTerm) then
    isUpToDate = true
  end
  return isUpToDate
end

--[[
  R4 | Implements fourth rule of the RequestVote message.
  Check if can grant vote to candidate. Can only grant vote if candidate log is at least as up-to-date as voter.
  Up-to-date is defined by: 
    1. LastLogIndex entry term is the same and candidate log is bigger or same size as voter.
    2. LastLogIndex entry term is different and the candidate term is bigger
  Params:
    nodeProperties: the state of the caller node
    candidateNode: id of the candidate node
  Returns:
    true: if candidate log is at least as up to date as voter
    false: if not
]]--
function LeaderElection.LogIsUpToDate(nodeProperties, candidateLastLogIndex, candidateLastLogTerm)
  local isUpToDate = false
  if (nodeProperties.log[nodeProperties.lastLogIndex].term == candidateLastLogTerm
  and nodeProperties.lastLogIndex <= candidateLastLogIndex) then
    isUpToDate = true
  elseif (nodeProperties.log[nodeProperties.lastLogIndex].term ~= candidateLastLogTerm
      and nodeProperties.log[nodeProperties.lastLogIndex].term <= candidateLastLogTerm) then
    isUpToDate = true
  end
  return isUpToDate
end

--[[
  RR1 | Implements first rule of the RequestVoteResp message.
  Check if should ignore reply.
  If the reply is from an stale election or if the candidate is no longer a candidate (became leader through majority, etc).
  Params:
    nodeProperties: the state of the caller node
    voterTerm: term of the voter node
  Returns:
    true: if should refuse the vote
    false: if not
]]--
function LeaderElection.RefuseStaleVoterResp(nodeProperties, voterTerm)
  return nodeProperties.term > voterTerm or nodeProperties.state ~= nodeStates.Candidate
end

--[[
  RR2 | Implements second rule of the RequestVoteResp message.
  Check if should update self.
  If the reply is from a node with bigger term should update term and convert to follower until new election or another leader is established.
  Params:
    nodeProperties: the state of the caller node
    voterTerm: term of the voter node
  Returns:
    true: if should update self
    false: if not
]]--
function LeaderElection.AcceptBiggerVoterTerm(nodeProperties, voterTerm)
  if (nodeProperties.term < voterTerm) then
    nodeProperties.term = voterTerm
    nodeProperties.State = nodeStates.Follower
    return true
  end
  return false
end

--[[
  RR3 | Implements third rule of the RequestVoteResp message.
  Check if has reached majority of votes.
  If voteCount is at least majority of votes establish majority.
  Params:
    nodeProperties: the state of the caller node
    voterTerm: term of the voter node
  Returns:
    true: if should update self
    false: if not
]]--
function LeaderElection.HasMajority(nodeProperties)
  local majorityValue = ((#nodeProperties.clusterNodes)//2) + 1
  return majorityValue <= nodeProperties.voteCount
end

return LeaderElection