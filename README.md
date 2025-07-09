# Lua Redis Server

A simple Redis-like server implemented in Lua.

## Description

This project is a lightweight, non-blocking Redis server clone written entirely in Lua. It uses `luasocket` for handling TCP connections and implements the RESP (REdis Serialization Protocol) for communication.

Currently, it supports the following Redis commands:
- `PING`
- `GET`
- `SET`

## Prerequisites

- Lua 5.1+ (developed with 5.4)
- LuaRocks

## Installation

The only external dependency is `luasocket`. You can install it locally using LuaRocks:

```sh
luarocks install --local luasocket
```

All other dependencies are included in this project.

## Usage

The server can be managed using the provided shell script.

### Start the server

This will start the server in the background.

```sh
./start_server.sh start
```

### Stop the server

```sh
./start_server.sh stop
```

### Check server status

```sh
./start_server.sh status
```

### Restart the server

```sh
./start_server.sh restart
```

## How it works

- `main.lua`: The main entry point that starts the TCP server.
- `server.lua`: Handles the server logic, including accepting connections and managing clients.
- `command_handlers.lua`: Contains the implementation for each supported Redis command.
- `data_store.lua`: A simple in-memory data store using a Lua table.
- `resp_protocol.lua`: Handles parsing and encoding of the RESP protocol.
