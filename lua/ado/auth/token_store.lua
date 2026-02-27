--- auth/token_store.lua — token store interface (documentation + duck-typing check)
-- Token stores are used by OAuth providers (v2+).
-- In v1, only the in-memory store is implemented.
-- No dependencies.

local M = {}

--- Check that a table satisfies the token store interface.
-- @param store table
-- @return boolean, string|nil
function M.validate(store)
  if type(store) ~= "table" then
    return false, "token store must be a table"
  end
  for _, method in ipairs({ "get", "set", "delete" }) do
    if type(store[method]) ~= "function" then
      return false, "token store must implement " .. method .. "()"
    end
  end
  return true, nil
end

--[[
Token store interface:

  store:get(key) → value|nil
    Retrieve a stored token by key. Returns nil if not found or expired.

  store:set(key, value, opts)
    Persist a token. opts.ttl = seconds until expiry (nil = no expiry).

  store:delete(key)
    Remove a stored token.
]]

return M
