local pairs = pairs
local type = type

----------------------------
-- LuaSocket proxy metatable
----------------------------

local luasocket_mt = {}

function luasocket_mt:__index(key)
  local orig = self.sock[key]
  if type(orig) == 'function' then
    local f = function(_, ...)
      return orig(self.sock, ...)
    end
    self[key] = f
    return f
  elseif orig then
    return orig
  end

  return luasocket_mt[key]
end

function luasocket_mt.getreusedtimes()
  return 0
end

function luasocket_mt:settimeout(t)
  if t then
    t = t/1000
  end

  self.sock:settimeout(t)
end

function luasocket_mt:setkeepalive()
  self.sock:close()

  return true
end

-- Mimics the ngx_lua `sslhandshake()` signature with
-- an additional argument to specify other SSL options
-- for LuaSec.
function luasocket_mt:sslhandshake(reused_session, _, verify, opts)
  opts = opts or {}
  local return_bool = reused_session == false

  local ssl = require 'ssl'
  local params = {
    mode = 'client',
    protocol = 'tlsv1',
    key = opts.key,
    certificate = opts.cert,
    cafile = opts.cafile,
    verify = verify and 'peer' or 'none',
    options = 'all'
  }

  local sock, err = ssl.wrap(self.sock, params)
  if not sock then
    return return_bool and false or nil, err
  end

  local ok, err = sock:dohandshake()
  if not ok then
    return return_bool and false or nil, err
  end

  -- purge memoized closures
  for k, v in pairs(self) do
    if type(v) == 'function' then
      self[k] = nil
    end
  end

  self.sock = sock

  return return_bool and true or self
end

-----------------------
-- ngx_lua/plain compat
-----------------------

local new_tcp

do
  local setmetatable = setmetatable

  if ngx then
    local log, WARN = ngx.log, ngx.WARN
    local get_phase = ngx.get_phase
    local ngx_socket = ngx.socket

    local cosocket_phases = {
      rewrite = true,
      access = true,
      content = true,
      timer = true
    }

    new_tcp = function(...)
      local phase = get_phase()
      if cosocket_phases[phase] then
        return ngx_socket.tcp(...)
      elseif phase ~= 'init' then
        log(WARN, 'no support for cosockets in this context, falling back on LuaSocket')
      end

      local socket = require 'socket'

      return setmetatable({
        sock = socket.tcp(...)
      }, luasocket_mt)
    end
  else
    local socket = require 'socket'

    new_tcp = function(...)
      return setmetatable({
        sock = socket.tcp(...)
      }, luasocket_mt)
    end
  end
end

---------
-- Module
---------

return {
  tcp = new_tcp,
  luasocket_mt = luasocket_mt,
  _VERSION = '0.0.4'
}
