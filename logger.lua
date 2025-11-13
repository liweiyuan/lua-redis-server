local M = {}

-- 日志记录函数
function M.log(level, message)
    print(string.format("[%s] %s", level, message))
end

return M