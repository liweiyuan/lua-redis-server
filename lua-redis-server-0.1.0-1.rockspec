package = "lua-redis-server"
version = "0.1.0-1"

source = {
    url = ".", -- 指向当前目录
    dir = "."
}

description = {
    summary = "A simple Redis server implemented in Lua.",
    detailed = [[
        A basic Redis-like server written in Lua, supporting GET, SET, and PING commands.
    ]],
    homepage = "https://github.com/your-username/lua-redis-server", -- 请替换为您的项目主页
    license = "MIT"
}

dependencies = {
    "lua >= 5.1",
    "luasocket" -- 我们仍然依赖 luasocket
}

build = {
    type = "builtin",
    modules = {
        ["main"] = "main.lua" -- 定义主模块
    }
}
