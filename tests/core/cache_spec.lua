--- tests/core/cache_spec.lua — unit tests for core/cache.lua

local cache_mod = require("ado.core.cache")
local util      = require("ado.core.util")

describe("cache.new", function()
  it("is disabled by default", function()
    local c = cache_mod.new()
    assert.is_false(c.enabled)
  end)

  it("can be enabled", function()
    local c = cache_mod.new({ enabled = true })
    assert.is_true(c.enabled)
  end)
end)

describe("cache:get / cache:set", function()
  it("returns nil for unknown key", function()
    local c = cache_mod.new({ enabled = true })
    assert.is_nil(c:get("nonexistent"))
  end)

  it("stores and retrieves a value", function()
    local c = cache_mod.new({ enabled = true })
    local data = { status = 200, data = { value = { 1, 2 } } }
    c:set("key1", data, 60, nil)
    local retrieved = c:get("key1")
    assert.same(data, retrieved)
  end)

  it("returns nil after TTL expires", function()
    local c = cache_mod.new({ enabled = true })
    -- Store with TTL of -1 (already expired)
    c._store["key_exp"] = {
      data       = { status = 200 },
      expires_at = util.time() - 1,
      etag       = nil,
    }
    assert.is_nil(c:get("key_exp"))
    -- Verify lazy eviction removed it
    assert.is_nil(c._store["key_exp"])
  end)

  it("does not store when disabled", function()
    local c = cache_mod.new({ enabled = false })
    c:set("key1", { status = 200 }, 60, nil)
    assert.is_nil(c:get("key1"))
  end)
end)

describe("cache:get_etag", function()
  it("returns nil for unknown key", function()
    local c = cache_mod.new({ enabled = true })
    assert.is_nil(c:get_etag("missing"))
  end)

  it("returns stored etag", function()
    local c = cache_mod.new({ enabled = true })
    c:set("key1", { status = 200 }, 60, "\"abc123\"")
    assert.equals("\"abc123\"", c:get_etag("key1"))
  end)

  it("returns etag even for expired entries (for conditional requests)", function()
    local c = cache_mod.new({ enabled = true })
    c._store["old"] = {
      data       = { status = 200 },
      expires_at = util.time() - 100,
      etag       = "\"stale-etag\"",
    }
    -- get_etag should not check TTL
    assert.equals("\"stale-etag\"", c:get_etag("old"))
  end)
end)

describe("cache:invalidate / cache:flush", function()
  it("invalidate removes a specific key", function()
    local c = cache_mod.new({ enabled = true })
    c:set("k1", { ok = true }, 60, nil)
    c:set("k2", { ok = true }, 60, nil)
    c:invalidate("k1")
    assert.is_nil(c:get("k1"))
    assert.is_not_nil(c:get("k2"))
  end)

  it("flush removes all keys", function()
    local c = cache_mod.new({ enabled = true })
    c:set("k1", {}, 60, nil)
    c:set("k2", {}, 60, nil)
    c:flush()
    assert.is_nil(c:get("k1"))
    assert.is_nil(c:get("k2"))
  end)
end)
