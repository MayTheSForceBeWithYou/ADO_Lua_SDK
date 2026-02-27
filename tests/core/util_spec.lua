--- tests/core/util_spec.lua — unit tests for core/util.lua

local util = require("ado.core.util")

describe("util.base64", function()
  it("encodes empty string", function()
    assert.equals("", util.base64(""))
  end)

  it("encodes 'f' → 'Zg=='", function()
    assert.equals("Zg==", util.base64("f"))
  end)

  it("encodes 'fo' → 'Zm8='", function()
    assert.equals("Zm8=", util.base64("fo"))
  end)

  it("encodes 'foo' → 'Zm9v'", function()
    assert.equals("Zm9v", util.base64("foo"))
  end)

  it("encodes 'foobar' → 'Zm9vYmFy'", function()
    assert.equals("Zm9vYmFy", util.base64("foobar"))
  end)

  it("encodes PAT auth format ':token' correctly", function()
    -- ADO Basic auth uses ":token" (empty username)
    local token = "mytoken"
    local encoded = util.base64(":" .. token)
    assert.is_string(encoded)
    -- Verify it's non-empty and contains only base64 characters
    assert.truthy(encoded:match("^[A-Za-z0-9+/=]+$"))
  end)

  it("produces correct encoding for ':abc123'", function()
    -- ':abc123' in base64 is 'OmFiYzEyMw=='
    assert.equals("OmFiYzEyMw==", util.base64(":abc123"))
  end)
end)

describe("util.query_encode", function()
  it("returns empty string for nil input", function()
    assert.equals("", util.query_encode(nil))
  end)

  it("returns empty string for empty table", function()
    assert.equals("", util.query_encode({}))
  end)

  it("encodes a single key-value pair", function()
    assert.equals("foo=bar", util.query_encode({ foo = "bar" }))
  end)

  it("sorts keys alphabetically for determinism", function()
    local result = util.query_encode({ zoo = "1", alpha = "2", mango = "3" })
    assert.equals("alpha=2&mango=3&zoo=1", result)
  end)

  it("percent-encodes spaces in values", function()
    local result = util.query_encode({ q = "hello world" })
    assert.equals("q=hello%20world", result)
  end)

  it("percent-encodes special characters", function()
    local result = util.query_encode({ x = "a&b=c" })
    assert.equals("x=a%26b%3Dc", result)
  end)

  it("coerces non-string values to string", function()
    local result = util.query_encode({ n = 42 })
    assert.equals("n=42", result)
  end)
end)

describe("util.json_encode / util.json_decode", function()
  it("round-trips a simple table", function()
    local t = { name = "Alice", age = 30 }
    local encoded, err = util.json_encode(t)
    assert.is_nil(err)
    assert.is_string(encoded)

    local decoded, err2 = util.json_decode(encoded)
    assert.is_nil(err2)
    assert.equals("Alice", decoded.name)
    assert.equals(30, decoded.age)
  end)

  it("round-trips nested tables", function()
    local t = { items = { 1, 2, 3 }, meta = { ok = true } }
    local encoded, _ = util.json_encode(t)
    local decoded, _ = util.json_decode(encoded)
    assert.equals(2, decoded.items[2])
    assert.is_true(decoded.meta.ok)
  end)

  it("json_decode returns nil + err for invalid JSON", function()
    local val, err = util.json_decode("not json {{{{")
    assert.is_nil(val)
    assert.is_not_nil(err)
    assert.equals("parse", err.type)
    assert.is_false(err.retryable)
  end)

  it("json_decode returns nil + err for empty string", function()
    local val, err = util.json_decode("")
    assert.is_nil(val)
    assert.is_not_nil(err)
    assert.equals("parse", err.type)
  end)

  it("json_decode returns nil + err for nil input", function()
    local val, err = util.json_decode(nil)
    assert.is_nil(val)
    assert.is_not_nil(err)
  end)
end)

describe("util.time", function()
  it("returns a positive number", function()
    local t = util.time()
    assert.is_number(t)
    assert.truthy(t > 0)
  end)

  it("is monotonically non-decreasing", function()
    local t1 = util.time()
    local t2 = util.time()
    assert.truthy(t2 >= t1)
  end)
end)
