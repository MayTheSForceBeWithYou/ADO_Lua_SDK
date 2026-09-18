--- tests/http/request_spec.lua — unit tests for http/request.lua

local request = require("ado.http.request")

local function config(override)
  local c = {
    base_url    = "https://dev.azure.com/myorg",
    vssps_url   = "https://vssps.dev.azure.com/myorg",
    api_version = "7.0",
    timeout     = 30000,
  }
  for k, v in pairs(override or {}) do c[k] = v end
  return c
end

describe("request.build url", function()
  it("joins base_url and path", function()
    local req = request.build(config(), { path = "/_apis/projects" })
    assert.truthy(req.url:match("^https://dev%.azure%.com/myorg/_apis/projects%?"))
  end)

  it("builds project-scoped paths", function()
    local req = request.build(config(), { path = "/MyProject/_apis/wit/wiql" })
    assert.truthy(req.url:match("/myorg/MyProject/_apis/wit/wiql%?"))
  end)

  it("percent-encodes path segments but keeps separators", function()
    local req = request.build(config(), { path = "/My Project/_apis/wit/wiql" })
    assert.truthy(req.url:match("/My%%20Project/_apis/wit/wiql"))
  end)

  it("uses base_url override for org-level endpoints like vssps", function()
    local c = config()
    local req = request.build(c, { path = "/_apis/identities", base_url = c.vssps_url })
    assert.truthy(req.url:match("^https://vssps%.dev%.azure%.com/myorg/_apis/identities"))
  end)

  it("strips CR/LF from the url", function()
    local req = request.build(config({ base_url = "https://dev.azure.com/myorg\r\n" }), {
      path = "/_apis/projects",
    })
    assert.is_nil(req.url:find("[\r\n]"))
  end)
end)

describe("request.build query", function()
  it("always includes api-version", function()
    local req = request.build(config(), { path = "/_apis/projects" })
    assert.truthy(req.url:match("api%-version=7%.0"))
  end)

  it("uses the configured api-version", function()
    local req = request.build(config({ api_version = "7.1" }), { path = "/_apis/projects" })
    assert.truthy(req.url:match("api%-version=7%.1"))
  end)

  it("lets params override api-version for preview endpoints", function()
    local req = request.build(config(), {
      path   = "/_apis/wit/workItems/1/comments",
      params = { ["api-version"] = "7.0-preview.3" },
    })
    assert.truthy(req.url:match("api%-version=7%.0%-preview%.3"))
  end)

  it("appends additional params", function()
    local req = request.build(config(), {
      path   = "/_apis/wit/workitems",
      params = { ids = "1,2,3", ["$expand"] = "all" },
    })
    assert.truthy(req.url:match("ids=1%%2C2%%2C3"))
    assert.truthy(req.url:match("%%24expand=all"))
  end)

  it("percent-encodes param values", function()
    local req = request.build(config(), { path = "/_apis/x", params = { q = "hello world" } })
    assert.truthy(req.url:match("q=hello%%20world"))
  end)
end)

describe("request.build method and headers", function()
  it("defaults to GET", function()
    local req = request.build(config(), { path = "/_apis/projects" })
    assert.equals("GET", req.method)
  end)

  it("upper-cases the method", function()
    local req = request.build(config(), { method = "patch", path = "/_apis/x" })
    assert.equals("PATCH", req.method)
  end)

  it("sets JSON Accept and Content-Type by default", function()
    local req = request.build(config(), { path = "/_apis/projects" })
    assert.equals("application/json", req.headers["Accept"])
    assert.equals("application/json", req.headers["Content-Type"])
  end)

  it("applies per-request header overrides (JSON Patch)", function()
    local req = request.build(config(), {
      method  = "PATCH",
      path    = "/_apis/wit/workitems/1",
      headers = { ["Content-Type"] = "application/json-patch+json" },
    })
    assert.equals("application/json-patch+json", req.headers["Content-Type"])
    assert.equals("application/json", req.headers["Accept"])
  end)

  it("does not set an Authorization header (the pipeline injects it)", function()
    local req = request.build(config(), { path = "/_apis/projects" })
    assert.is_nil(req.headers["Authorization"])
  end)
end)

describe("request.build body", function()
  it("is nil when no body is given", function()
    local req = request.build(config(), { path = "/_apis/projects" })
    assert.is_nil(req.body_string)
  end)

  it("JSON-encodes table bodies", function()
    local req = request.build(config(), {
      method = "POST",
      path   = "/_apis/wit/wiql",
      body   = { query = "SELECT [System.Id] FROM WorkItems" },
    })
    assert.truthy(req.body_string:match("System.Id"))
  end)

  it("passes string bodies through unchanged", function()
    local req = request.build(config(), { method = "POST", path = "/x", body = '{"a":1}' })
    assert.equals('{"a":1}', req.body_string)
  end)
end)

describe("request.build timeout", function()
  it("falls back to the config timeout", function()
    local req = request.build(config({ timeout = 5000 }), { path = "/x" })
    assert.equals(5000, req.timeout)
  end)

  it("prefers the per-request timeout", function()
    local req = request.build(config({ timeout = 5000 }), { path = "/x", timeout = 1000 })
    assert.equals(1000, req.timeout)
  end)

  it("defaults to 30000 ms", function()
    local req = request.build({ base_url = "https://example.com" }, { path = "/x" })
    assert.equals(30000, req.timeout)
  end)
end)
