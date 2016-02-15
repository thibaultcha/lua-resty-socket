local get_phase, ngx_socket, has_cosocket, log

--- ngx_lua utils

if ngx ~= nil then
  get_phase = ngx.get_phase
  ngx_socket = ngx.socket
  log = ngx.log
  has_cosocket = function()
    local phase = get_phase()
    return phase == "rewrite" or phase == "access"
        or phase == "content" or phase == "timer"
  end
else
  log = function()end
  get_phase = function()end
  has_cosocket = function()end
end

--- LuaSocket proxy metatable

local luasocket_mt = {}

function luasocket_mt:__index(key)
  local override = rawget(luasocket_mt, key)
  if override ~= nil then
    return override
  end

  local orig = self.sock[key]
  if type(orig) == "function" then
    local f = function(_, ...)
      return orig(self.sock, ...)
    end
    self[key] = f
    return f
  end

  return orig
end


--- LuaSocket/ngx_lua compat

function luasocket_mt.getreusedtimes()
  return 0
end

function luasocket_mt:settimeout(t)
  self.sock:settimeout(t/1000)
end

function luasocket_mt:setkeepalive()
  self.sock:close()
  return true
end

--- Module

return {
  tcp = function(...)
    if has_cosocket() then
      return ngx_socket.tcp(...)
    else
      log(ngx.WARN, "no support for cosockets in this context, falling back on LuaSocket")

      local socket = require "socket"

      return setmetatable({
        sock = socket.tcp(...)
      }, luasocket_mt)
    end
  end,
  luasocket_mt = luasocket_mt,
  _VERSION = "0.0.1"
}
