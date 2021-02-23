local type = type

----------------------------
-- LuaSocket proxy metatable
----------------------------

local proxy_mt

do
  local tostring = tostring
  local concat = table.concat
  local pairs = pairs

  local function flatten(v, buf)
    if type(v) == 'string' then
      buf[#buf+1] = v
    elseif type(v) == 'number' then
      buf[#buf+1] = tostring(v)
    elseif type(v) == 'table' then
      for i = 1, #v do
        flatten(v[i], buf)
      end
    end
  end

  proxy_mt = {
    connect = function(self, ...)
      local ok, err = self.sock:connect(...)
      
      if self._connected_before and err == "closed" then
        -- luasocket does not allow reusing sockets after being closed
        local socket = require 'socket'
        self.sock = socket.tcp()
        ok, err = self.sock:connect(...)
      end
      
      self._connected_before = true
      return ok, err
    end,
    send = function(self, data)
      if type(data) == 'table' then
        local buffer = {}
        flatten(data, buffer)
        data = concat(buffer)
      end

      return self.sock:send(data)
    end,
    getreusedtimes = function() return 0 end,
    settimeout = function(self, t)
      if t then
        t = t/1000
      end
      self.sock:settimeout(t)
    end,
    setkeepalive = function(self)
      self.sock:close()
      return true
    end,
    close = function(self)
      -- LuaSec dismisses the return value from sock:close(), so we override
      -- sock:close() here to ensure that we always return non-nil from it,
      -- even when wrapped by LuaSec
      self.sock:close()
      return 1
    end,
    sslhandshake = function(self, reused_session, _, verify, send_status_req, opts)
      if opts == nil and type(send_status_req) == "table" then
        -- backward compat after OR added send_status_req, shift args
        opts, send_status_req = send_status_req, nil       -- luacheck: ignore
      end
      opts = opts or {}
      local return_bool = reused_session == false

      local ssl = require 'ssl'
      local params = {
        mode = 'client',
        protocol = 'any',
        key = opts.key,
        certificate = opts.cert,
        cafile = opts.cafile,
        verify = verify and 'peer' or 'none',
        -- can the following be dynamically generated from `lua_ssl_protocols`?
        options = {"all", "no_sslv2", "no_sslv3", "no_tlsv1"}
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
  }

  proxy_mt.__tostring = function(self)
    return tostring(self.sock)
  end

  proxy_mt.__index = function(self, key)
    local override = proxy_mt[key]
    if override then
      return override
    end

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
  end
end

---------
-- Module
---------

local _M = {
  luasocket_mt = proxy_mt,
  _VERSION = '1.0.0'
}

-----------------------
-- ngx_lua/plain compat
-----------------------

local COSOCKET_PHASES = {
  rewrite = true,
  access = true,
  content = true,
  timer = true,
  ssl_cert = true,
  ssl_session_fetch = true
}

local forced_luasocket_phases = {}
local forbidden_luasocket_phases = {}

do
  local setmetatable = setmetatable

  if ngx then
    local log, WARN, INFO = ngx.log, ngx.WARN, ngx.INFO
    local get_phase = ngx.get_phase
    local ngx_socket = ngx.socket

    function _M.tcp(...)
      local phase = get_phase()
      if not forced_luasocket_phases[phase]
         and COSOCKET_PHASES[phase]
         or forbidden_luasocket_phases[phase] then
        return ngx_socket.tcp(...)
      end

      -- LuaSocket
      if phase ~= 'init' then
        if forced_luasocket_phases[phase] then
          log(INFO, 'support for cosocket in this context, but LuaSocket forced')
        else
          log(WARN, 'no support for cosockets in this context, falling back to LuaSocket')
        end
      end

      local socket = require 'socket'

      return setmetatable({
        sock = socket.tcp(...)
      }, proxy_mt)
    end
  else
    local socket = require 'socket'

    function _M.tcp(...)
      return setmetatable({
        sock = socket.tcp(...)
      }, proxy_mt)
    end
  end
end

---------------------------------------
-- Disabling/forcing LuaSocket fallback
---------------------------------------

do
  local function check_phase(phase)
    if type(phase) ~= 'string' then
      local info = debug.getinfo(2)
      local err = string.format("bad argument #1 to '%s' (%s expected, got %s)",
                                info.name, 'string', type(phase))
      error(err, 3)
    end
  end

  function _M.force_luasocket(phase, force)
    check_phase(phase)
    forced_luasocket_phases[phase] = force
  end

  function _M.disable_luasocket(phase, disable)
    check_phase(phase)
    forbidden_luasocket_phases[phase] = disable
  end
end

return _M
