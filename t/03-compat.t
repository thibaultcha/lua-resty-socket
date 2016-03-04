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
--- wait: 2
--- http_config eval
"$t::Utils::HttpConfig"
--- config
    location /get {
        content_by_lua_block {
            ngx.sleep(2)
            ngx.say "ok"
        }
    }

    location /t {
        return 200;

        log_by_lua_block {
            local socket = require "resty.socket"
            local sock = socket.tcp()
            sock:settimeout(1000) -- should be translated to 1 for LuaSocket
            local ok, err = sock:connect("localhost", $TEST_NGINX_SERVER_PORT)
            if not ok then
                ngx.log(ngx.ERR, "could not connect: "..err)
                return
            end

            local bytes, err = sock:send "GET /get HTTP/1.1\r\nHost: localhost\r\n\r\n"
            if not bytes then
                ngx.log(ngx.ERR, "could not send: "..err)
                return
            end

            ngx.timer.at(1, function()
                local res, err = sock:receive "*l"
                if not res then
                    print("could not receive: "..err)
                end
            end)
        }
    }
--- request
GET /t
--- response_body

--- no_error_log
[error]
--- error_log
could not receive: timeout



=== TEST 3: luasocket settimeout() nil
--- wait: 1
--- http_config eval
"$t::Utils::HttpConfig"
--- config
    location /t {
        return 200;

        log_by_lua_block {
            local socket = require "resty.socket"
            local sock = socket.tcp()
            sock:settimeout() -- no errors
            ngx.log(ngx.INFO, "ok")
        }
    }
--- request
GET /t
--- response_body

--- no_error_log
[error]
--- error_log
ok



=== TEST 4: luasocket setkeepalive() compat (close)
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
            if not ok then
                ngx.log(ngx.ERR, "could not connect: "..err)
                return
            end

            local bytes, err = sock:send "GET / HTTP/1.1\r\nHost: localhost\r\n\r\n"
            if not bytes then
                ngx.log(ngx.ERR, "could not send: "..err)
                return
            end

            local res, err = sock:receive "*l"
            if not res then
                ngx.log(ngx.ERR, "could not receive: "..err)
                return
            end

            local ok, err = sock:setkeepalive()
            if not ok then
                ngx.log(ngx.ERR, "setkeepalive() proxy should return true")
                return
            end

            local ok, err = sock:send "HEAD / HTTP/1.1\r\nHost: localhost\r\n\r\n"
            if not ok then
                print("could not send after keepalive: "..err)
            end
        }
    }
--- request
GET /t
--- response_body

--- no_error_log
[error]
--- error_log
could not send after keepalive: closed



=== TEST 5: luasocket sslhandshake() compat
--- http_config eval
"$t::Utils::HttpConfig"
--- config
    location /t {
        return 200;

        log_by_lua_block {
            local socket = require "resty.socket"
            local sock = socket.tcp()
            local ok, err = sock:connect("google.com", 443)
            if not ok then
                ngx.log(ngx.ERR, "could not connect: "..err)
                return
            end

            local session, err = sock:sslhandshake(nil, nil, false)
            if err then
                ngx.log(ngx.ERR, "could not handshake: "..err)
                return
            end

            local bytes, err = sock:send "HEAD / HTTP/1.1\r\nHost: localhost\r\n\r\n"
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
HTTP/1.1 404 Not Found
