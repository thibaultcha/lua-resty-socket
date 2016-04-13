local socket = require 'lib.resty.socket'

describe('resty.socket', function()
  it('fallbacks on LuaSocket outside of ngx_lua', function()
    local sock = assert(socket.tcp())
    assert.is_table(getmetatable(sock))

    finally(function()
      sock:close()
    end)

    local ok = assert(sock:connect('www.google.com', 80))
    assert.equal(1, ok)

    local bytes = assert(sock:send('HEAD / HTTP/1.1\r\nHost: www.google.com\r\nConnection: close\r\n\r\n'))
    assert.is_number(bytes)

    local status = assert(sock:receive())
    assert.equal("HTTP/1.1 200 OK", status)
  end)

  describe('setkeepalive()', function()
    it('calls close()', function()
      local sock = assert(socket.tcp())

      local ok = assert(sock:connect('www.google.com', 80))
      assert.equal(1, ok)

      sock:setkeepalive()

      local _, err = sock:send('HEAD / HTTP/1.1\r\nHost: www.google.com\r\nConnection: close\r\n\r\n')
      assert.equal("closed", err)
    end)
  end)

  it('exposes metadata', function()
    assert.matches('%d.%d.%d', socket._VERSION)
    assert.is_table(socket.luasocket_mt)
  end)
end)
