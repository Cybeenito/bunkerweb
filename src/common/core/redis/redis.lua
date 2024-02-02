local class = require "middleclass"
local plugin = require "bunkerweb.plugin"

local redis = class("redis", plugin)

local ngx = ngx
local NOTICE = ngx.NOTICE
local HTTP_INTERNAL_SERVER_ERROR = ngx.HTTP_INTERNAL_SERVER_ERROR
local HTTP_OK = ngx.HTTP_OK
local match = string.match

function redis:initialize(ctx)
	-- Call parent initialize
	plugin.initialize(self, "redis", ctx)
end

function redis:init_worker()
	-- Check if init_worker is needed
	if self.variables["USE_REDIS"] ~= "yes" or self.is_loading then
		return self:ret(true, "init_worker not needed")
	end
	-- Check redis connection
	local ok, err = self.clusterstore:connect(true)
	if not ok then
		return self:ret(false, "redis connect error : " .. err)
	end
	-- Send ping
	local ok, err = self.clusterstore:call("ping")
	self.clusterstore:close()
	if err then
		return self:ret(false, "error while sending ping command to redis server : " .. err)
	end
	if not ok then
		return self:ret(false, "redis ping command failed")
	end
	self.logger:log(NOTICE, "connectivity with redis server " .. self.variables["REDIS_HOST"] .. " is successful")
	return self:ret(true, "success")
end

function redis:api()
	-- Match request
	if not match(self.ctx.bw.uri, "^/redis/ping$") or self.ctx.bw.request_method ~= "POST" then
		return self:ret(false, "success")
	end
	-- Check redis connection
	local ok, err = self.clusterstore:connect(true)
	if not ok then
		return self:ret(true, "redis connect error : " .. err, HTTP_INTERNAL_SERVER_ERROR)
	end
	-- Send ping
	local ok, err = self.clusterstore:call("ping")
	self.clusterstore:close()
	if err then
		return self:ret(true, "error while sending ping command to redis server : " .. err, HTTP_INTERNAL_SERVER_ERROR)
	end
	if not ok then
		return self:ret(true, "redis ping command failed", HTTP_INTERNAL_SERVER_ERROR)
	end
	return self:ret(true, "success", HTTP_OK)
end

return redis
