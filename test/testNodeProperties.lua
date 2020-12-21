package.path = "../?.lua;" .. package.path
local nodeProperties = {
  IP = "127.0.0.1",
  port = 8000,
  clusterNodes = {},
  clusterNodesProxies = {},
  -- 
  tick = 0,
  suspendNodeFlag = false,
  receivedMessagesLine = {},
  sentMessagesLine = {},
  verbose = true
}
return nodeProperties