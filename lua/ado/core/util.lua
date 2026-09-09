--- core/util.lua — pure-Lua base utilities: base64, query encoding, JSON adapter
-- No vim.* usage; safe for any runtime.

local M = {}

-- ---------------------------------------------------------------------------
-- Base64 encoder (RFC 4648, standard alphabet, with padding)
-- ---------------------------------------------------------------------------
local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

function M.base64(data)
  if data == nil then return "" end
  data = tostring(data)
  local result = {}
  local len = #data
  local i = 1
  while i <= len do
    local b0 = data:byte(i) or 0
    local b1 = data:byte(i + 1) or 0
    local b2 = data:byte(i + 2) or 0
    local triple = b0 * 0x10000 + b1 * 0x100 + b2
    result[#result + 1] = B64_CHARS:sub(math.floor(triple / 0x40000) % 64 + 1, math.floor(triple / 0x40000) % 64 + 1)
    result[#result + 1] = B64_CHARS:sub(math.floor(triple / 0x1000) % 64 + 1, math.floor(triple / 0x1000) % 64 + 1)
    result[#result + 1] = B64_CHARS:sub(math.floor(triple / 0x40) % 64 + 1, math.floor(triple / 0x40) % 64 + 1)
    result[#result + 1] = B64_CHARS:sub(triple % 64 + 1, triple % 64 + 1)
    i = i + 3
  end
  local encoded = table.concat(result)
  local remainder = len % 3
  if remainder == 1 then
    encoded = encoded:sub(1, -3) .. "=="
  elseif remainder == 2 then
    encoded = encoded:sub(1, -2) .. "="
  end
  return encoded
end

-- ---------------------------------------------------------------------------
-- URL percent-encoding
-- ---------------------------------------------------------------------------
local function percent_encode(s)
  s = tostring(s)
  -- Encode everything except unreserved chars per RFC 3986
  return (s:gsub("([^A-Za-z0-9%-_.~])", function(c)
    return string.format("%%%02X", c:byte())
  end))
end

--- Percent-encode a URL path, keeping slashes as separators.
-- Built without gsub replacement strings so "%20" is not re-interpreted
-- as a capture (`%2`).
-- @param path string e.g. "/My Project/_apis/wit/wiql"
-- @return string
function M.encode_path(path)
  if not path or path == "" then return path or "" end
  path = tostring(path)
  local out = {}
  local i, n = 1, #path
  while i <= n do
    local c = path:sub(i, i)
    if c == "/" then
      out[#out + 1] = "/"
      i = i + 1
    else
      local j = i
      while j <= n and path:sub(j, j) ~= "/" do
        j = j + 1
      end
      out[#out + 1] = percent_encode(path:sub(i, j - 1))
      i = j
    end
  end
  return table.concat(out)
end

--- Build a query string from a table.
-- Keys are sorted alphabetically for deterministic cache-key generation.
-- @param t table of key→value pairs (values coerced to string)
-- @return string like "foo=bar&zoo=baz" (empty string if t is empty/nil)
function M.query_encode(t)
  if not t or next(t) == nil then return "" end
  local keys = {}
  for k in pairs(t) do
    keys[#keys + 1] = k
  end
  table.sort(keys)
  local parts = {}
  for _, k in ipairs(keys) do
    local v = t[k]
    if v ~= nil then
      parts[#parts + 1] = percent_encode(tostring(k)) .. "=" .. percent_encode(tostring(v))
    end
  end
  return table.concat(parts, "&")
end

-- ---------------------------------------------------------------------------
-- JSON adapter — tries cjson, then vim.json (in Neovim), then dkjson
-- ---------------------------------------------------------------------------
local _json

local function _load_json()
  if _json then return _json end

  -- 1. cjson (fastest, available in LuaJIT / Neovim default)
  local ok, lib = pcall(require, "cjson")
  if ok and lib then
    _json = {
      encode = function(v) return lib.encode(v) end,
      decode = function(s) return lib.decode(s) end,
    }
    return _json
  end

  -- 2. vim.json (Neovim built-in, not a real module — access via global)
  local vim_g = rawget(_G, "vim")
  if vim_g and vim_g.json then
    _json = {
      encode = function(v) return vim_g.json.encode(v) end,
      decode = function(s) return vim_g.json.decode(s) end,
    }
    return _json
  end

  -- 3. dkjson (pure Lua fallback, installable via luarocks)
  ok, lib = pcall(require, "dkjson")
  if ok and lib then
    _json = {
      encode = function(v) return lib.encode(v) end,
      decode = function(s)
        local val, _, err = lib.decode(s)
        if err then return nil, err end
        return val
      end,
    }
    return _json
  end

  return nil
end

--- Encode a Lua value to a JSON string.
-- @return string|nil, err
function M.json_encode(value)
  local lib = _load_json()
  if not lib then
    return nil, { type = "parse", message = "No JSON library available (install cjson or dkjson)", retryable = false }
  end
  local ok, result = pcall(lib.encode, value)
  if not ok then
    return nil, { type = "parse", message = "JSON encode error: " .. tostring(result), retryable = false }
  end
  return result, nil
end

--- Decode a JSON string to a Lua value.
-- @return value|nil, err
function M.json_decode(s)
  if s == nil or s == "" then
    return nil, { type = "parse", message = "Cannot decode empty string", retryable = false }
  end
  local lib = _load_json()
  if not lib then
    return nil, { type = "parse", message = "No JSON library available (install cjson or dkjson)", retryable = false }
  end
  local ok, result, decode_err = pcall(lib.decode, s)
  if not ok then
    return nil, { type = "parse", message = "JSON decode error: " .. tostring(result), retryable = false, raw = s }
  end
  if decode_err then
    -- dkjson returns (value, pos, err) style via pcall wrapper
    return nil, { type = "parse", message = "JSON decode error: " .. tostring(decode_err), retryable = false, raw = s }
  end
  return result, nil
end

-- ---------------------------------------------------------------------------
-- Clock source (single point for TTL logic)
-- ---------------------------------------------------------------------------
function M.time()
  return os.time()
end

return M
