--[[----------------------------------------------------------------------------
-- 
-- Copyright (C) Zenoss, Inc. 2013, all rights reserved.
--
-- This content is made available according to terms specified in
-- License.zenoss under the directory where your Zenoss product is installed.
--
--]]----------------------------------------------------------------------------

local common = loadfile("conf/zproxy-common.lua")
common()
local uri = ngx.var.uri
local uri_prefix = extract_prefix(uri)
local frontend = extract_frontend(ngx.var.http_host)
local domain_name = extract_domain(frontend)
local backend = extract_backend(uri_prefix, frontend, domain_name)
local req_headers = ngx.req.get_headers()
local auth_token = extract_auth_token(req_headers)

-- If we don't have a basic auth header or a zauth token, quit now
if not req_headers['Authorization'] and not auth_token then
   return exit_unauth()
end

cjson = require "cjson"
-- Proxy token will be passed through as header to the proxied request
local proxy_token
if auth_token then
   -- Zapps do their own validation, so just pass through the auth token
   proxy_token = auth_token
   ngx.var.subrequest_time = 0
else
   -- The original request did not have a discernable auth token, so login
   local subrequest_url = '/zauth/api/login'
   ngx.log(ngx.DEBUG, 'Subrequest URL: ' .. subrequest_url)
   -- Make a subrequest to login
   local substart = ngx.now()
   local lres = ngx.location.capture (subrequest_url, { 
                                         method = ngx.HTTP_GET,
                                         body = nil,
                                         share_all_vars = false,
                                         copy_all_vars = false
   })
   ngx.var.subrequest_time = ngx.now() - substart
   -- If we got anything other than OK, bail out here.
   if lres.status ~= ngx.HTTP_OK then
      return exit_authfailed(lres.status)
   end
   ngx.log(ngx.DEBUG, "Body: " .. lres.body)
   -- Decode the subrequest
   token = cjson.decode(lres.body)
   -- Add a ZAuth cookie to the response for future calls
   ngx.header['Set-Cookie'] = build_cookie(token)
   -- The passed through auth token will be the one we just got from login
   proxy_token = token['id']
end
-- Set the ZAuth token in the proxy request
ngx.req.set_header('X-ZAuth-Token', proxy_token)
rewrite_backend(uri, uri_prefix, backend)
