# vim:set ts=4 sw=4 et fdm=marker:
use Test::Nginx::Socket::Lua;

our $HttpConfig = <<_EOC_;
    lua_package_path 'lib/?.lua;;';
_EOC_

plan tests => repeat_each() * (blocks() * 3 + 1);

$ENV{TEST_NGINX_RESOLVER} ||= '8.8.8.8';

run_tests();

__DATA__

=== TEST 1: _VERSION field
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local socket = require 'resty.socket'
            ngx.say(socket._VERSION)
        }
    }
--- request
GET /t
--- response_body_like
[0-9]\.[0-9]\.[0-9]
--- no_error_log
[error]



=== TEST 2: expose proxy metatable
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local socket = require 'resty.socket'
            ngx.say(type(socket.luasocket_mt))
        }
    }
--- request
GET /t
--- response_body
table
--- no_error_log
[error]



=== TEST 3: warn message on fallback
--- http_config eval: $::HttpConfig
--- config
    location /t {
        return 200;

        log_by_lua_block {
            local socket = require 'resty.socket'
            socket.tcp()
        }
    }
--- request
GET /t
--- response_body

--- error_log eval
qr/\[warn\].*?no support for cosockets in this context, falling back on LuaSocket/



=== TEST 4: cosocket sanity
--- http_config eval: $::HttpConfig
--- config
    location /post {
        return 201;
    }

    location /t {
        content_by_lua_block {
            local socket = require 'resty.socket'
            local sock = socket.tcp()

            local ok, err = sock:connect('127.0.0.1', $TEST_NGINX_SERVER_PORT)
            if ok ~= 1 then
                ngx.log(ngx.ERR, 'could not connect: ', err)
                return
            end

            local bytes, err = sock:send('POST /post HTTP/1.1\r\nHost: localhost\r\n\r\n')
            if not bytes then
                ngx.log(ngx.ERR, 'could not send: ', err)
                return
            end

            local status, err = sock:receive()
            if not status then
                ngx.log(ngx.ERR, 'could not receive: ', err)
                return
            end

            ngx.say(status)
        }
    }
--- request
GET /t
--- response_body
HTTP/1.1 201 Created
--- no_error_log
[error]



=== TEST 5: luasocket fallback sanity
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
            if ok ~= 1 then
                ngx.log(ngx.ERR, 'could not connect: ', err)
                return
            end

            local bytes, err = sock:send('HEAD / HTTP/1.1\r\nHost: www.google.com\r\nConnection: close\r\n\r\n')
            if not bytes then
                ngx.log(ngx.ERR, 'could not send: ', err)
                return
            end

            local res, err = sock:receive()
            if not res then
                ngx.log(ngx.ERR, 'could not receive: ', err)
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
