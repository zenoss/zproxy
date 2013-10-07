--##############################################################################
--
-- Copyright (C) Zenoss, Inc. 2013, all rights reserved.
--
-- This content is made available according to terms specified in
-- License.zenoss under the directory where your Zenoss product is installed.
--
--#############################################################################

function string.starts(String, Start)
    return string.sub(String, 1, string.len(Start)) == Start
end

local key = KEYS[1]

local endpoint = "frontend:"..key
local deadpoint = "dead:"..key

-- Get the servers in the pool
local server_list = redis.call("LRANGE", endpoint, 1, -1)

-- Find the index where the server resides
local index = 0
for k,v in pairs(server_list) do
    if (v == ARGV[1]) then
        index = k
        break
    end
end

if (index > 0) then
    redis.call("LREM", deadpoint, 0, index)
    if (index < table.getn(server_list)) then
        -- Fix the list of dead servers
        local dead_list = redis.call("LRANGE", deadpoint, 0, -1)
        for k,v in pairs(dead_list) do
            local i = tonumber(v)
            if (i > index) then
                redis.call("LSET", deadpoint, k-1, tostring(i-1))
            end
        end
    end
    redis.call("LREM", endpoint, 0, ARGV[1])
end

return key 
