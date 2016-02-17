# vim:set ts=4 sw=4 et fdm=marker:
use Test::Nginx::Socket::Lua;
use t::Utils;

repeat_each(1);

plan tests => repeat_each() * (blocks() * 3 + 1);

run_tests();

__DATA__

=== TEST 1: _VERSION field
--- http_config eval
"$t::Utils::HttpConfig"
--- config
    location /t {
        content_by_lua_block {
            local socket = require "resty.socket"
            ngx.say(socket._VERSION)
        }
    }
--- request
GET /t
--- response_body
0.0.1
--- no_error_log
[error]



=== TEST 2: expose proxy metatable
--- http_config eval
"$t::Utils::HttpConfig"
--- config
    location /t {
        content_by_lua_block {
            local socket = require "resty.socket"
            if socket.luasocket_mt == nil then
                ngx.exit(500)
            end
        }
    }
--- request
GET /t
--- response_body

--- no_error_log
[error]



=== TEST 3: warn message on fallback
--- http_config eval
"$t::Utils::HttpConfig"
--- config
    location /t {
        return 200;

        log_by_lua_block {
            local socket = require "resty.socket"
            socket.tcp()
        }
    }
--- request
GET /t
--- response_body

--- error_log eval
qr/\[warn\].*?no support for cosockets in this context, falling back on LuaSocket/



=== TEST 4: cosocket behavior
--- http_config eval
"$t::Utils::HttpConfig"
--- config
    location /get {
        content_by_lua_block {
            ngx.status = 201
        }
    }

    location /t {
        content_by_lua_block {
            local socket = require "resty.socket"
            local sock = socket.tcp()

            local ok, err = sock:connect("127.0.0.1", $TEST_NGINX_SERVER_PORT)
            if ok ~= 1 then
                ngx.log(ngx.ERR, "could not connect: "..err)
                ngx.exit(500)
            end

            local bytes, err = sock:send "GET /get HTTP/1.1\r\nHost: localhost\r\n\r\n"
            if not bytes then
                ngx.log(ngx.ERR, "could not send: "..err)
            end

            local res, err = sock:receive "*l"
            if not res then
                ngx.log(ngx.ERR, "could not receive: "..err)
            end

            ngx.say(res)
        }
    }
--- request
GET /t
--- response_body
HTTP/1.1 201 Created
--- no_error_log
[error]



=== TEST 5: luasocket fallback behavior
--- wait: 1
--- http_config eval
"$t::Utils::HttpConfig"
--- config
    location /t {
        return 200;

        log_by_lua_block {
            local socket = require "resty.socket"
            local sock = socket.tcp()

            local ok, err = sock:connect("google.com", 80)
            if ok ~= 1 then
                ngx.log(ngx.ERR, "could not connect: "..err)
                return
            end

            local bytes, err = sock:send "GET / HTTP/1.1\r\n\r\n"
            if not bytes then
                ngx.log(ngx.ERR, "could not send: "..err)
                return
            end

            local res, err = sock:receive "*l"
            if not res then
                ngx.log(ngx.ERR, "could not receive: "..err)
                return
            end

            print(res)
        }
    }
--- request
GET /t
--- response_body

--- no_error_log
[error]
--- error_log
HTTP/1.1 200 OK
