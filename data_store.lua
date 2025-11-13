local data_store = {}

-- Redis 数据库 (简单的 Lua 表)
local db = {}

-- 设置键值对
function data_store.set(key, value)
    db[key] = value
end

-- 获取键对应的值
function data_store.get(key)
    return db[key]
end

return data_store
