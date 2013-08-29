--#####################################################################################################################
-- Portions of this code are Copyright (C) Zenoss, Inc. 2013, all rights reserved.
--
-- This content is made available according to terms specified in
-- License.zenoss under the directory where your Zenoss product is installed.
--
-- Portions of this code are Copyright (c) 2012 DotCloud Inc <opensource@dotcloud.com>, Sam Alba <sam.alba@gmail.com>
--
--#####################################################################################################################

function extract_prefix(uri)
   ngx.log(ngx.INFO, "URI: ", uri)
   --match the first 3 parts of a path. eg /api/category/resource
   local pathPrefixRE = [[(^/[^/]+/[^/]+/[^/]+)]]
   local uri_prefix  = ngx.re.match(uri, pathPrefixRE)
   if uri_prefix == nil then
      ngx.log(ngx.INFO, "No prefix")
      uri_prefix = ""
   else
      uri_prefix = uri_prefix[1]
      ngx.log(ngx.INFO, "PREFIX: ", uri_prefix)
   end
   return uri_prefix
end

function extract_frontend(http_host)
   -- Extract only the hostname without the port
   local frontend = ngx.re.match(http_host, "^([^:]*)")
   if frontend ~= nil then
      frontend = frontend[1]
   end
   ngx.var.frontend = frontend
   return frontend
end

function extract_domain(frontend)
   -- Extract the domain name without the subdomain
   local domain_regex = [[(\.[^.]+\.[^.]+)$]]
   local domain_name = ngx.re.match(frontend, domain_regex)
   if domain_name ~= nil then
      domain_name = domain_name[1]
   else
      ngx.log(ngx.INFO, "No domain name")
      domain_name = ""
   end
   return domain_name
end

function extract_backend(uri_prefix, frontend, domain_name)
   ngx.log(ngx.INFO, "uri_prefix: " .. uri_prefix .. ", frontend: " .. frontend)
   -- Connect to Redis
   local redis = require "resty.redis"
   local red = redis:new()
   red:set_timeout(1000)
   local ok, err = red:connect("127.0.0.1", 6379)
   if not ok then
      ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
      ngx.say("Failed to connect to Redis: ", err)
      -- to cause quit the whole request rather than the current phase handler
      ngx.exit(ngx.HTTP_OK)
      return nil
   end
   ngx.log(ngx.INFO, "Connected to redis...")

   -- Redis lookup
   red:multi()
   red:lrange("frontend:" .. uri_prefix, 0, -1)
   red:lrange("frontend:" .. frontend, 0, -1)
   red:lrange("frontend:*" .. domain_name, 0, -1)
   red:smembers("dead:" .. frontend)
   red:smembers("dead:" .. uri_prefix)
   local ans, err = red:exec()
   if not ans then
      ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
      ngx.say("Lookup failed: ", err)
      -- to cause quit the whole request rather than the current phase handler
      ngx.exit(ngx.HTTP_OK)
      return nil
   end

   -- Parse the result of the Redis lookup
   local backends = ans[1]
   local pathBackend = true
   if #backends == 0 then
      -- did not match URI prefix?
      -- fall back to regular hipache matches by host then domain
      pathBackend = false
      backends = ans[2]
      if #backends == 0 then
         -- domain match
         backends = ans[3]
      end
   end

   if #backends == 0 then
      ngx.status = 502
      ngx.say("Backend not found")
      -- to cause quit the whole request rather than the current phase handler
      ngx.exit(ngx.HTTP_OK)
      return nil
   end
   local vhost_name = backends[1]
   table.remove(backends, 1)
   local deads
   if pathBackend then
      deads = ans[5]
   else
      deads = ans[4]
   end

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

   ngx.var.backends_len = #backends
   ngx.var.backend_id = index - 1
   ngx.var.vhost = vhost_name

   return backend
end

function rewrite_backend(uri, uri_prefix, backend)
   if backend then
      -- found a uri prefix match, rewrite path to backend path
      -- parse backend
      -- match 1 is up to first slash after host, match 2 is the path
      local backendRE = [[(.+\://[^/]*)(/.*)]]
      local backendMatch= ngx.re.match(backend, backendRE)

      ngx.var.backend = backendMatch[1]
      if true then
         ngx.log(ngx.INFO, "new backend ",ngx.var.backend)
      end

      -- path portion of backend url
      local newPrefix = backendMatch[2]
      if true then
         ngx.log(ngx.INFO, "new prefix ", newPrefix)
      end
      -- replace incoming path prefix with new prefix (rewrite url)
      local newPath = string.gsub(uri, uri_prefix, newPrefix, 1)
      ngx.log(ngx.INFO, "new path ", newPath)
      ngx.req.set_uri(newPath)
   else
      -- not a path back end, should just be a host eg. http://www.host.com:8000
      ngx.var.backend = backend
   end
end


