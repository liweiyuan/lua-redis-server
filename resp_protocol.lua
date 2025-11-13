local resp_protocol = {}
local logger = require("logger")

-- RESP 协议编码函数
-- 编码简单字符串回复
function resp_protocol.encode_string(str)
    return "+" .. str .. "\r\n"
end

-- 编码批量字符串回复
function resp_protocol.encode_bulk_string(str)
    if str == nil then
        return "$-1\r\n" -- Null Bulk String
    end
    return "$" .. #str .. "\r\n" .. str .. "\r\n"
end

-- 编码错误回复
function resp_protocol.encode_error(err_msg)
    return "-" .. err_msg .. "\r\n"
end

-- 编码数组回复
function resp_protocol.encode_array(arr)
    if not arr then return "*-1\r\n" end -- Null Array
    local result = "*" .. #arr .. "\r\n"
    for _, v in ipairs(arr) do
        -- 简单起见，这里只处理字符串和批量字符串
        if type(v) == "string" then
            result = result .. resp_protocol.encode_bulk_string(v)
        else
            -- 如果有其他类型，需要更复杂的处理
            result = result .. resp_protocol.encode_error("ERR unsupported type in array encoding")
        end
    end
    return result
end

-- 极简 RESP 协议解析函数 (仅支持数组命令，如 *2\r\n$4\r\nPING\r\n)
-- 注意：此函数现在假定客户端套接字是阻塞的，或者在调用前已通过 select 确认有数据
function resp_protocol.parse_command(client)
    local line, err = client:receive("*l")
    if not line or err then return nil, err end

    if line:sub(1, 1) == "*" then -- 数组类型
        local num_elements = tonumber(line:sub(2))
        if not num_elements or num_elements < 0 then return nil, "ERR invalid array length" end

        local command = {}
        for i = 1, num_elements do
            local bulk_len_line, err = client:receive("*l")
            if not bulk_len_line or err then return nil, err end
            if bulk_len_line:sub(1, 1) ~= "$" then return nil, "ERR expected bulk string" end

            local bulk_len = tonumber(bulk_len_line:sub(2))
            if not bulk_len or bulk_len < 0 then return nil, "ERR invalid bulk string length" end

            local bulk_data, err = client:receive(bulk_len)
            if not bulk_data or err then return nil, err end

            -- 消耗掉 CRLF
            local crlf, err = client:receive(2)
            if err then
                logger.log("ERROR", "Socket error while consuming CRLF: " .. tostring(err))
                return nil, err
            end
            if crlf ~= "\r\n" then
                logger.log("ERROR",
                    "Expected CRLF but received: '" ..
                    (crlf or "nil") .. "' (length: " .. (crlf and #crlf or "nil") .. ")")
                return nil, "ERR protocol error: missing CRLF after bulk data"
            end

            table.insert(command, bulk_data)
        end
        return command
    else
        -- 简单起见，目前只处理数组命令
        return nil, "ERR only array commands are supported for now"
    end
end

return resp_protocol
