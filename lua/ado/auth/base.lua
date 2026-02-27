--- auth/base.lua — auth provider interface (documentation + duck-typing check)
-- All auth providers must implement this interface.
-- No dependencies.

local M = {}

--- Check that a table satisfies the auth provider interface.
-- @param provider table
-- @return boolean, string|nil  (true if valid; false + message if not)
function M.validate(provider)
  if type(provider) ~= "table" then
    return false, "auth provider must be a table"
  end
  if type(provider.get_authorization_header) ~= "function" then
    return false, "auth provider must implement get_authorization_header()"
  end
  if type(provider.refresh_if_needed) ~= "function" then
    return false, "auth provider must implement refresh_if_needed(opts)"
  end
  return true, nil
end

--[[
Auth provider interface:

  provider:get_authorization_header() → string
    Returns the value for the "Authorization" HTTP header (e.g. "Basic xxx").

  provider:refresh_if_needed(opts) → true, nil | nil, err
    Called before each request. PAT returns immediately (no-op).
    OAuth implementations refresh the access token if expired.
    Returns true on success, or nil + error table on failure.
]]

return M
