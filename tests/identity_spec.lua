--- tests/identity_spec.lua — unit tests for api/identity.lua

local identity_factory = require("ado.api.identity")

local function make_client(override_fn)
  local c = {
    config = {
      api_version = "7.0",
      base_url    = "https://dev.azure.com/myorg",
      vssps_url   = "https://vssps.dev.azure.com/myorg",
    },
    _last_req = nil,
  }
  c.request = function(self, req, opts)
    self._last_req = req
    if override_fn then return override_fn(req, opts) end
    return { data = { value = {} }, status = 200, headers = {}, continuation_token = nil, etag = nil }, nil
  end
  return c
end

describe("identity:search", function()
  it("uses vssps_url as base_url override (not base_url)", function()
    local c = make_client()
    local m = identity_factory(c)
    m:search("alice")
    -- The req_spec base_url must be the vssps_url
    assert.equals(c.config.vssps_url, c._last_req.base_url)
    -- It must NOT be the regular base_url
    assert.not_equals(c.config.base_url, c._last_req.base_url)
  end)

  it("sends GET /_apis/identities", function()
    local c = make_client()
    local m = identity_factory(c)
    m:search("bob")
    assert.equals("GET",              c._last_req.method)
    assert.equals("/_apis/identities", c._last_req.path)
  end)

  it("sets correct default query params", function()
    local c = make_client()
    local m = identity_factory(c)
    m:search("alice@example.com")
    local params = c._last_req.params
    assert.equals("General",            params.searchFilter)
    assert.equals("alice@example.com",  params.filterValue)
    assert.equals("None",               params.queryMembership)
  end)

  it("pins api-version to 7.0 in params", function()
    local c = make_client()
    local m = identity_factory(c)
    m:search("x")
    assert.equals("7.0", c._last_req.params["api-version"])
  end)

  it("allows param overrides", function()
    local c = make_client()
    local m = identity_factory(c)
    m:search("x", { queryMembership = "Direct" })
    assert.equals("Direct", c._last_req.params.queryMembership)
  end)
end)
