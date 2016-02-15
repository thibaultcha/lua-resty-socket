# vim:set ts=4 sw=4 et fdm=marker:
use Test::Nginx::Socket::Lua;
use t::Utils;

repeat_each(3);

plan tests => repeat_each() * blocks() * 4;

run_tests();

__DATA__

=== TEST 1: luasocket getreusedtimes()
--- http_config eval
"$t::Utils::HttpConfig"
--- config
    location /t {
        return 200;

        log_by_lua_block {
            local socket = require "resty.socket"
            local sock = socket.tcp()
            local reused_times = sock:getreusedtimes()
            print("reused: "..reused_times)
        }
    }
--- request
GET /t
--- response_body

--- no_error_log
[error]
--- error_log
reused: 0



=== TEST 2: luasocket settimeout() compat (ms to seconds conversion)
--- http_config eval
"$t::Utils::HttpConfig"
--- config
    location /get {
        content_by_lua_block {
            ngx.sleep(2)
        }
    }

    location /t {
        return 200;

        log_by_lua_block {
            local socket = require "resty.socket"
            local sock = socket.tcp()
            sock:settimeout(1000) -- should be translated to 1 for LuaSocket
            local ok, err = sock:connect("127.0.0.1", $TEST_NGINX_SERVER_PORT)
            if not ok then
                ngx.log(ngx.ERR, "could not connect: "..err)
            end

            local ok, err = sock:send "GET /get HTTP/1.1\r\nHost: localhost\r\n\r\n"
            if not ok then
                ngx.log(ngx.ERR, "could not send: "..err)
            end

            local res, err = sock:receive "*l"
            if not res then
                print("could not receive: "..err)
            end
        }
    }
--- request
GET /t
--- response_body

--- no_error_log
[error]
--- error_log
could not receive: timeout



=== TEST 3: luasocket setkeepalive() compat (close)
--- http_config eval
"$t::Utils::HttpConfig"
--- config
    location /t {
        return 200;

        log_by_lua_block {
            local socket = require "resty.socket"
            local sock = socket.tcp()
            local ok, err = sock:connect("google.com", 80)
            if not ok then
                ngx.log(ngx.ERR, "could not connect: "..err)
            end

            local ok, err = sock:send "GET /get HTTP/1.1\r\nHost: localhost\r\n\r\n"
            if not ok then
                ngx.log(ngx.ERR, "could not send: "..err)
            end

            local res, err = sock:receive "*l"
            if not res then
                ngx.log(ngx.ERR, "could not receive: "..err)
            end

            local ok, err = sock:setkeepalive()
            if not ok then
                ngx.log(ngx.ERR, "setkeepalive() proxy should return true")
            end

            local ok, err = sock:send "GET /get HTTP/1.1\r\nHost: localhost\r\n\r\n"
            if not ok then
                print("could not send after close: "..err)
            end
        }
    }
--- request
GET /t
--- response_body

--- no_error_log
[error]
--- error_log
could not send after close: closed
