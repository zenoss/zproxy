    -- Extract the URI
    local uri = ngx.var.uri
    ngx.log(ngx.STDERR, "URI: ", uri)
    --match the first 2 parts of a path
    local pathPrefixRE = [[(^/[^/]+/[^/]+)]]
    local uri_prefix  = ngx.re.match(uri, pathPrefixRE)
    if uri_prefix == nill then
       ngx.log(ngx.STDERR, "No prefix")
       uri_prefix = ""
    else
        ngx.log(ngx.STDERR, "PREFIX[0]: ", uri_prefix[0])
        ngx.log(ngx.STDERR, "PREFIX[1]: ", uri_prefix[1])
	    uri_prefix = uri_prefix[1]
        ngx.log(ngx.STDERR, "PREFIX: ", uri_prefix)
    end

    -- Connect to Redis
    local redis = require "resty.redis"
    local red = redis:new()
    red:set_timeout(1000)
    local ok, err = red:connect("127.0.0.1", 6379)
    if not ok then
        ngx.say("Failed to connect to Redis: ", err)
        return
    end

    -- Extract only the hostname without the port
    local frontend = ngx.re.match(ngx.var.http_host, "^([^:]*)")
    if frontend ~= nill then
       ngx.log(ngx.STDERR, "FRONTEND 0: ", frontend[0])
       ngx.log(ngx.STDERR, "FRONTEND 1: ", frontend[1])
       frontend = frontend[1]
    end

    -- Extract the domain name without the subdomain
    local domain_regex = [[(\.[^.]+\.[^.]+)$]]
    local domain_name = ngx.re.match(frontend, domain_regex)
    if domain_name ~= nill then
       ngx.log(ngx.STDERR, "domain_name 0: ", domain_name[0])
       ngx.log(ngx.STDERR, "domain_name 1: ", domain_name[1])
       domain_name = domain_name[1]
    else
       ngx.log(ngx.STDERR, "No domain name")
       domain_name = ""
    end
    -- Redis lookup
    red:multi()
    red:lrange("frontend:" .. uri_prefix, 0, -1)
    red:lrange("frontend:" .. frontend, 0, -1)
    red:lrange("frontend:*" .. domain_name, 0, -1)
    red:smembers("dead:" .. frontend)
    red:smembers("dead:" .. uri_prefix)
    local ans, err = red:exec()
    if not ans then
        ngx.say("Lookup failed: ", err)
        return
    end

    -- Parse the result of the Redis lookup
    local backends = ans[1]
    local pathBackend = true
    if #backends == 0 then
        pathBackend = false
    	backends = ans[2]
	    if #backends == 0 then
	        backends = ans[3]
	    end
    end

    if #backends == 0 then
        ngx.say("Backend not found")
        return
    end
    local vhost_name = backends[1]
    table.remove(backends, 1)
    local deads
    if pathBackend then
        deads = ans[5]
    else
        deads = ans[4]
    end
    for i, v in ipairs(deads) do
        --print(i, v)
        ngx.log(ngx.STDERR, "-------deads", i, ":", v)
    end

    -- Pickup a random backend (after removing the dead ones)
    local indexes = {}
    for i, v in ipairs(deads) do
        deads[v] = true
    end
    for k, v in pairs(deads) do
        --print(i, v)
        ngx.log(ngx.STDERR, "-------deads after ", k, ":", v)
    end

    for i, v in ipairs(backends) do
        ngx.log(ngx.STDERR, "-------checking deads", i, ":", v)
        if deads[v] == nil then
            table.insert(indexes, i)
        end
    end
    local index = indexes[math.random(1, #indexes)]
    local backend = backends[index]

    -- Announce dead backends if there is any
    local deads = ngx.shared.deads
    for i, v in ipairs(deads:get_keys()) do
        ngx.log(ngx.STDERR, "--------PUB DEADS-------------- ", i)
        ngx.log(ngx.STDERR, "--------PUB DEADS-------------- ", v)
        ngx.log(ngx.STDERR, "--------PUB DEADS-------------- ", deads:get(v))
        red:publish("dead", deads:get(v))
        deads:delete(v)
    end

    -- Set the connection pool (to avoid connect/close everytime)
    red:set_keepalive(0, 100)

    -- Export variables
    ngx.log(ngx.STDERR, "path backends ", pathBackend)
    ngx.log(ngx.STDERR, "backend ", backend)

    if not backend then
        ngx.say("Backend not available")
        return
    end

    if pathBackend == true then
        -- parse backend
	    local backendRE = [[(.+\://[^/]*)(/.*)]]
	    local backendMatch= ngx.re.match(backend, backendRE)
        if true then
            ngx.log(ngx.STDERR, "blam ",backendMatch[1])
            ngx.log(ngx.STDERR, "blam ",backendMatch[2])
        end

	    ngx.var.backend = backendMatch[1]
        if true then
            ngx.log(ngx.STDERR, "new backend ",ngx.var.backend)
        end

	    local newPrefix = backendMatch[2]
        if true then
            ngx.log(ngx.STDERR, "new prefix ", newPrefix)
        end

	    local newPath = string.gsub(uri, uri_prefix, newPrefix, 1)
        ngx.log(ngx.STDERR, "new path ", newPath)
        ngx.req.set_uri(newPath)
    else
        ngx.var.backend = backend
    end
    ngx.var.backends_len = #backends
    ngx.var.backend_id = index - 1
    ngx.var.frontend = frontend
    ngx.var.vhost = vhost_name
