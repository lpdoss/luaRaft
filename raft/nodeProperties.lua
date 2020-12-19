package.path = "../?.lua;" .. package.path
local nodeProperties = {
  IP = "127.0.0.1",
  port = 8000,
  verbose = false,
  clusterNodes = {},
  clusterNodesProxies = {},
  -- 
  receivedMessagesLine = {},
  sentMessagesLine = {},
  
  -- Raft properties
  state = 0,
  term = 0,
  heartbeat = 0,
  nextElection = 0,
  heartbeatTimeout = 2,
  electionTimeoutMin = 6,
  electionTimeoutMax = 20,
  votedFor = nil,
  log = {},
  lastLogIndex = -1,
  commitIndex = -1,
  leaderId = nil,
  -- Leader properties
  nodeNextIndex = {},
  nodeMatchIndex = {},
}
return nodeProperties
