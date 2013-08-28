--#####################################################################################################################
-- Portions of this code are Copyright (C) Zenoss, Inc. 2013, all rights reserved.
--
-- This content is made available according to terms specified in
-- License.zenoss under the directory where your Zenoss product is installed.
--
-- Portions of this code are Copyright (c) 2012 DotCloud Inc <opensource@dotcloud.com>, Sam Alba <sam.alba@gmail.com>
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
    -- If we don't have a basic auth header or a zauth token, quit now
    if not req_headers['Authorization'] and not req_headers['X-ZAuth-Token'] then
        ngx.log(ngx.INFO, "No authorization provided")
        ngx.status = ngx.HTTP_UNAUTHORIZED
	ngx.say("Authorization required")
	ngx.exit(ngx.HTTP_OK)
	return
    end

    -- If we don't have a zauth token, we need to acquire one
    -- [[ --
    if not req_headers['X-ZAuth-Token'] then
        local lres = ngx.location.capture ('/zauth/api/login', { 
	   method = ngx.HTTP_GET,
	   body = nil,
	   share_all_vars = false,
	   copy_all_vars = false
	})
        if lres.status ~= ngx.HTTP_OK then
           ngx.log(ngx.INFO, "Authentication failed")
	   ngx.status = lres.status
	   ngx.exit(ngx.HTTP_OK)
	   return
	end
    else
       ngx.log(ngx.STDERR, 'Found ZAuth')
    end

    rewrite_backend(uri, uri_prefix, backend)
