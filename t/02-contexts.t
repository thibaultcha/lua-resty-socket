# vim:set ts=4 sw=4 et fdm=marker:
use Test::Nginx::Socket::Lua;

our $HttpConfig = <<_EOC_;
    lua_package_path 'lib/?.lua;;';
_EOC_

plan tests => repeat_each() * (blocks() * 5);

run_tests();

__DATA__

=== TEST 1: luasocket in init
--- http_config eval
"$::HttpConfig
init_by_lua_block {
    local socket = require 'resty.socket'
    local sock = socket.tcp()
    print('is fallback: ', getmetatable(sock) == socket.luasocket_mt)
}"
--- config
    location /t {
        return 200;
    }
--- request
GET /t
--- response_body

--- no_error_log
[warn]
[error]
--- error_log
is fallback: true



=== TEST 2: luasocket in init_worker
--- http_config eval
"$::HttpConfig
init_worker_by_lua_block {
    local socket = require 'resty.socket'
    local sock = socket.tcp()
    print('is fallback: ', getmetatable(sock) == socket.luasocket_mt)
}"
--- config
    location /t {
        return 200;
    }
--- request
GET /t
--- response_body

--- no_error_log
[error]
--- error_log
is fallback: true
no support for cosockets in this context, falling back to LuaSocket



=== TEST 3: luasocket in set
--- http_config eval: $::HttpConfig
--- config
    location /t {
        set_by_lua_block $res {
            local socket = require 'resty.socket'
            local sock = socket.tcp()
            print('is fallback: ', getmetatable(sock) == socket.luasocket_mt)
            return 'ok'
        }
        echo $res;
    }
--- request
GET /t
--- response_body
ok
--- no_error_log
[error]
--- error_log
is fallback: true
no support for cosockets in this context, falling back to LuaSocket



=== TEST 4: cosocket in rewrite
--- http_config eval: $::HttpConfig
--- config
    location /t {
        set $res "";
        rewrite_by_lua_block {
            local socket = require 'resty.socket'
            local sock = socket.tcp()
            print('is fallback: ', getmetatable(sock) == socket.luasocket_mt)
            ngx.var.res = "ok"
        }
        echo $res;
    }
--- request
GET /t
--- response_body
ok
--- no_error_log
[error]
[warn]
--- error_log
is fallback: false



=== TEST 5: cosocket in access
--- http_config eval: $::HttpConfig
--- config
    location /t {
        access_by_lua_block {
            local socket = require 'resty.socket'
            local sock = socket.tcp()
            ngx.say('is fallback: ', getmetatable(sock) == socket.luasocket_mt)
        }
    }
--- request
GET /t
--- response_body
is fallback: false
--- no_error_log
[warn]
[error]



=== TEST 6: cosocket in content
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local socket = require 'resty.socket'
            local sock = socket.tcp()
            ngx.say('is fallback: ', getmetatable(sock) == socket.luasocket_mt)
        }
    }
--- request
GET /t
--- response_body
is fallback: false
--- no_error_log
[warn]
[error]



=== TEST 7: luasocket in header_filter
--- http_config eval: $::HttpConfig
--- config
    location /t {
        return 200;

        header_filter_by_lua_block {
            local socket = require 'resty.socket'
            local sock = socket.tcp()
            print('is fallback: ', getmetatable(sock) == socket.luasocket_mt)
        }
    }
--- request
GET /t
--- response_body

--- no_error_log
[error]
--- error_log
is fallback: true
no support for cosockets in this context, falling back to LuaSocket



=== TEST 8: luasocket in body_filter
--- http_config eval: $::HttpConfig
--- config
    location /t {
        return 200;

        body_filter_by_lua_block {
            local socket = require 'resty.socket'
            local sock = socket.tcp()
            print('is fallback: ', getmetatable(sock) == socket.luasocket_mt)
        }
    }
--- request
GET /t
--- response_body

--- no_error_log
[error]
--- error_log
is fallback: true
no support for cosockets in this context, falling back to LuaSocket



=== TEST 9: luasocket in log
--- wait: 1
--- http_config eval: $::HttpConfig
--- config
    location /t {
        return 200;

        log_by_lua_block {
            local socket = require 'resty.socket'
            local sock = socket.tcp()
            print('is fallback: ', getmetatable(sock) == socket.luasocket_mt)
        }
    }
--- request
GET /t
--- response_body

--- no_error_log
[error]
--- error_log
is fallback: true
no support for cosockets in this context, falling back to LuaSocket



=== TEST 10: cosocket in timer
--- wait: 1
--- http_config eval: $::HttpConfig
--- config
    location /t {
        return 200;

        log_by_lua_block {
            ngx.timer.at(0, function()
                local socket = require 'resty.socket'
                local sock = socket.tcp()
                print('is fallback: ', getmetatable(sock) == socket.luasocket_mt)
            end)
        }
    }
--- request
GET /t
--- response_body

--- no_error_log
[warn]
[error]
--- error_log
is fallback: false



=== TEST 11: fallback in non-supported contexts only
--- http_config eval
"$::HttpConfig
init_by_lua_block {
    local socket = require 'resty.socket'
    local sock = socket.tcp()
    print('is fallback in init: ', getmetatable(sock) == socket.luasocket_mt)
}"
--- config
    location /t {
        content_by_lua_block {
            local socket = require 'resty.socket'
            local sock = socket.tcp()
            print('is fallback in content: ', getmetatable(sock) == socket.luasocket_mt)
        }
    }
--- request
GET /t
--- response_body

--- error_log
is fallback in init: true
is fallback in content: false
--- no_error_log
[warn]
[error]



=== TEST 12: fallback in non-supported contexts only (bis)
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local socket = require 'resty.socket'
            local sock = socket.tcp()
            print('is fallback in content: ', getmetatable(sock) == socket.luasocket_mt)
        }

        header_filter_by_lua_block {
            local socket = require 'resty.socket'
            local sock = socket.tcp()
            print('is fallback in header_filter: ', getmetatable(sock) == socket.luasocket_mt)
        }
    }
--- request
GET /t
--- response_body

--- error_log
is fallback in content: false
is fallback in header_filter: true
no support for cosockets in this context, falling back to LuaSocket
--- no_error_log
[error]
