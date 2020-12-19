package.path = "../?.lua;" .. package.path
local utils = require("utils")
local nodeStates = require("nodeStates")
local messageTypes = 
{
  --[[ Append Request
    
    The message value is expected to contain: term;prevLogIndex;prevLogTerm;leaderCommit;entryTerm;entryValue
    A1 - Refuse appends from stale leaders, send term for node to update self.
    A2 - Update state to acknowledge leader and set new election timeout.
    A3 - Reply to empty heartbeats
    A4 - Check log consistency (implementation of Log Matching Property)
    A5 - Clear existing entries that were not commited and append new entry
    A6 - Update commit index and reply success to leader.
  ]]--
  AppendEntries = function(nodeProperties, message, generalRules, logReplicationRules, leaderElectionRules)
    if (nodeProperties.verbose) then
      print("[NODE " .. nodeProperties.port .. "] AppendEntries - enter")
    end
    local belongsToNode, callerProxy = generalRules.CheckNodeBelongsInCluster(nodeProperties, message.fromNode)
    if not belongsToNode then return end
    --
    local processed = false
    leaderTerm, previousLogIndex, previousLogTerm, leaderCommitIndex, entryTerm, entryValue  = string.match(message.value, "(.-);(.-);(.-);(.-);(.-);(.*)")
    leaderTerm = tonumber(leaderTerm)
    previousLogIndex = tonumber(previousLogIndex)
    previousLogTerm = tonumber(previousLogTerm)
    leaderCommitIndex = tonumber(leaderCommitIndex)
    entryTerm = tonumber(entryTerm)
    -- A1
    if (generalRules.RefuseStaleTerm(nodeProperties, leaderTerm)) then
      logReplicationRules.RejectAppend(nodeProperties, message.timeout, message.fromNode, nodeProperties.term, false, callerProxy)
      return
    end
    -- A2
    if (nodeProperties.verbose) then
      print("A2")
    end
    logReplicationRules.AcceptLeader(nodeProperties, leaderTerm, message.fromNode)
    logReplicationRules.FollowerUpdateCommitIndex(nodeProperties, leaderCommitIndex)
    -- A3
    if (nodeProperties.verbose) then
      print("A3")
    end
    if (logReplicationRules.AppendIsEmpty(entryTerm, entryValue)) then
      logReplicationRules.AcceptAppend(nodeProperties, message.timeout, message.fromNode, leaderTerm, true, callerProxy)
      return
    end
    -- A4
    if (nodeProperties.verbose) then
      print("A4")
    end
    if (not logReplicationRules.LogsAreConsistent(nodeProperties, previousLogIndex, previousLogTerm)) then
      logReplicationRules.RejectAppend(nodeProperties, message.timeout, message.fromNode, leaderTerm, false, callerProxy)
      return
    end
    -- A5
    if (nodeProperties.verbose) then
      print("A5")
    end
    logReplicationRules.ClearDirtyEntries(nodeProperties, previousLogIndex, previousLogTerm, entryTerm)
    logReplicationRules.AddEntryToLog(nodeProperties, entryTerm, entryValue)
    -- A6
    if (nodeProperties.verbose) then
      print("A6")
    end
    
    logReplicationRules.AcceptAppend(nodeProperties, message.timeout, message.fromNode, leaderTerm, false, callerProxy)
    if (nodeProperties.verbose) then
      print("[NODE " .. nodeProperties.port .. "] AppendEntries - left")
    end
  end,
  --[[ Append Request Reply
    
    The message value is expected to contain: term;wasEmpty;success;
    AR1 - Ignore replies from stale appends.
    AR2 - Convert self to follower if other follower has a higher term.
    AR3 - Ignore reply if was an empty heartbeat.
    AR4 - Decrement next entry to send to node after failed append attempt.
    AR5 - Increment next entry to send to node and the last matching entry after successfull attempt.
  ]]--
  AppendEntriesResp = function(nodeProperties, message, generalRules, logReplicationRules, leaderElectionRules)
    if (nodeProperties.verbose) then
      print("[NODE " .. nodeProperties.port .. "] AppendEntriesResp - enter")
    end
    local belongsToNode, callerProxy = generalRules.CheckNodeBelongsInCluster(nodeProperties, message.fromNode)
    if not belongsToNode then return end
    --
    followerTerm, wasEmpty, success  = string.match(message.value, "(.-);(.-);(.*)")
    followerTerm = tonumber(followerTerm)
    -- AR1
    if (nodeProperties.verbose) then
      print("AR1")
    end
    if (logReplicationRules.RefuseStaleAppendResp(nodeProperties, followerTerm)) then return end
    -- AR2
    if (nodeProperties.verbose) then
      print("AR2")
    end
    if (logReplicationRules.AcceptBiggerFollowerTerm(nodeProperties, followerTerm)) then return end
    -- AR3
    if (nodeProperties.verbose) then
      print("AR3")
    end
    if (logReplicationRules.AppendRespIsEmpty(wasEmpty)) then return end
    -- AR4
    if (nodeProperties.verbose) then
      print("AR4")
    end
    if (success == "false") then
      logReplicationRules.UpdateNodeFailedAppend(nodeProperties, message.fromNode)
      return
    end
    -- AR5
    if (nodeProperties.verbose) then
      print("AR5")
    end
    logReplicationRules.UpdateNodeSuccessfullAppend(nodeProperties, message.fromNode)
    if (nodeProperties.verbose) then
      print("[NODE " .. nodeProperties.port .. "] AppendEntriesResp - left")
    end
  end,
  --[[ Vote Request
    
    The message value is expected to contain: term;lastLogIndex;lastLogTerm;
    R1 - Don't grant vote for candidates with stale terms.
    R2 - Grant vote if candidate has higher term than voter.
    R3 - Vote only if has not voted yet this term or candidate is the same as already voted.
    R4 - Vote only if candidate log is at least as up-to-date as voter log.
  ]]--
  RequestVote = function(nodeProperties, message, generalRules, logReplicationRules, leaderElectionRules)     
    if (nodeProperties.verbose) then
      print("[NODE " .. nodeProperties.port .. "] RequestVote - enter")
    end
    local belongsToNode, candidateProxy = generalRules.CheckNodeBelongsInCluster(nodeProperties, message.fromNode)
    if not belongsToNode then return end
    --
    candidateTerm, candidateLastLogIndex, candidateLastLogTerm = string.match(message.value, "(.-);(.-);(.*)")
    candidateTerm = tonumber(candidateTerm)
    candidateLastLogIndex = tonumber(candidateLastLogIndex)
    candidateLastLogTerm = tonumber(candidateLastLogTerm)
    local resp = nil
    -- R1
    if (generalRules.RefuseStaleTerm(nodeProperties, candidateTerm)) then 
      leaderElectionRules.RejectVote(nodeProperties, message.timeout, message.fromNode, nodeProperties.term, candidateProxy)
      return
    end
    -- R2
    if (leaderElectionRules.AcceptBiggerTermElection(nodeProperties, candidateTerm, message.fromNode)) then
      leaderElectionRules.GrantVote(nodeProperties, message.timeout, message.fromNode, candidateTerm, candidateProxy)
      return
    end
    -- R3 & R4
    if (leaderElectionRules.CanGrantVote(nodeProperties, message.fromNode)
    and leaderElectionRules.LogIsUpToDate(nodeProperties, candidateLastLogIndex, candidateLastLogTerm)) then
      leaderElectionRules.GrantVote(nodeProperties, message.timeout, message.fromNode, candidateTerm, candidateProxy)
    else
      leaderElectionRules.RejectVote(nodeProperties, message.timeout, message.fromNode, candidateTerm, candidateProxy)
    end
    if (nodeProperties.verbose) then
      print("[NODE " .. nodeProperties.port .. "] RequestVote - left")
    end
  end,
  --[[ Vote Request Reply
    The message value is expected to contain: term;vote;
    RR1 - Ignore replies from stale elections
    RR2 - Convert self to follower if voter has a higher term
    RR3 - Check if has majority of votes and should establish leadership
  ]]--
  RequestVoteResp = function(nodeProperties, message, generalRules, logReplicationRules, leaderElectionRules)
    if (nodeProperties.verbose) then
      print("[NODE " .. nodeProperties.port .. "] RequestVoteResp - enter")
    end
    local belongsToNode, _ = generalRules.CheckNodeBelongsInCluster(nodeProperties, message.fromNode)
    if not belongsToNode then return end
    --
    term, vote = string.match(message.value, "(.-);(.*)")
    term = tonumber(term)
    -- RR1
    if (leaderElectionRules.RefuseStaleVoterResp(nodeProperties, term)) then return end
    -- RR2
    if (leaderElectionRules.AcceptBiggerVoterTerm(nodeProperties, term)) then
      print("Became follower")
      return 
    end
    if (vote == "true") then
      leaderElectionRules.AcceptVote(nodeProperties)
      print("Received vote from ", message.fromNode)
      -- RR3
      if (leaderElectionRules.HasMajority(nodeProperties)) then
        leaderElectionRules.EstablishLeadership(nodeProperties)
      end
    end
    if (nodeProperties.verbose) then
      print("[NODE " .. nodeProperties.port .. "] RequestVoteResp - left")
    end
  end
}

return messageTypes