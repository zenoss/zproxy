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

rewrite_backend(uri, uri_prefix, backend)
