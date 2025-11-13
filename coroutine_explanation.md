# Lua Redis Server 协程处理详解

本文档旨在解释 `lua-redis-server` 项目中如何使用 Lua 协程来处理多个客户端的并发连接，以避免阻塞。

## 核心概念

- **协程 (Coroutine)**: Lua 中的一种协作式多任务处理机制。协程类似于轻量级线程，但它们的执行是由程序员显式控制的，而不是由操作系统调度。协程可以在任何时候暂停执行（`yield`）并将控制权返回给调用者，并且可以在之后从它暂停的地方恢复执行（`resume`）。

## 实现细节

### 1. 数据结构

- `clients`: 一个 Lua 表，用于跟踪当前所有活跃的客户端连接。键是客户端套接字对象，值是 `true`。
- `client_coroutines`: 一个 Lua 表，用于存储与每个客户端套接字关联的协程。键是客户端套接字对象，值是对应的协程。

### 2. 协程创建

当主循环通过 `socket.select` 检测到一个已存在的客户端套接字 `s` 有数据可读时，会执行以下逻辑：

```lua
-- 检查是否已为该客户端创建协程
if not client_coroutines[s] then
    -- 为客户端创建一个新的协程
    client_coroutines[s] = coroutine.create(function()
        -- 协程的主循环：只要客户端连接存在
        while clients[s] do
            -- 处理客户端的一个命令
            handle_client_data(s)
            -- 处理完后，主动让出控制权
            coroutine.yield()
        end
    end)
end
```

- `coroutine.create`: 创建一个新的协程，它包装了一个匿名函数。这个函数包含一个循环，用于持续处理该客户端的数据。
- `while clients[s] do ... end`: 确保只要客户端连接是活跃的，协程就会继续尝试处理它的数据。
- `handle_client_data(s)`: 调用函数来处理来自客户端 `s` 的一个完整的 RESP 命令。
- `coroutine.yield()`: 在处理完一个命令后，协程主动暂停。这会将控制权立即返回给 `coroutine.resume` 的调用者（即主循环），使得主循环可以继续处理其他套接字（例如，接受新连接或其他客户端的数据）。

### 3. 协程执行

创建协程后，主循环会立即尝试运行它：

```lua
-- 恢复（或启动）与客户端关联的协程
local ok, err = coroutine.resume(client_coroutines[s])
if not ok then
    -- 如果协程内部出错，则记录错误、关闭连接并清理
    logger.log("ERROR", "Coroutine error: " .. tostring(err))
    s:close()
    clients[s] = nil
    client_coroutines[s] = nil
end
```

- `coroutine.resume`: 启动一个新创建的协程，或恢复一个已暂停的协程。
    - 如果是第一次调用 `resume`，协程会从其包装函数的开始处执行，直到遇到 `yield`。
    - 如果协程之前因为 `yield` 而暂停，`resume` 会使它从 `yield` 之后的地方继续执行。
- 错误处理：`resume` 返回 `ok` 和可能的 `err`。如果协程执行出错（`ok` 为 false），则记录日志并清理相关资源。

## 工作流程总结

1.  **客户端连接**: 客户端连接到服务器，其套接字 `s` 被添加到 `clients` 表中。
2.  **事件检测**: 主循环的 `socket.select` 检测到套接字 `s` 有数据可读。
3.  **协程创建**: 如果 `client_coroutines[s]` 不存在，则为 `s` 创建一个新的协程。
4.  **协程启动/恢复**: 调用 `coroutine.resume(client_coroutines[s])`。
5.  **命令处理**: 协程内的函数调用 `handle_client_data(s)` 来处理一个命令。
6.  **主动让出**: `handle_client_data` 完成后，协程调用 `coroutine.yield()` 暂停。
7.  **控制权返回**: 控制权返回给主循环，主循环可以继续处理其他事件（如接受新连接或其他客户端的数据）。
8.  **循环**: 当 `socket.select` 再次检测到 `s` 可读时，重复步骤 4-6，协程会处理下一个命令。

通过这种方式，服务器可以在单线程环境中实现一种伪并发，有效地处理多个客户端的请求，而无需为每个客户端创建操作系统级线程或进程。