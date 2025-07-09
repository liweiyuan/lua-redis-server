#!/bin/bash

# Configuration
LOG_FILE="server.log"
PID_FILE="process.pid"
LUA_SERVER_CMD="lua main.lua" # The actual command to run the server

# Set LUA_PATH and LUA_CPATH for local LuaRocks installations
export LUA_PATH="./?.lua;$HOME/.luarocks/share/lua/5.4/?.lua;$HOME/.luarocks/share/lua/5.4/?/init.lua;"$LUA_PATH
export LUA_CPATH="$HOME/.luarocks/lib/lua/5.4/?.so;"$LUA_CPATH

# Function to check if the server is running
is_running() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        # Check if the process with this PID is actually running and is our server
        # Use 'pgrep -f' to find processes by full command line
        if pgrep -f "$LUA_SERVER_CMD" | grep -q "^$PID$"; then
            return 0 # Running
        else
            # PID file exists but process is not running or is not our server
            rm -f "$PID_FILE" # Clean up stale PID file
            return 1
        fi
    else
        return 1 # PID file not found
    fi
}

start_server() {
    if is_running; then
        echo "Server is already running (PID: $(cat "$PID_FILE"))."
        exit 1
    fi

    echo "Starting Lua Redis Server..."
    # Clear previous log before starting
    > "$LOG_FILE"

    # Start the server in the background, redirect output, and write PID
    nohup $LUA_SERVER_CMD > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE" # Write PID to file
    SERVER_PID=$!

    # Give it a moment to start and check if it's truly running
    sleep 1
    if is_running; then
        echo "Lua Redis Server started successfully."
        echo "Logs are being written to: $LOG_FILE"
        echo "Server PID: $SERVER_PID"
    else
        echo "Failed to start Lua Redis Server. Check $LOG_FILE for details."
        rm -f "$PID_FILE" # Clean up PID file if start failed
        exit 1
    fi
}

stop_server() {
    if ! is_running; then
        echo "Server is not running."
        exit 1
    fi

    PID=$(cat "$PID_FILE")
    echo "Stopping Lua Redis Server (PID: $PID)..."
    kill "$PID"
    # Give it a moment to terminate
    sleep 2
    if ! is_running; then
        echo "Server stopped successfully."
        rm -f "$PID_FILE"
        # Clear log file after successful stop as requested
        > "$LOG_FILE"
    else
        echo "Server did not stop gracefully. Force killing..."
        kill -9 "$PID"
        sleep 1
        if ! is_running; then
            echo "Server force-stopped."
            rm -f "$PID_FILE"
            > "$LOG_FILE"
        else
            echo "Failed to stop server (PID: $PID). Manual intervention may be required."
            exit 1
        fi
    fi
}

status_server() {
    if is_running; then
        echo "Lua Redis Server is running (PID: $(cat "$PID_FILE"))."
    else
        echo "Lua Redis Server is not running."
    fi
}

case "$1" in
    start)
        start_server
        ;;
    stop)
        stop_server
        ;;
    status)
        status_server
        ;;
    restart)
        stop_server
        start_server
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart}"
        exit 1
        ;;
esac

exit 0
