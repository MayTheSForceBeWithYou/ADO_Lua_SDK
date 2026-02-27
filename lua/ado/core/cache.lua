--- core/cache.lua — in-memory TTL + ETag cache
-- Depends on: util (for util.time)

local util = require("ado.core.util")

local M = {}
local Cache = {}
Cache.__index = Cache

--- Create a new cache instance.
-- @param opts table
--   opts.enabled boolean  cache active? (default false)
--   opts.ttl     number   default TTL in seconds (default 60)
-- @return cache
function M.new(opts)
  opts = opts or {}
  return setmetatable({
    enabled = opts.enabled == true,  -- explicit true required; default off
    default_ttl = opts.ttl or 60,
    _store = {},  -- key → { data, expires_at, etag }
  }, Cache)
end

--- Retrieve a cached entry if it exists and has not expired.
-- Expired entries are lazily evicted on access.
-- @param key string
-- @return entry table|nil  (the full SDK response table)
function Cache:get(key)
  local entry = self._store[key]
  if not entry then return nil end
  if util.time() > entry.expires_at then
    self._store[key] = nil
    return nil
  end
  return entry.data
end

--- Store a response in the cache.
-- @param key      string
-- @param response table   SDK response table to cache
-- @param ttl      number  TTL override in seconds (nil → default_ttl)
-- @param etag     string  ETag value for conditional requests (nil → cleared)
function Cache:set(key, response, ttl, etag)
  if not self.enabled then return end
  self._store[key] = {
    data       = response,
    expires_at = util.time() + (ttl or self.default_ttl),
    etag       = etag,
  }
end

--- Get the stored ETag for a cache key (without returning the data).
-- @param key string
-- @return string|nil
function Cache:get_etag(key)
  local entry = self._store[key]
  if not entry then return nil end
  -- Don't bother checking expiry — stale ETags are still valid for conditional reqs
  return entry.etag
end

--- Remove a specific key from the cache.
function Cache:invalidate(key)
  self._store[key] = nil
end

--- Remove all entries from the cache.
function Cache:flush()
  self._store = {}
end

return M
