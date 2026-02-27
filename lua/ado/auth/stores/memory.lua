--- auth/stores/memory.lua — in-memory token store
-- No dependencies.

local M = {}
local Store = {}
Store.__index = Store

--- Create a new in-memory token store.
function M.new()
  return setmetatable({ _data = {} }, Store)
end

--- Retrieve a stored value by key.
-- Returns nil if not found or if the entry has expired.
-- @param key string
-- @return value|nil
function Store:get(key)
  local entry = self._data[key]
  if not entry then return nil end
  if entry.expires_at and os.time() > entry.expires_at then
    self._data[key] = nil
    return nil
  end
  return entry.value
end

--- Store a value.
-- @param key   string
-- @param value any
-- @param opts  table  opts.ttl = seconds until expiry (nil = no expiry)
function Store:set(key, value, opts)
  opts = opts or {}
  local expires_at = nil
  if opts.ttl then
    expires_at = os.time() + opts.ttl
  end
  self._data[key] = { value = value, expires_at = expires_at }
end

--- Remove a stored value.
-- @param key string
function Store:delete(key)
  self._data[key] = nil
end

return M
