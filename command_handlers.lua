local command_handlers = {}
local resp_protocol = require("resp_protocol")
local data_store = require("data_store")
local logger = require("logger")

-- 命令处理函数
-- 处理 PING 命令
local function handle_ping(client, args)
    if #args > 1 then
        logger.log("WARN", "PING: wrong number of arguments: " .. #args)
        client:send(resp_protocol.encode_error("ERR wrong number of arguments for 'ping' command"))
    elseif #args == 1 then
        client:send(resp_protocol.encode_string("PONG"))
    else
        client:send(resp_protocol.encode_string("PONG"))
    end
end

-- 处理 SET 命令
local function handle_set(client, args)
    if #args < 3 then
        logger.log("WARN", "SET: wrong number of arguments: " .. #args)
        client:send(resp_protocol.encode_error("ERR wrong number of arguments for 'set' command"))
        return
    end
    local key = args[2]
    local value = args[3]
    data_store.set(key, value)
    client:send(resp_protocol.encode_string("OK"))
end

-- 处理 GET 命令
local function handle_get(client, args)
    if #args < 2 then
        logger.log("WARN", "GET: wrong number of arguments: " .. #args)
        client:send(resp_protocol.encode_error("ERR wrong number of arguments for 'get' command"))
        return
    end
    local key = args[2]
    local value = data_store.get(key)
    client:send(resp_protocol.encode_bulk_string(value))
end

-- 命令分发表
command_handlers.commands = {
    ["PING"] = handle_ping,
    ["SET"] = handle_set,
    ["GET"] = handle_get,
}

return command_handlers
