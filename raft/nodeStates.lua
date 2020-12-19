package.path = "../?.lua;" .. package.path
local nodeStates = 
{
  Follower = 1,
  Candidate = 2,
  Leader = 3
}

return nodeStates