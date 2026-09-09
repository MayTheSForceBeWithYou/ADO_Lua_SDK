--- http/request.lua — build a normalized request table from config + req_spec
-- Depends on: util (query_encode, json_encode)

local util = require("ado.core.util")

local M = {}

--- Build a normalized request table ready for transport:send().
--
-- @param config   table  client config (base_url, api_version, timeout, …)
-- @param req_spec table  per-request specification:
--   req_spec.method     string  "GET"|"POST"|"PATCH"|"PUT"|"DELETE" (default "GET")
--   req_spec.path       string  URL path, e.g. "/_apis/projects"
--   req_spec.base_url   string  optional override (e.g. vssps URL for identity)
--   req_spec.params     table   query parameters (merged with api-version)
--   req_spec.body       table|string|nil  request body
--   req_spec.headers    table   per-request header overrides
--   req_spec.timeout    number  ms override
--
-- @return request table:
--   { method, url, headers, body_string, timeout }
function M.build(config, req_spec)
  req_spec = req_spec or {}

  local method  = (req_spec.method or "GET"):upper()
  local base    = req_spec.base_url or config.base_url
  local path    = req_spec.path or ""

  -- Merge query params: spec params + api-version (spec can override api-version)
  local query = {}
  -- Start with any config-level defaults (none currently, but extensible)
  -- Inject api-version first so spec params can override it
  query["api-version"] = config.api_version or "7.0"
  if req_spec.params then
    for k, v in pairs(req_spec.params) do
      query[k] = v
    end
  end

  local qs = util.query_encode(query)
  local url = base .. util.encode_path(path)
  if qs ~= "" then url = url .. "?" .. qs end
  url = url:gsub("[\r\n]", "")

  -- Build headers
  local headers = {
    ["Accept"]       = "application/json",
    ["Content-Type"] = "application/json",
  }
  -- Apply per-request header overrides
  if req_spec.headers then
    for k, v in pairs(req_spec.headers) do
      headers[k] = v
    end
  end

  -- Encode body
  local body_string = nil
  if req_spec.body ~= nil then
    if type(req_spec.body) == "string" then
      body_string = req_spec.body
    else
      local encoded, err = util.json_encode(req_spec.body)
      if err then
        -- Return a minimal request with the encode error attached so pipeline can surface it
        return { _encode_error = err }
      end
      body_string = encoded
    end
  end

  -- Timeout: spec overrides config (config is in ms; pass through as-is)
  local timeout = req_spec.timeout or config.timeout or 30000

  return {
    method      = method,
    url         = url,
    headers     = headers,
    body_string = body_string,
    timeout     = timeout,
  }
end

return M
