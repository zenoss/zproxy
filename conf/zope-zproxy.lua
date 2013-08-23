--#####################################################################################################################
-- Portions of this code are Copyright (C) Zenoss, Inc. 2013, all rights reserved.
--
-- This content is made available according to terms specified in
-- License.zenoss under the directory where your Zenoss product is installed.
--
-- Portions of this code are Copyright (c) 2012 DotCloud Inc <opensource@dotcloud.com>, Sam Alba <sam.alba@gmail.com>
--
--#####################################################################################################################
    -- Connect to Redis

    local uri = ngx.var.uri
    ngx.log(ngx.DEBUG, "LUA Request ", uri)


    local redis = require "resty.redis"
    local red = redis:new()
    red:set_timeout(1000)
    local ok, err = red:connect("127.0.0.1", 6379)
    if not ok then
        ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
        ngx.say("Failed to connect to Redis: ", err)
        -- to cause quit the whole request rather than the current phase handler
        ngx.exit(ngx.HTTP_OK)
        return
    end

    -- Redis lookup
    local frontend = "zope"
    red:multi()
    red:lrange("frontend:zope", 0, -1)
    red:smembers("dead:zope")
    local ans, err = red:exec()
    if not ans then
        ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
        ngx.say("Lookup failed: ", err)
        -- to cause quit the whole request rather than the current phase handler
        ngx.exit(ngx.HTTP_OK)
        return
    end

    -- Parse the result of the Redis lookup
    local backends = ans[1]
    if #backends == 0 then
        -- 502 is BAD GATEWAY
        ngx.status = 502
        ngx.say("Backend not found for "..uri)
        -- to cause quit the whole request rather than the current phase handler
        ngx.exit(ngx.HTTP_OK)
        return
    end
    table.remove(backends, 1)
    local deads = ans[2]

    -- Pickup a random backend (after removing the dead ones)
    local indexes = {}
    for i, v in ipairs(deads) do
        deads[v] = true
    end

    for i, v in ipairs(backends) do
        if deads[v] == nil then
            table.insert(indexes, i)
        end
    end
    local index = indexes[math.random(1, #indexes)]
    local backend = backends[index]

    -- Announce dead backends if there is any
    local deads = ngx.shared.deads
    for i, v in ipairs(deads:get_keys()) do
        red:publish("dead", deads:get(v))
        deads:delete(v)
    end

    -- Set the connection pool (to avoid connect/close everytime)
    red:set_keepalive(0, 100)

    -- Export variables

    if not backend then
        ngx.status = ngx.HTTP_SERVICE_UNAVAILABLE
        ngx.say("Backend not available")
        -- to cause quit the whole request rather than the current phase handler
        ngx.exit(ngx.HTTP_OK)
        return
    end

    ngx.log(ngx.DEBUG, "LUA backend: ", backend)


    ngx.var.backend = backend
    ngx.var.backends_len = #backends
    ngx.var.backend_id = index - 1
    ngx.var.frontend = frontend
    ngx.var.vhost = vhost_name
