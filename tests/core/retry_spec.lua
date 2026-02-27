--- tests/core/retry_spec.lua — unit tests for core/retry.lua

local retry_mod = require("ado.core.retry")

describe("retry.new", function()
  it("defaults to max_attempts=3", function()
    local policy = retry_mod.new()
    assert.equals(3, policy.max_attempts)
  end)

  it("accepts custom max_attempts", function()
    local policy = retry_mod.new({ max_attempts = 5 })
    assert.equals(5, policy.max_attempts)
  end)
end)

describe("policy:should_retry", function()
  local policy = retry_mod.new({ max_attempts = 3 })

  it("returns false when err is nil", function()
    assert.is_false(policy:should_retry(1, nil))
  end)

  it("returns false when retryable=false", function()
    local err = { retryable = false }
    assert.is_false(policy:should_retry(1, err))
  end)

  it("returns true when retryable=true and attempt < max_attempts", function()
    local err = { retryable = true }
    assert.is_true(policy:should_retry(1, err))
    assert.is_true(policy:should_retry(2, err))
  end)

  it("returns false when attempt >= max_attempts (attempt=3, max=3)", function()
    local err = { retryable = true }
    assert.is_false(policy:should_retry(3, err))
  end)

  it("returns false when attempt > max_attempts", function()
    local err = { retryable = true }
    assert.is_false(policy:should_retry(4, err))
  end)

  it("uses custom max_attempts boundary correctly", function()
    local p2 = retry_mod.new({ max_attempts = 1 })
    local err = { retryable = true }
    -- With max=1, even attempt 1 should NOT retry (1 < 1 is false)
    assert.is_false(p2:should_retry(1, err))
  end)
end)
