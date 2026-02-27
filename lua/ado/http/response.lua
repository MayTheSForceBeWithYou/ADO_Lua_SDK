--- http/response.lua — normalize raw transport output into SDK response shape
-- Depends on: util (json_decode), errors

local util   = require("ado.core.util")
local errors = require("ado.core.errors")

local M = {}

--- Normalize a raw response from transport:send() into the SDK response shape.
--
-- @param raw table  from transport:send():
--   raw.status  number
--   raw.headers table  (lowercase keys already)
--   raw.body    string
--
-- On success returns:
--   { data, status, headers, continuation_token, etag }
-- On error returns:
--   nil, error_table
function M.normalize(raw)
  if not raw then
    return nil, errors.transport(nil, "transport returned nil response")
  end

  local status  = raw.status
  local headers = raw.headers or {}
  local body    = raw.body or ""

  -- Lowercase all header keys (transport should do this, but be defensive)
  local lc_headers = {}
  for k, v in pairs(headers) do
    lc_headers[k:lower()] = v
  end

  -- Extract continuation token (ADO uses both spellings)
  local continuation_token =
    lc_headers["x-ms-continuationtoken"] or
    lc_headers["x-ms-continuation-token"]

  -- Extract ETag
  local etag = lc_headers["etag"]

  -- Handle error status codes
  if status and status >= 400 then
    return nil, errors.from_status(status, body, lc_headers)
  end

  -- Decode body (may be empty for 204 No Content)
  local data = nil
  if body ~= "" then
    local decoded, decode_err = util.json_decode(body)
    if decode_err then
      return nil, errors.parse(body, decode_err.message)
    end
    data = decoded
  end

  return {
    data               = data,
    status             = status,
    headers            = lc_headers,
    continuation_token = continuation_token,
    etag               = etag,
  }, nil
end

return M
