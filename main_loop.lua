local socket = require("socket")
local resp_protocol = require("resp_protocol")
local command_handlers = require("command_handlers")
local logger = require("logger")

local clients = {}
local client_coroutines = {}

local function handle_new_connection(server)
    local client = server:accept()
    if client then
        logger.log("INFO", "Client connected: " .. client:getpeername())
        clients[client] = true
    end
end

local function handle_client_data(s)
    local cmd_array, err = resp_protocol.parse_command(s)
    if not cmd_array then
        if err == "closed" then
            logger.log("INFO", "Client disconnected: " .. s:getpeername())
        else
            logger.log("ERROR", "parse_resp_command returned nil with error: " .. (err or "unknown error"))
            local ok, send_err = pcall(s.send, s, resp_protocol.encode_error(err or "Unknown protocol error"))
            if not ok then logger.log("ERROR", "Failed to send error response: " .. tostring(send_err)) end
        end
        s:close()
        clients[s] = nil
        client_coroutines[s] = nil
    else
        -- Command successfully parsed
        local command_name = string.upper(cmd_array[1])
        local handler = command_handlers.commands[command_name]

        if handler then
            local ok, handler_err = pcall(handler, s, cmd_array)
            if not ok then
                logger.log("ERROR", "Handler for '" .. command_name .. "' failed: " .. tostring(handler_err))
                local ok_send, send_err = pcall(s.send, s, resp_protocol.encode_error("ERR internal server error"))
                if not ok_send then logger.log("ERROR", "Failed to send internal error response: " .. tostring(send_err)) end
            end
        else
            local ok, send_err = pcall(s.send, s, resp_protocol.encode_error("ERR unknown command '" .. command_name .. "'"))
            if not ok then logger.log("ERROR", "Failed to send unknown command error: " .. tostring(send_err)) end
        end
    end
end

local function run_main_loop(server)
    while true do
        local read_sockets = {server}
        for c in pairs(clients) do
            read_sockets[#read_sockets + 1] = c
        end

        local ready_sockets, _, _ = socket.select(read_sockets, nil, 0.1) -- 0.1秒超时

        -- 检查是否有准备好的套接字
        if #ready_sockets > 0 then
            for _, s in ipairs(ready_sockets) do
                if s == server then
                    handle_new_connection(server)
                else
                    -- 为每个客户端创建一个协程来处理数据
                    if not client_coroutines[s] then
                        client_coroutines[s] = coroutine.create(function()
                            while clients[s] do
                                handle_client_data(s)
                                coroutine.yield()
                            end
                        end)
                    end

                    -- 恢复协程的执行
                    local ok, err = coroutine.resume(client_coroutines[s])
                    if not ok then
                        logger.log("ERROR", "Coroutine error: " .. tostring(err))
                        s:close()
                        clients[s] = nil
                        client_coroutines[s] = nil
                    end
                end
            end
        end
    end
end

return {
    run_main_loop = run_main_loop
}