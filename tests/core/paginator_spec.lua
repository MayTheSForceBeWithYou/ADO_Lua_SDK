--- tests/core/paginator_spec.lua — unit tests for core/paginator.lua

local paginator = require("ado.core.paginator")

--- Helper: build a mock fetch_fn that returns pages from a list.
-- Each page entry: { items = {...}, token = "next"|nil }
local function make_fetcher(pages)
  local call = 0
  return function(_token)
    call = call + 1
    local page = pages[call]
    if not page then
      return nil, { type = "http", message = "unexpected extra call", retryable = false }
    end
    return {
      data               = { value = page.items },
      status             = 200,
      headers            = {},
      continuation_token = page.token,
      etag               = nil,
    }, nil
  end
end

describe("paginator.collect", function()
  it("collects a single page with no continuation token", function()
    local fetch = make_fetcher({
      { items = { "a", "b", "c" }, token = nil },
    })
    local res, err = paginator.collect(fetch)
    assert.is_nil(err)
    assert.is_not_nil(res)
    assert.same({ "a", "b", "c" }, res.data.value)
  end)

  it("collects multiple pages into one result", function()
    local fetch = make_fetcher({
      { items = { 1, 2 }, token = "tok1" },
      { items = { 3, 4 }, token = "tok2" },
      { items = { 5 },    token = nil    },
    })
    local res, err = paginator.collect(fetch)
    assert.is_nil(err)
    assert.same({ 1, 2, 3, 4, 5 }, res.data.value)
  end)

  it("propagates error from fetch_fn on first call", function()
    local fetch = function(_)
      return nil, { type = "transport", message = "network failure", retryable = true }
    end
    local res, err = paginator.collect(fetch)
    assert.is_nil(res)
    assert.equals("transport", err.type)
  end)

  it("propagates error from fetch_fn on subsequent call", function()
    local call = 0
    local fetch = function(_)
      call = call + 1
      if call == 1 then
        return { data = { value = { 1 } }, continuation_token = "next" }, nil
      else
        return nil, { type = "http", message = "server error", retryable = false }
      end
    end
    local res, err = paginator.collect(fetch)
    assert.is_nil(res)
    assert.equals("http", err.type)
  end)

  it("respects max_pages guard", function()
    -- Always returns a continuation token → infinite loop guard
    local fetch = function(_)
      return {
        data               = { value = { "x" } },
        continuation_token = "always",
        status             = 200, headers = {},
      }, nil
    end
    local res, err = paginator.collect(fetch, { max_pages = 3 })
    assert.is_nil(res)
    assert.is_not_nil(err)
    assert.truthy(err.message:match("max_pages"))
  end)

  it("supports custom data_key", function()
    local fetch = function(_)
      return {
        data               = { items = { "p", "q" } },
        continuation_token = nil,
        status             = 200, headers = {},
      }, nil
    end
    local res, err = paginator.collect(fetch, { data_key = "items" })
    assert.is_nil(err)
    assert.same({ "p", "q" }, res.data.items)
  end)
end)
