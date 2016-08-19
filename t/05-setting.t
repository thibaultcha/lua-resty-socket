
# vim:set ts=4 sw=4 et fdm=marker:
use Test::Nginx::Socket::Lua;

our $HttpConfig = <<_EOC_;
    lua_package_path 'lib/?.lua;;';
_EOC_

plan tests => repeat_each() * (blocks() * 5);

$ENV{TEST_NGINX_RESOLVER} ||= '8.8.8.8';

run_tests();

__DATA__

=== TEST 1: force_luasocket()
--- http_config eval: $::HttpConfig
--- config
    location /t {
        return 200;

        log_by_lua_block {
            ngx.timer.at(0, function()
                local socket = require 'resty.socket'
                socket.force_luasocket('timer', true)

                local sock = socket.tcp()
                print('is fallback: ', getmetatable(sock) == socket.luasocket_mt)
            end)
        }
    }
--- request
GET /t
--- response_body

--- no_error_log
[error]
--- error_log
support for cosocket in this context, but LuaSocket forced
is fallback: true



=== TEST 2: disable_luasocket()
--- http_config eval: $::HttpConfig
--- config
    location /t {
        return 200;

        log_by_lua_block {
            local socket = require 'resty.socket'
            socket.disable_luasocket('log', true)

            socket.tcp()
        }
    }
--- request
GET /t
--- response_body

--- no_error_log
[warn]
[info]
--- error_log
API disabled in the context of log_by_lua*
