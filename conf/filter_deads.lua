--[[----------------------------------------------------------------------------
-- Portions of this code are Copyright (C) Zenoss, Inc. 2013, 
-- all rights reserved.
--
-- This content is made available according to terms specified in
-- License.zenoss under the directory where your Zenoss product is installed.
--
-- Portions of this code are Copyright (c) 2012:
--   DotCloud Inc <opensource@dotcloud.com>, 
--   Sam Alba <sam.alba@gmail.com>
--]]----------------------------------------------------------------------------

local code = ngx.status
-- Mark the backend as dead only for 5xx errors
if not (ngx.status >= 501 and ngx.status ~= 503) then
   return
end
local frontend = ngx.var.frontend

if #frontend == 0 then
   return
end
-- Put the dead backends in a shared dict (we cannot call Redis from here)
local deads = ngx.shared.deads
local line = frontend .. ";" .. ngx.var.backend .. ";" ..
   ngx.var.backend_id .. ";" .. ngx.var.backends_len
deads:set(ngx.var.frontend .. ngx.var.backend_id, line)
