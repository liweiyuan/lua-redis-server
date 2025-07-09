local M = {}

function M.log(level, message)
    print(string.format("[%s] %s", level, message))
end

return M