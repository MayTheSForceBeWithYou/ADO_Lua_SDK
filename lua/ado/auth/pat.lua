--- auth/pat.lua — Personal Access Token (PAT) auth provider
-- Implements the auth provider interface using HTTP Basic auth.
-- Depends on: util (base64), auth/base (interface check)

local util = require("ado.core.util")

local M = {}
local PAT = {}
PAT.__index = PAT

--- Create a new PAT auth provider.
-- @param token string  the PAT token (never logged or included in errors)
-- @return provider|nil, err|nil
function M.new(token)
  if type(token) ~= "string" or token == "" then
    return nil, {
      type      = "auth",
      message   = "PAT token must be a non-empty string",
      retryable = false,
    }
  end
  -- Pre-compute the header value at construction time to avoid repeated encoding.
  -- ADO PAT format: Basic base64(":" .. token)
  local encoded = util.base64(":" .. token)
  return setmetatable({
    _header = "Basic " .. encoded,
    -- NOTE: _pat is intentionally NOT stored to prevent accidental logging.
  }, PAT), nil
end

--- Return the Authorization header value.
-- @return string  e.g. "Basic dXNlcjpwYXN..."
function PAT:get_authorization_header()
  return self._header
end

--- No-op for PAT — tokens don't expire.
-- @return true, nil
function PAT:refresh_if_needed(_opts)
  return true, nil
end

return M
