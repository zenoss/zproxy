--#####################################################################################################################
-- Copyright (C) Zenoss, Inc. 2013, all rights reserved.
--
-- This content is made available according to terms specified in
-- License.zenoss under the directory where your Zenoss product is installed.
--
--#####################################################################################################################

local common = loadfile("conf/zproxy-common.lua")
common()
local uri = ngx.var.uri
local uri_prefix = extract_prefix(uri)
local frontend = extract_frontend(ngx.var.http_host)
local domain_name = extract_domain(frontend)
local backend = extract_backend(uri_prefix, frontend, domain_name)

local req_headers = ngx.req.get_headers()

local auth_token = req_headers['X-ZAuth-Token']
if not auth_token then
   ngx.log(ngx.DEBUG, 'X-ZAuth-Token header was nil; checking ZAuthToken cookie')
   auth_token = ngx.var['cookie_ZAuthToken']
   if auth_token then
      -- If we got an auth token from a cookie, let's set an X-ZAuth-Token header
      ngx.req.set_header('X-ZAuth-Token', auth_token)
   end
   ngx.log(ngx.DEBUG, 'ZAuthToken cookie was ' .. (auth_token or 'nil'))
else
   ngx.log(ngx.DEBUG, 'Found X-ZAuth-Token header')
end

-- If we don't have a basic auth header or a zauth token, quit now
if not req_headers['Authorization'] and not auth_token then
   ngx.log(ngx.INFO, "No authorization provided")
   ngx.status = ngx.HTTP_UNAUTHORIZED
   ngx.say("Authorization required")
   ngx.exit(ngx.HTTP_OK)
   return
end

cjson = require "cjson"
-- If we don't have a zauth token, we need to acquire one

local subrequest_url
if auth_token then
   subrequest_url = '/zauth/api/validate'
else
   subrequest_url = '/zauth/api/login'
end
ngx.log(ngx.DEBUG, 'Subrequest URL: ' .. subrequest_url)
local lres = ngx.location.capture (subrequest_url, { 
   method = ngx.HTTP_GET,
   body = nil,
   share_all_vars = false,
   copy_all_vars = false
})
if lres.status ~= ngx.HTTP_OK then
   ngx.log(ngx.INFO, "Authentication failed")
   ngx.say("Authentication failed")
   ngx.status = lres.status
   ngx.exit(ngx.HTTP_OK)
   return
end
ngx.log(ngx.DEBUG, "Body: " .. lres.body)
-- Decode the subrequest
token = cjson.decode(lres.body)
-- Add a ZAuth cookie to the response for future calls
if not auth_token then
   ngx.header['Set-Cookie'] = {'ZAuthToken=' .. token['id'] .. '; path=/; Expires=' .. ngx.cookie_time(token['expires'])}
end
-- Set the ZAuth token in the proxy request
ngx.req.set_header('X-ZAuth-Token', token['id'])
rewrite_backend(uri, uri_prefix, backend)
