# vim:set ts=4 sw=4 et fdm=marker:
use Test::Nginx::Socket::Lua;

our $HttpConfig = <<_EOC_;
    lua_package_path 'lib/?.lua;;';
_EOC_

plan tests => repeat_each() * blocks() * 2;

$ENV{TEST_NGINX_RESOLVER} ||= '8.8.8.8';

run_tests();

__DATA__

=== TEST 1: purge memoized closures
--- http_config eval: $::HttpConfig
--- config
    resolver $TEST_NGINX_RESOLVER ipv6=off;
    location /t {
        return 200;

        log_by_lua_block {
            local socket = require 'resty.socket'
            local sock = socket.tcp()

            local ok, err = sock:connect('www.google.com', 443)
            if ok ~= 1 then
                ngx.log(ngx.ERR, 'could not connect: ', err)
                return
            end

            -- create closures
            sock.send = function() return nil, 'closure' end
            sock.receive = function() return nil, 'closure' end

            local ok, err = sock:sslhandshake(false)
            if not ok then
                ngx.log(ngx.ERR, 'could not handshake: ', err)
                return
            end

            local bytes, err = sock:send 'HEAD / HTTP/1.1\r\nHost: www.google.com\r\nConnection: close\r\n\r\n'
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
qr/\[notice\] .*? HTTP/1.1 200 OK/
