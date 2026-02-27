--- tests/core/errors_spec.lua — unit tests for core/errors.lua

local errors = require("ado.core.errors")

describe("errors.from_status routing", function()
  it("routes 401 to auth error", function()
    local err = errors.from_status(401, "", {})
    assert.equals("auth", err.type)
    assert.is_false(err.retryable)
    assert.equals(401, err.status)
  end)

  it("routes 403 to auth error", function()
    local err = errors.from_status(403, "", {})
    assert.equals("auth", err.type)
    assert.is_false(err.retryable)
  end)

  it("routes 429 to rate_limit error", function()
    local err = errors.from_status(429, "", {})
    assert.equals("rate_limit", err.type)
    assert.is_true(err.retryable)
  end)

  it("routes 500 to http error with retryable=true", function()
    local err = errors.from_status(500, "", {})
    assert.equals("http", err.type)
    assert.is_true(err.retryable)
    assert.equals(500, err.status)
  end)

  it("routes 404 to http error with retryable=false", function()
    local err = errors.from_status(404, "", {})
    assert.equals("http", err.type)
    assert.is_false(err.retryable)
    assert.equals(404, err.status)
  end)
end)

describe("errors.rate_limit", function()
  it("extracts Retry-After header", function()
    local err = errors.rate_limit(429, "", { ["retry-after"] = "60" })
    assert.equals(60, err.retry_after)
    assert.is_true(err.retryable)
  end)

  it("retry_after is nil when header is absent", function()
    local err = errors.rate_limit(429, "", {})
    assert.is_nil(err.retry_after)
  end)
end)

describe("errors.http", function()
  it("extracts ADO message from JSON body", function()
    local body = '{"message": "Project not found", "typeKey": "ProjectDoesNotExist"}'
    local err = errors.http(404, body, {})
    assert.equals("Project not found", err.message)
    assert.equals("ProjectDoesNotExist", err.code)
  end)

  it("falls back to plain text body when not JSON", function()
    local err = errors.http(503, "Service Unavailable", {})
    assert.equals("Service Unavailable", err.message)
    assert.is_true(err.retryable)
  end)

  it("extracts request-id from headers", function()
    local err = errors.http(500, "", { ["x-msrequestid"] = "req-abc" })
    assert.equals("req-abc", err.request_id)
  end)
end)

describe("errors.transport", function()
  it("is retryable", function()
    local err = errors.transport(7, "could not connect")
    assert.equals("transport", err.type)
    assert.is_true(err.retryable)
  end)

  it("includes exit code in code field", function()
    local err = errors.transport(28, "timeout")
    assert.equals("28", err.code)
  end)
end)

describe("errors.parse", function()
  it("is not retryable", function()
    local err = errors.parse("not json", "unexpected char")
    assert.equals("parse", err.type)
    assert.is_false(err.retryable)
  end)

  it("stores raw body", function()
    local err = errors.parse("some body", "oops")
    assert.equals("some body", err.raw)
  end)
end)

describe("all error types have required fields", function()
  local all_errors = {
    errors.http(500, "", {}),
    errors.auth(401, "", {}),
    errors.rate_limit(429, "", {}),
    errors.transport(nil, "oops"),
    errors.parse("body", "err"),
  }

  for _, err in ipairs(all_errors) do
    it("has type, message, retryable for " .. tostring(err.type), function()
      assert.is_string(err.type)
      assert.is_string(err.message)
      assert.is_boolean(err.retryable)
    end)
  end
end)
