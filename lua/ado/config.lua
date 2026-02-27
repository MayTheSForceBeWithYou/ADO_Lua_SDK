--- config.lua — normalize and validate client configuration
-- Depends on: errors

local errors = require("ado.core.errors")

local M = {}

--- Derive the VSSPS URL from a standard ADO org URL.
-- https://dev.azure.com/ORG       → https://vssps.dev.azure.com/ORG
-- https://ORG.visualstudio.com    → https://ORG.vssps.visualstudio.com
-- Other formats: returned unchanged (best-effort)
local function derive_vssps_url(base_url)
  -- dev.azure.com pattern
  local org = base_url:match("^https?://dev%.azure%.com/([^/]+)")
  if org then
    return "https://vssps.dev.azure.com/" .. org
  end
  -- ORG.visualstudio.com pattern
  local prefix = base_url:match("^(https?://[^.]+)%.visualstudio%.com")
  if prefix then
    -- Insert .vssps before .visualstudio.com
    local scheme_host = base_url:match("^https?://([^.]+)")
    return "https://" .. scheme_host .. ".vssps.visualstudio.com"
  end
  -- Unknown format — return as-is
  return base_url
end

--- Normalize and validate client options.
-- @param opts table  user-supplied options
-- @return config table|nil, err|nil
function M.normalize(opts)
  if type(opts) ~= "table" then
    return nil, {
      type      = "http",
      message   = "ado.new() requires an options table",
      retryable = false,
    }
  end

  -- Required: base_url
  local base_url = opts.base_url
  if type(base_url) ~= "string" or base_url == "" then
    return nil, {
      type      = "http",
      message   = "config.base_url is required (e.g. 'https://dev.azure.com/myorg')",
      retryable = false,
    }
  end
  -- Trim trailing slash
  base_url = base_url:gsub("/+$", "")

  -- Required: auth
  local auth = opts.auth
  if type(auth) ~= "table" then
    return nil, {
      type      = "auth",
      message   = "config.auth is required (use ado.auth.pat(token))",
      retryable = false,
    }
  end
  if type(auth.get_authorization_header) ~= "function" then
    return nil, {
      type      = "auth",
      message   = "config.auth must be a valid auth provider (missing get_authorization_header)",
      retryable = false,
    }
  end

  -- Defaults
  local api_version = opts.api_version or "7.0"
  local timeout     = opts.timeout or 30000
  local transport   = opts.transport or "curl"

  -- Cache config
  local cache_opts = opts.cache or {}
  local cache = {
    enabled = cache_opts.enabled == true,
    ttl     = cache_opts.ttl or 60,
  }

  -- Retry config
  local retry_opts = opts.retry or {}
  local retry = {
    max_attempts = retry_opts.max_attempts or 3,
    backoff_opts = retry_opts.backoff_opts or {},
  }

  -- VSSPS URL
  local vssps_url = opts.vssps_url or derive_vssps_url(base_url)

  return {
    base_url    = base_url,
    auth        = auth,
    api_version = api_version,
    timeout     = timeout,
    transport   = transport,
    cache       = cache,
    retry       = retry,
    vssps_url   = vssps_url,
    logger      = opts.logger,  -- nil = use noop
  }, nil
end

return M
