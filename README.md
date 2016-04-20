# lua-resty-socket

![Module Version][badge-version-image]
[![Build Status][badge-travis-image]][badge-travis-url]

cosocket/LuaSocket compatibility module.

### Table of Contents

* [Motivation](#motivation)
* [Important note](#important-note)
* [Usage](#usage)
* [Requirements](#requirements)
* [Installation](#installation)
* [License](#license)

### Motivation

The aim of this module is to provide an automatic fallback to LuaSocket when
[ngx_lua]'s cosockets are not available. That is:
- When not used in ngx_lua
- In ngx_lua contexts where cosockets are not supported (`init`, `init_worker`,
etc...)

When falling back to LuaSocket, it provides you with shims for cosocket-only
functions such as `getreusedtimes`, `setkeepalive` etc...

It comes handy when one is developing a module/library that aims at being
either compatible with both ngx_lua **and** plain Lua, **or** in ngx_lua
contexts such as `init`.

[Back to TOC](#table-of-contents)

### Important note

The use of LuaSocket inside ngx_lua is **very strongly** discouraged due to its
blocking nature. However, it is fine to use it in the `init` context where
blocking is not considered harmful.

In the future, only the `init` phase will allow falling back to LuaSocket.

It currently only support TCP sockets.

[Back to TOC](#table-of-contents)

## Usage

All of the available functions follow the same prototype as the cosocket API,
allowing this example to run in any ngx_lua context or outside ngx_lua
altogether:
```lua
local socket = require 'resty.socket'
local sock = socket.tcp()

getmetatable(sock) == socket.luasocket_mt ---> true/false depending on underlying socket

sock:settimeout(1000) ---> 1000ms translated to 1s if LuaSocket

sock:getreusedtimes(...) ---> 0 if LuaSocket

sock:setkeepalive(...) ---> calls close() if LuaSocket

sock:sslhandshake(...) ---> LuaSec dependency if LuaSocket
```

As such, one can write a module relying on TCP sockets such as:
```lua
local socket = require 'resty.socket'

local _M = {}

function _M.new()
  local sock = socket.tcp() -- similar to ngx.socket.tcp()

  return setmetatable({
    sock = sock
  }, {__index = _M})
end

function _M:connect(host, port)
  local ok, err = self.sock:connect(host, port)
  if not ok then
    return nil, err
  end

  local times, err = self.sock:getreusedtimes() -- cosocket API
  if not times then
    return nil, err
  elseif times == 0 then
    -- handle connection
  end
end

return _M
```

The user of such a module could use it in contexts with cosocket support, or
in the `init` phase of ngx_lua, with little effort from the developer.

[Back to TOC](#table-of-contents)

### Requirements

**As long as sockets are created in contexts with support for cosockets, this
module will never require LuaSocket nor LuaSec.**

- LuaSocket (only if sockets are created where cosockets don't exist)
- LuaSec (only if the fallbacked socket attempts to perform an SSL handshake)

[Back to TOC](#table-of-contents)

### Installation

This module can either be copied in a lua-resty library, allowing one to
modify the list of contexts allowing fallback.

It can also be installed via LuaRocks:

```shell
$ luarocks install lua-resty-socket
```

[Back to TOC](#table-of-contents)

### License

Work licensed under the MIT License.

[Back to TOC](#table-of-contents)

[ngx_lua]: https://github.com/openresty/lua-nginx-module

[badge-travis-url]: https://travis-ci.org/thibaultCha/lua-resty-socket
[badge-travis-image]: https://travis-ci.org/thibaultCha/lua-resty-socket.svg?branch=master

[badge-version-image]: https://img.shields.io/badge/version-0.0.6-blue.svg?style=flat
