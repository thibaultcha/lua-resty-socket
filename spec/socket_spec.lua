local socket = require "lib.resty.socket"

describe("resty.socket", function()
  it("fallback on LuaSocket outside of ngx_lua", function()
    local sock = socket.tcp()
    assert.truthy(sock)
    assert.is_table(getmetatable(sock))

    local ok, err = sock:connect("google.com", 80)
    assert.falsy(err)
    assert.equal(1, ok)

    local bytes, err = sock:send "HEAD / HTTP/1.1\r\n\r\n"
    assert.falsy(err)
    assert.is_number(bytes)

    local res, err = sock:receive "*l"
    assert.falsy(err)
    assert.equal("HTTP/1.1 200 OK", res)

    finally(function()
      sock:close()
    end)
  end)

  describe("setkeepalive()", function()
    it("call close()", function()
      local sock = socket.tcp()
      assert.truthy(sock)

      local ok, err = sock:connect("google.com", 80)
      assert.falsy(err)
      assert.equal(1, ok)

      sock:setkeepalive()

      local _, err = sock:send "HEAD / HTTP/1.1\r\n\r\n"
      assert.equal("closed", err)
    end)
  end)

  it("expose metadata", function()
    assert.equal("0.0.1", socket._VERSION)
    assert.is_table(socket.luasocket_mt)
  end)
end)
