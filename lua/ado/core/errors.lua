--- core/errors.lua — error factory for all SDK error types
-- All factory functions return a plain table; never throw.

local util = require("ado.core.util")

local M = {}

-- ---------------------------------------------------------------------------
-- Base builder
-- ---------------------------------------------------------------------------
local function base(type_, message, extras)
  local t = {
    type      = type_,
    message   = tostring(message or ""),
    retryable = false,
    status    = nil,
    code      = nil,
    retry_after = nil,
    request_id  = nil,
    raw         = nil,
  }
  if extras then
    for k, v in pairs(extras) do t[k] = v end
  end
  return t
end

-- ---------------------------------------------------------------------------
-- HTTP error (4xx / 5xx from ADO)
-- ---------------------------------------------------------------------------
--- Build an HTTP error from a status code + raw body + headers.
-- Automatically extracts ADO's message/typeKey fields from the body.
-- @param status  number  HTTP status code
-- @param body    string  raw response body (may be JSON)
-- @param headers table   response headers (lowercase keys)
-- @return error table
function M.http(status, body, headers)
  local retryable = status and status >= 500
  local message = "HTTP " .. tostring(status)
  local code = nil
  local request_id = headers and (headers["x-msrequestid"] or headers["x-ms-request-id"])

  -- Try to extract ADO error payload
  if body and body ~= "" then
    local decoded, _ = util.json_decode(body)
    if decoded then
      if decoded.message then message = decoded.message end
      if decoded.typeKey then code = decoded.typeKey end
    else
      -- body is not JSON — use raw text (truncated)
      if #body <= 256 then
        message = body
      else
        message = body:sub(1, 256) .. "…"
      end
    end
  end

  return base("http", message, {
    status     = status,
    code       = code,
    retryable  = retryable,
    request_id = request_id,
    raw        = body,
  })
end

-- ---------------------------------------------------------------------------
-- Auth error (401 / 403)
-- ---------------------------------------------------------------------------
function M.auth(status, body, headers)
  local message = "Authentication failed"
  local request_id = headers and (headers["x-msrequestid"] or headers["x-ms-request-id"])
  if body and body ~= "" then
    local decoded, _ = util.json_decode(body)
    if decoded and decoded.message then message = decoded.message end
  end
  return base("auth", message, {
    status     = status,
    retryable  = false,
    request_id = request_id,
    raw        = body,
  })
end

-- ---------------------------------------------------------------------------
-- Rate limit error (429)
-- ---------------------------------------------------------------------------
function M.rate_limit(status, body, headers)
  local message = "Rate limit exceeded"
  local retry_after = nil
  local request_id = headers and (headers["x-msrequestid"] or headers["x-ms-request-id"])
  if headers then
    local ra = headers["retry-after"]
    if ra then retry_after = tonumber(ra) end
  end
  if body and body ~= "" then
    local decoded, _ = util.json_decode(body)
    if decoded and decoded.message then message = decoded.message end
  end
  return base("rate_limit", message, {
    status      = status,
    retryable   = true,
    retry_after = retry_after,
    request_id  = request_id,
    raw         = body,
  })
end

-- ---------------------------------------------------------------------------
-- Transport error (curl failure, network error)
-- ---------------------------------------------------------------------------
--- @param exit_code number|nil  curl exit code or OS error code
--- @param detail    string|nil  stderr output or description
function M.transport(exit_code, detail)
  local message = "Transport error"
  if detail and detail ~= "" then
    message = "Transport error: " .. tostring(detail)
  elseif exit_code then
    message = "Transport error (exit " .. tostring(exit_code) .. ")"
  end
  return base("transport", message, {
    retryable = true,
    code      = exit_code and tostring(exit_code) or nil,
    raw       = detail,
  })
end

-- ---------------------------------------------------------------------------
-- Parse error (JSON decode failure)
-- ---------------------------------------------------------------------------
--- @param body string  raw body that failed to parse
--- @param err  string  parse error detail
function M.parse(body, err)
  local message = "Failed to parse response"
  if err then message = message .. ": " .. tostring(err) end
  return base("parse", message, {
    retryable = false,
    raw       = body,
  })
end

-- ---------------------------------------------------------------------------
-- Status routing helper
-- Routes a raw HTTP status to the correct error factory.
-- ---------------------------------------------------------------------------
--- @param status  number
--- @param body    string
--- @param headers table (lowercase keys)
--- @return error table
function M.from_status(status, body, headers)
  if status == 401 or status == 403 then
    return M.auth(status, body, headers)
  elseif status == 429 then
    return M.rate_limit(status, body, headers)
  else
    return M.http(status, body, headers)
  end
end

return M
