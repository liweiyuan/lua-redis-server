local socket = require("socket")
local logger = require("logger")
local main_loop = require("main_loop")

-- 服务器配置
local HOST = os.getenv("LUA_REDIS_HOST") or "127.0.0.1"
local PORT = tonumber(os.getenv("LUA_REDIS_PORT")) or 6380

-- 主服务器逻辑
local server = socket.tcp() -- 创建TCP套接字
server:setoption("reuseaddr", true) -- 设置地址重用选项
local ok, err = server:bind(HOST, PORT) -- 绑定地址和端口
if not ok then
    logger.log("ERROR", "Could not bind to " .. HOST .. ":" .. PORT .. ": " .. tostring(err))
    return
end
local ok_listen, err_listen = server:listen(10) -- 开始监听连接
if not ok_listen then
    logger.log("ERROR", "Could not listen on " .. HOST .. ":" .. PORT .. ": " .. tostring(err_listen))
    return
end

logger.log("INFO", "Lua Redis Server listening on " .. HOST .. ":" .. PORT)

-- 启动主循环
main_loop.run_main_loop(server)
