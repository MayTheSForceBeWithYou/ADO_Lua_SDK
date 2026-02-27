--- tests/work_items_spec.lua — unit tests for api/work_items.lua

local wi_factory = require("ado.api.work_items")

local function make_client(override_fn)
  local c = {
    config   = {
      api_version = "7.0",
      base_url    = "https://dev.azure.com/myorg",
      vssps_url   = "https://vssps.dev.azure.com/myorg",
    },
    _last_req = nil,
  }
  c.request = function(self, req, opts)
    self._last_req = req
    if override_fn then return override_fn(req, opts) end
    return { data = {}, status = 200, headers = {}, continuation_token = nil, etag = nil }, nil
  end
  return c
end

describe("work_items:query_wiql", function()
  it("sends POST to /{project}/_apis/wit/wiql", function()
    local c = make_client()
    local m = wi_factory(c)
    m:query_wiql({ project = "TestProj" })
    assert.equals("POST", c._last_req.method)
    assert.equals("/TestProj/_apis/wit/wiql", c._last_req.path)
  end)

  it("includes project condition in WHERE clause", function()
    local c = make_client()
    local m = wi_factory(c)
    m:query_wiql({ project = "MyProj" })
    assert.truthy(c._last_req.body.query:match("System.TeamProject"))
    assert.truthy(c._last_req.body.query:match("MyProj"))
  end)

  it("includes area_path UNDER condition when specified", function()
    local c = make_client()
    local m = wi_factory(c)
    m:query_wiql({ project = "P", area_path = "P\\Team1" })
    assert.truthy(c._last_req.body.query:match("AreaPath.*UNDER"))
  end)

  it("includes states IN condition when specified", function()
    local c = make_client()
    local m = wi_factory(c)
    m:query_wiql({ project = "P", states = { "Active", "Resolved" } })
    local q = c._last_req.body.query
    assert.truthy(q:match("System.State.*IN"))
    assert.truthy(q:match("Active"))
    assert.truthy(q:match("Resolved"))
  end)

  it("includes work item type IN condition when specified", function()
    local c = make_client()
    local m = wi_factory(c)
    m:query_wiql({ project = "P", types = { "Bug", "Task" } })
    local q = c._last_req.body.query
    assert.truthy(q:match("WorkItemType.*IN"))
    assert.truthy(q:match("Bug"))
  end)

  it("returns nil + err when project is missing", function()
    local c = make_client()
    local m = wi_factory(c)
    local res, err = m:query_wiql({})
    assert.is_nil(res)
    assert.is_not_nil(err)
    assert.truthy(err.message:match("project"))
  end)

  it("passes $top param", function()
    local c = make_client()
    local m = wi_factory(c)
    m:query_wiql({ project = "P", limit = 50 })
    assert.equals(50, c._last_req.params["$top"])
  end)
end)

describe("work_items:run_wiql", function()
  it("sends the raw WIQL string as body.query", function()
    local c = make_client()
    local m = wi_factory(c)
    local raw = "SELECT [System.Id] FROM WorkItems"
    m:run_wiql(raw, { project = "P" })
    assert.equals(raw, c._last_req.body.query)
  end)

  it("returns nil + err when project is missing", function()
    local c = make_client()
    local m = wi_factory(c)
    local _, err = m:run_wiql("SELECT ...", {})
    assert.is_not_nil(err)
  end)
end)

describe("work_items:get", function()
  it("sends GET /{project}/_apis/wit/workitems/{id}", function()
    local c = make_client()
    local m = wi_factory(c)
    m:get(42, { project = "P" })
    assert.equals("GET", c._last_req.method)
    assert.equals("/P/_apis/wit/workitems/42", c._last_req.path)
  end)

  it("returns nil + err when project is absent", function()
    local c = make_client()
    local m = wi_factory(c)
    local _, err = m:get(1, {})
    assert.is_not_nil(err)
    assert.truthy(err.message:match("project"))
  end)
end)

describe("work_items:get_batch", function()
  it("joins ids as comma-separated query param", function()
    local c = make_client()
    local m = wi_factory(c)
    m:get_batch({ 1, 2, 3 }, { project = "P" })
    assert.equals("1,2,3", c._last_req.params.ids)
  end)

  it("sends GET /{project}/_apis/wit/workitems", function()
    local c = make_client()
    local m = wi_factory(c)
    m:get_batch({ 5 }, { project = "P" })
    assert.equals("/P/_apis/wit/workitems", c._last_req.path)
  end)

  it("returns nil + err for empty ids table", function()
    local c = make_client()
    local m = wi_factory(c)
    local _, err = m:get_batch({}, { project = "P" })
    assert.is_not_nil(err)
  end)
end)

describe("work_items:update", function()
  it("sends PATCH /{project}/_apis/wit/workitems/{id}", function()
    local c = make_client()
    local m = wi_factory(c)
    local patch = { { op = "add", path = "/fields/System.Title", value = "New" } }
    m:update(10, patch, { project = "P" })
    assert.equals("PATCH", c._last_req.method)
    assert.equals("/P/_apis/wit/workitems/10", c._last_req.path)
  end)

  it("sets Content-Type to application/json-patch+json", function()
    local c = make_client()
    local m = wi_factory(c)
    m:update(1, {}, { project = "P" })
    assert.equals("application/json-patch+json", c._last_req.headers["Content-Type"])
  end)

  it("sends the patch as the body", function()
    local c = make_client()
    local m = wi_factory(c)
    local patch = { { op = "add", path = "/fields/System.Title", value = "X" } }
    m:update(1, patch, { project = "P" })
    assert.same(patch, c._last_req.body)
  end)
end)

describe("work_items:get_type", function()
  it("sends GET /{project}/_apis/wit/workitemtypes/{name}", function()
    local c = make_client()
    local m = wi_factory(c)
    m:get_type("Bug", { project = "P" })
    assert.equals("/P/_apis/wit/workitemtypes/Bug", c._last_req.path)
  end)
end)

describe("work_items:get_type_states", function()
  it("sends GET /{project}/_apis/wit/workitemtypes/{name}/states", function()
    local c = make_client()
    local m = wi_factory(c)
    m:get_type_states("Bug", { project = "P" })
    assert.equals("/P/_apis/wit/workitemtypes/Bug/states", c._last_req.path)
  end)
end)
