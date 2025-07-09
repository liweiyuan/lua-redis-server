local socket = require("socket")
local resp_protocol = require("resp_protocol")
local command_handlers = require("command_handlers")

-- 服务器配置
local HOST = "127.0.0.1"
local PORT = 6380

-- 主服务器逻辑
local server = socket.tcp() -- Create a TCP socket
server:setoption("reuseaddr", true) -- Optional: allow reusing address immediately
local ok, err = server:bind(HOST, PORT) -- Bind it
if not ok then
    print("Error: Could not bind to " .. HOST .. ":" .. PORT .. ": " .. tostring(err))
    return
end
local ok_listen, err_listen = server:listen(10) -- Start listening
if not ok_listen then
    print("Error: Could not listen on " .. HOST .. ":" .. PORT .. ": " .. tostring(err_listen))
    return
end

print("Lua Redis Server listening on " .. HOST .. ":" .. PORT)

local clients = {}

while true do
    local read_sockets = {server}
    for c in pairs(clients) do
        read_sockets[#read_sockets + 1] = c
    end

    local ready_sockets, _, _ = socket.select(read_sockets, nil, 0.1) -- 0.1 second timeout for select

    for _, s in ipairs(ready_sockets) do
        if s == server then
            -- New connection
            local client = server:accept()
            if client then
                print("Client connected: " .. client:getpeername())
                clients[client] = true -- Add to active clients
            end
        else
            -- Data from existing client
            local cmd_array, err = resp_protocol.parse_command(s)
            if not cmd_array then
                if err == "closed" then
                    print("Client disconnected: " .. s:getpeername())
                else
                    print("ERROR: parse_resp_command returned nil with error: " .. (err or "unknown error"))
                    local ok, send_err = pcall(s.send, s, resp_protocol.encode_error(err or "Unknown protocol error"))
                    if not ok then print("ERROR: Failed to send error response: " .. tostring(send_err)) end
                end
                s:close()
                clients[s] = nil -- Remove from active clients
            else
                -- Command successfully parsed
                local command_name = string.upper(cmd_array[1])
                local handler = command_handlers.commands[command_name]

                if handler then
                    local ok, handler_err = pcall(handler, s, cmd_array)
                    if not ok then
                        print("ERROR: Handler for '" .. command_name .. "' failed: " .. tostring(handler_err))
                        local ok_send, send_err = pcall(s.send, s, resp_protocol.encode_error("ERR internal server error"))
                        if not ok_send then print("ERROR: Failed to send internal error response: " .. tostring(send_err)) end
                    end
                else
                    local ok, send_err = pcall(s.send, s, resp_protocol.encode_error("ERR unknown command '" .. command_name .. "'"))
                    if not ok then print("ERROR: Failed to send unknown command error: " .. tostring(send_err)) end
                end
            end
        end
    end
end
