function string.starts(String, Start)
    return string.sub(String, 1, string.len(Start)) == Start
end


-- Compute the key, based on whether the server is http or websocket
local key = ""
if string.starts(ARGV[1], "ws") then
    key = "/ws/"..KEYS[1]
else
    key = "/api/"..KEYS[1]
end

local endpoint = "frontend:"..key

-- Check if the key exists on the server
local server_list = redis.call("LRANGE", endpoint, 0, -1)

if (table.getn(server_list) > 1) then

    for k,v in pairs(server_list) do
        if (v == ARGV[1]) then
            return key
        end
    end
else
    redis.call("RPUSH", endpoint, KEYS[1])
end

redis.call("RPUSH", endpoint, ARGV[1])

return key
