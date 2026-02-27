--- tests/projects_spec.lua — unit tests for api/projects.lua

local projects_factory = require("ado.api.projects")

--- Fake client that captures requests and returns a canned response.
local function make_client(override_fn)
  local c = {
    config   = {
      api_version = "7.0",
      base_url    = "https://dev.azure.com/myorg",
      vssps_url   = "https://vssps.dev.azure.com/myorg",
    },
    _last_req  = nil,
    _last_opts = nil,
  }
  c.request = function(self, req, opts)
    self._last_req  = req
    self._last_opts = opts
    if override_fn then return override_fn(req, opts) end
    return { data = { value = {} }, status = 200, headers = {}, continuation_token = nil, etag = nil }, nil
  end
  return c
end

describe("projects:list", function()
  it("sends GET /_apis/projects", function()
    local c = make_client()
    local m = projects_factory(c)
    m:list()
    assert.equals("GET",             c._last_req.method)
    assert.equals("/_apis/projects", c._last_req.path)
  end)

  it("passes params to request", function()
    local c = make_client()
    local m = projects_factory(c)
    m:list({ stateFilter = "wellFormed" })
    assert.equals("wellFormed", c._last_req.params.stateFilter)
  end)

  it("returns res on success", function()
    local c = make_client()
    local m = projects_factory(c)
    local res, err = m:list()
    assert.is_nil(err)
    assert.equals(200, res.status)
  end)
end)

describe("projects:get", function()
  it("sends GET /_apis/projects/{id} with includeCapabilities=true", function()
    local c = make_client()
    local m = projects_factory(c)
    m:get("proj-123")
    assert.equals("GET", c._last_req.method)
    assert.equals("/_apis/projects/proj-123", c._last_req.path)
    assert.equals("true", c._last_req.params.includeCapabilities)
  end)

  it("merges extra params while preserving includeCapabilities", function()
    local c = make_client()
    local m = projects_factory(c)
    m:get("p", { extraParam = "x" })
    assert.equals("true", c._last_req.params.includeCapabilities)
    assert.equals("x",    c._last_req.params.extraParam)
  end)
end)

describe("projects:list_teams", function()
  it("sends GET /_apis/projects/{project}/teams", function()
    local c = make_client()
    local m = projects_factory(c)
    m:list_teams("MyProject")
    assert.equals("/_apis/projects/MyProject/teams", c._last_req.path)
  end)

  it("passes $mine param", function()
    local c = make_client()
    local m = projects_factory(c)
    m:list_teams("MyProject", { ["$mine"] = true })
    assert.is_true(c._last_req.params["$mine"])
  end)
end)

describe("projects:list_team_members", function()
  it("sends GET /_apis/projects/{project}/teams/{team_id}/members", function()
    local c = make_client()
    local m = projects_factory(c)
    m:list_team_members("MyProject", "team-abc")
    assert.equals("/_apis/projects/MyProject/teams/team-abc/members", c._last_req.path)
    assert.equals("GET", c._last_req.method)
  end)
end)
