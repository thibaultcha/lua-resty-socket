# lua-resty-socket
![Module Version][badge-version-image]
[![Build Status][badge-travis-image]][badge-travis-url]

Graceful fallback of the [ngx_lua] cosocket API to LuaSocket for unusupported
contexts or plain Lua usage.

This module allows for a better compatibility between the APIs of both
cosockets and LuaSocket, and should be used **wisely** (`init` is probably the
only context where you want such fallback).

**Important note**: The use of LuaSocket inside ngx_lua is **very strongly**
discouraged due to the blocking nature of LuaSocket. However, it does come
handy at certain times when one is developing a lua-resty module and wants it
to be compatible with plain Lua or in contexts that do not support cosockets
(such as `init`).

It currently only support TCP sockets.

## Features

- Fallback on LuaSocket if running in plain Lua/LuaJIT
- Fallback on LuaSocket if the current ngx_lua context does not support
  cosockets (use wisely, ideally, customize the contexts authorized to
  fallback)
- Interoperability of said fallbacked sockets with the cosocket API

## Usage

This module can run in plain Lua and any ngx_lua context:

```lua
local socket = require "lua-resty-socket"

local sock = socket.tcp()

local is_luasocket = getmetatable(sock) == socket.luasocket_mt -- depends on surrounding context

local times, err = sock:getreusedtimes() -- 0 if the underlying socket is LuaSocket

sock:settimeout(1000) -- converted to seconds if LuaSocket

local ok, err = sock:connect(host, port)

local ok, err = sock:sslhandshake(false, nil, false) -- cosocket signature, will use LuaSec if LuaSocket

local ok, err = sock:setkeepalive() -- close() if LuaSocket
```

## Installation

This module is mainly intended to be copied in a lua-resty library and
eventually modified to one's needs (such as desired supported contexts,
eventually `init` only).

For obvious reasons, it depends on LuaSocket (should a socket be created where
cosockets are not available). If such sockets are never created, LuaSocket will
never be required. Hence why, this module does **not** declare a dependency on
LuaSocket by default.

If SSL features are used, LuaSec will be required too.

It can also be installed via LuaRocks:

```shell
$ luarocks install lua-resty-socket
```

[ngx_lua]: https://github.com/openresty/lua-nginx-module

[badge-travis-url]: https://travis-ci.org/thibaultCha/lua-resty-socket
[badge-travis-image]: https://travis-ci.org/thibaultCha/lua-resty-socket.svg?branch=master

[badge-version-image]: https://img.shields.io/badge/version-0.0.4-blue.svg?style=flat
