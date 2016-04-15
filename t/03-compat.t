# vim:set ts=4 sw=4 et fdm=marker:
use Test::Nginx::Socket::Lua;

our $HttpConfig = <<_EOC_;
    lua_package_path 'lib/?.lua;;';
_EOC_

plan tests => repeat_each() * blocks() * 3 - 2;

$ENV{TEST_NGINX_RESOLVER} ||= '8.8.8.8';

run_tests();

__DATA__

=== TEST 1: luasocket getreusedtimes()
--- http_config eval: $::HttpConfig
--- config
    location /t {
        return 200;

        log_by_lua_block {
            local socket = require 'resty.socket'
            local sock = socket.tcp()
            local reused_times = sock:getreusedtimes()
            print("reused: ", reused_times)
        }
    }
--- request
GET /t
--- no_error_log
[error]
--- error_log
reused: 0



=== TEST 2: luasocket settimeout() compat (ms to seconds conversion)
--- SKIP
--- wait: 3
--- http_config eval: $::HttpConfig
--- config
    location /get {
        content_by_lua_block {
            print('sleeping...')
            ngx.sleep(2)
            ngx.say('ok')
        }
    }

    location /t {
        return 200;

        log_by_lua_block {
            local socket = require 'resty.socket'
            local sock = socket.tcp()
            sock:settimeout(1000) -- should be translated to 1 for LuaSocket
            local ok, err = sock:connect('localhost', $TEST_NGINX_SERVER_PORT)
            if not ok then
                ngx.log(ngx.ERR, 'could not connect: ', err)
                return
            end

            local bytes, err = sock:send('GET /get HTTP/1.1\r\nHost: localhost\r\n\r\n')
            if not bytes then
                ngx.log(ngx.ERR, 'could not send: ', err)
                return
            end

            ngx.timer.at(0, function()
                print('receiving...')
                local res, err = sock:receive()
                if not res then
                    print('could not receive: ', err)
                end
            end)
        }
    }
--- request
GET /t
--- no_error_log
[error]
--- error_log
could not receive: timeout



=== TEST 3: luasocket settimeout() nil
--- wait: 1
--- http_config eval: $::HttpConfig
--- config
    location /t {
        return 200;

        log_by_lua_block {
            local socket = require 'resty.socket'
            local sock = socket.tcp()
            sock:settimeout() -- no errors
            ngx.log(ngx.INFO, 'ok')
        }
    }
--- request
GET /t
--- no_error_log
[error]
--- error_log
ok



=== TEST 4: luasocket setkeepalive() compat (close)
--- wait: 1
--- http_config eval: $::HttpConfig
--- config
    resolver $TEST_NGINX_RESOLVER ipv6=off;
    location /t {
        return 200;

        log_by_lua_block {
            local socket = require 'resty.socket'
            local sock = socket.tcp()
            local ok, err = sock:connect('www.google.com', 80)
            if not ok then
                ngx.log(ngx.ERR, 'could not connect: ', err)
                return
            end

            local bytes, err = sock:send('HEAD / HTTP/1.1\r\nHost: www.google.com\r\nConnection: close\r\n\r\n')
            if not bytes then
                ngx.log(ngx.ERR, 'could not send: ', err)
                return
            end

            local status, err = sock:receive()
            if not status then
                ngx.log(ngx.ERR, 'could not receive: ', err)
                return
            end

            local ok, err = sock:setkeepalive()
            if not ok then
                ngx.log(ngx.ERR, 'setkeepalive() proxy should return true')
                return
            end

            local ok, err = sock:send('HEAD / HTTP/1.1\r\nHost: www.google.com\r\nConnection: close\r\n\r\n')
            if not ok then
                print('could not send after keepalive: ', err)
            end
        }
    }
--- request
GET /t
--- no_error_log
[error]
--- error_log
could not send after keepalive: closed



=== TEST 5: luasocket sslhandshake() compat
--- http_config eval: $::HttpConfig
--- config
    resolver $TEST_NGINX_RESOLVER ipv6=off;
    location /t {
        return 200;

        log_by_lua_block {
            local socket = require 'resty.socket'
            local sock = socket.tcp()
            local ok, err = sock:connect('www.google.com', 443)
            if not ok then
                ngx.log(ngx.ERR, 'could not connect: ', err)
                return
            end

            local session, err = sock:sslhandshake(nil, nil, false)
            if not session then
                ngx.log(ngx.ERR, 'could not handshake: ', err)
                return
            end

            print('session: ', type(session))

            local bytes, err = sock:send('HEAD / HTTP/1.1\r\nHost: www.google.com\r\nConnection: close\r\n\r\n')
            if not bytes then
                ngx.log(ngx.ERR, 'could not send: ', err)
                return
            end

            local status, err = sock:receive()
            if not status then
                ngx.log(ngx.ERR, 'could not receive: ', err)
                return
            end

            print(status)
        }
    }
--- request
GET /t
--- no_error_log
[error]
--- error_log_eval
[
    qr/\[notice\] .*? session: table/,
    qr/\[notice\] .?* HTTP/1.1 200 OK/
]



=== TEST 6: luasocket sslhandshake() compat arg #1 false
--- http_config eval: $::HttpConfig
--- config
    resolver $TEST_NGINX_RESOLVER ipv6=off;
    location /t {
        return 200;

        log_by_lua_block {
            local socket = require 'resty.socket'
            local sock = socket.tcp()
            local ok, err = sock:connect('www.google.com', 443)
            if not ok then
                ngx.log(ngx.ERR, 'could not connect: ', err)
                return
            end

            local session, err = sock:sslhandshake(false, nil, false)
            if not session then
                ngx.log(ngx.ERR, 'could not handshake: ', err)
                return
            end

            print('session: ', type(session))
        }
    }
--- request
GET /t
--- no_error_log
[error]
--- error_log_eval
qr/\[notice\] .*? session: boolean/
