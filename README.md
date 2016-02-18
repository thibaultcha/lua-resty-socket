# lua-resty-socket ![Module Version][badge-version-image] [![Build Status][badge-travis-image]][badge-travis-url]

A module to reconcile [ngx_lua]'s cosockets and LuaSocket.

**Important note**: The use of LuaSocket inside ngx_lua is **strongly** discouraged due to the blocking nature of LuaSocket's `receive`. However, it does come handy at certain times when one is developing a lua-resty module and wants it to run in contexts that do not support cosockets (such as `init`). This module allows for a better compatibility between the APIs of both implementations, and should be used wisely.

It currently only support TCP sockets.

## Features

- Fallback on LuaSocket if running in plain Lua/LuaJIT
- Fallback on LuaSocket if the current ngx_lua context does not support cosockets
- Interoperability of said fallbacked sockets with the cosocket API

## Usage

This module can run in any ngx_lua context and in plain Lua:

```lua
local socket = require "lua-resty-socket"

local sock = socket.tcp()

local is_luasocket = getmetatable(sock) == socket.luasocket_mt -- depends on surrounding context

local times, err = sock:getreusedtimes() -- 0 if underlying socket is LuaSocket
-- ...

sock:settimeout(1000) -- converted to seconds if LuaSocket

local ok, err = sock:connect(host, port)
-- ...

local ok, err = sock:sslhandshake(false, nil, false) -- cosocket signature, will use LuaSec if LuaSocket
-- ...

local ok, err = sock:setkeepalive() -- close() if LuaSocket
-- ...
```

## Installation

This module is mainly intended to be copied and tweaked in a lua-resty library if its author is mad enough.

It can also be installed via LuaRocks:

```shell
$ luarocks install lua-resty-socket
```

[ngx_lua]: https://github.com/openresty/lua-nginx-module

[badge-travis-url]: https://travis-ci.org/thibaultCha/lua-resty-socket
[badge-travis-image]: https://travis-ci.org/thibaultCha/lua-resty-socket.svg?branch=master

[badge-version-image]: https://img.shields.io/badge/version-0.0.1-blue.svg?style=flat
