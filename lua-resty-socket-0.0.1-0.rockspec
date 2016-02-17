package = "lua-resty-socket"
version = "0.0.1-0"
source = {
  url = "git://github.com/thibaultCha/lua-resty-socket",
  tag = "0.0.1"
}
description = {
  summary = "A module offering interoperability between the LuaSocket and cosocket APIs",
  homepage = "http://thibaultcha.github.io/lua-resty-socket",
  license = "MIT"
}
dependencies = {

}
build = {
  type = "builtin",
  modules = {
    ["resty.socket"] = "lib/resty/socket.lua"
  }
}
