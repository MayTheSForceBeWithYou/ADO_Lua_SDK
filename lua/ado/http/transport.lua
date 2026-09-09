--- http/transport.lua — transport interface + curl (sync) + vim (async) adapters
-- Only the vim adapter may reference vim.*
-- Depends on: errors

local errors = require("ado.core.errors")

local M = {}

-- ---------------------------------------------------------------------------
-- Shared header/curl utilities
-- ---------------------------------------------------------------------------

--- Escape a string for safe embedding in a shell command argument.
-- We prefer passing args as a table to vim.system / io.popen where possible,
-- but the curl adapter builds a single command string.
local function shell_escape(s)
  -- Wrap in single quotes; replace ' with '\''
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

--- Parse the raw curl -i output (status line + headers + blank line + body).
-- Handles HTTP/1.1 100 Continue (two header blocks).
-- @param raw string  the full output from curl -i
-- @return status number, headers table (lowercase), body string
local function parse_curl_output(raw)
  -- curl -i outputs:  STATUS_LINE\r\nHEADERS\r\n\r\nBODY
  -- Some servers send HTTP/1.1 100 Continue then a second header block.
  -- Split on double CRLF or double LF.
  local parts = {}
  -- Try CRLF first, then fall back to LF
  local remainder = raw
  while true do
    local s, e = remainder:find("\r?\n\r?\n", 1, false)
    if not s then break end
    parts[#parts + 1] = remainder:sub(1, s - 1)
    remainder = remainder:sub(e + 1)
  end
  parts[#parts + 1] = remainder  -- last chunk is the body

  -- Find the last non-empty header block whose status line is a real response
  -- (skip 100 Continue blocks)
  local header_block, body
  for i = #parts - 1, 1, -1 do
    local block = parts[i]
    if block:match("^HTTP/%d[^\n]*[2-9]%d%d") or
       block:match("^HTTP/%d[^\n]*1[1-9]%d") then
      header_block = block
      body = table.concat(parts, "\r\n\r\n", i + 1)
      break
    end
    -- Also accept any HTTP response that isn't 1xx
    if block:match("^HTTP/") then
      header_block = block
      body = table.concat(parts, "\r\n\r\n", i + 1)
      break
    end
  end

  if not header_block then
    -- Fallback: first block is headers, rest is body
    header_block = parts[1] or ""
    body = table.concat(parts, "\r\n\r\n", 2)
  end

  -- Parse status line
  local status_code = tonumber(header_block:match("^HTTP/%S+%s+(%d%d%d)"))

  -- Parse headers
  local headers = {}
  for line in header_block:gmatch("[^\r\n]+") do
    if not line:match("^HTTP/") then
      local k, v = line:match("^([^:]+):%s*(.*)$")
      if k then
        headers[k:lower():gsub("%s+$", "")] = v:gsub("%s+$", "")
      end
    end
  end

  return status_code, headers, body or ""
end

-- ---------------------------------------------------------------------------
-- Curl adapter (synchronous, default)
-- ---------------------------------------------------------------------------

local CurlAdapter = {}
CurlAdapter.__index = CurlAdapter

function CurlAdapter:send(req, opts)
  opts = opts or {}

  -- Build curl argument list as a command string
  -- We use -i to get headers in output, -s for silent, -S to show errors
  local timeout_s = math.ceil((req.timeout or 30000) / 1000)

  local parts = {
    "curl", "-s", "-S", "-i", "-g",
    "-X", shell_escape(req.method),
    "--max-time", tostring(timeout_s),
  }

  -- Headers
  for k, v in pairs(req.headers or {}) do
    parts[#parts + 1] = "-H"
    parts[#parts + 1] = shell_escape(k .. ": " .. v)
  end

  -- Body
  if req.body_string and req.body_string ~= "" then
    parts[#parts + 1] = "--data-raw"
    parts[#parts + 1] = shell_escape(req.body_string)
  end

  parts[#parts + 1] = "--url"
  parts[#parts + 1] = shell_escape(req.url)

  local cmd = table.concat(parts, " ") .. " 2>&1"

  local handle = io.popen(cmd, "r")
  if not handle then
    local err = errors.transport(nil, "io.popen failed to launch curl", req.url)
    if opts.callback then opts.callback(nil, err) end
    return nil, err
  end

  local raw_output = handle:read("*a")
  local ok = handle:close()

  if not ok and (not raw_output or raw_output == "") then
    local err = errors.transport(nil, "curl command failed with no output", req.url)
    if opts.callback then opts.callback(nil, err) end
    return nil, err
  end

  local status, headers, body = parse_curl_output(raw_output)
  if not status then
    local err = errors.transport(nil, "failed to parse curl output: " .. (raw_output:sub(1, 200)), req.url)
    if opts.callback then opts.callback(nil, err) end
    return nil, err
  end

  local res = { status = status, headers = headers, body = body }

  if opts.callback then
    opts.callback(res, nil)
  end
  return res, nil
end

-- ---------------------------------------------------------------------------
-- Vim adapter (asynchronous, Neovim only)
-- ---------------------------------------------------------------------------

local VimAdapter = {}
VimAdapter.__index = VimAdapter

function VimAdapter:send(req, opts)
  opts = opts or {}

  -- Build curl args as a table for vim.system (safer than shell escaping)
  local timeout_s = math.ceil((req.timeout or 30000) / 1000)
  local args = {
    "curl", "-s", "-S", "-i", "-g",
    "-X", req.method,
    "--max-time", tostring(timeout_s),
  }

  for k, v in pairs(req.headers or {}) do
    args[#args + 1] = "-H"
    args[#args + 1] = k .. ": " .. v
  end

  if req.body_string and req.body_string ~= "" then
    args[#args + 1] = "--data-raw"
    args[#args + 1] = req.body_string
  end

  args[#args + 1] = "--url"
  args[#args + 1] = req.url

  -- vim.system callbacks run in a fast context; schedule so plugin UI can update.
  local function deliver(res, err)
    if not opts.callback then return end
    vim.schedule(function()  -- luacheck: ignore vim
      opts.callback(res, err)
    end)
  end

  local function on_exit(obj)
    if obj.code ~= 0 then
      deliver(nil, errors.transport(obj.code, obj.stderr, req.url))
      return
    end
    local status, headers, body = parse_curl_output(obj.stdout or "")
    if not status then
      deliver(nil, errors.transport(nil, "failed to parse curl output", req.url))
      return
    end
    deliver({ status = status, headers = headers, body = body }, nil)
  end

  if opts.callback then
    -- Async: let vim.system call on_exit in the background
    -- vim.* only referenced here — this adapter is Neovim-only
    vim.system(args, { text = true }, on_exit)  -- luacheck: ignore vim
    return nil, nil
  else
    -- Synchronous fallback via vim.system + vim.wait (documented limitation)
    local done = false
    local result_res, result_err
    vim.system(args, { text = true }, function(obj)  -- luacheck: ignore vim
      if obj.code ~= 0 then
        result_err = errors.transport(obj.code, obj.stderr, req.url)
      else
        local status, headers, body = parse_curl_output(obj.stdout or "")
        if not status then
          result_err = errors.transport(nil, "failed to parse curl output", req.url)
        else
          result_res = { status = status, headers = headers, body = body }
        end
      end
      done = true
    end)
    -- vim.wait polls the event loop until done
    vim.wait(30000, function() return done end, 10)  -- luacheck: ignore vim
    return result_res, result_err
  end
end

-- ---------------------------------------------------------------------------
-- Factory
-- ---------------------------------------------------------------------------

--- Create a transport adapter.
-- @param opts table  opts.backend = "curl" (default) | "vim"
-- @return adapter
function M.new(opts)
  opts = opts or {}
  local backend = opts.backend or "curl"
  if backend == "vim" then
    return setmetatable({}, VimAdapter)
  else
    return setmetatable({}, CurlAdapter)
  end
end

return M
