--- tests/core/pipeline_spec.lua — end-to-end tests through the request pipeline
-- Builds a real client and swaps in a fake transport, so every step runs:
-- request build → auth injection → transport → response normalize.

local ado = require("ado")
local util = require("ado.core.util")

--- Create a client whose transport replays a canned response.
-- @param raw table|nil  { status, headers, body } returned to the pipeline
-- @param err table|nil  transport error returned instead of raw
-- @return client, sent (table populated with the last request)
local function make_client(raw, err)
  local client = ado.new({
    base_url = "https://dev.azure.com/testorg",
    auth     = ado.auth.pat("test-pat"),
    retry    = { max_attempts = 1 },
  })
  local sent = {}
  client.transport = {
    send = function(_, req, opts)
      sent.req = req
      if opts and opts.callback then
        opts.callback(raw, err)
        return nil, nil
      end
      return raw, err
    end,
  }
  return client, sent
end

--- Build a JSON response body with a 200 status.
local function ok_body(value)
  return { status = 200, headers = {}, body = (util.json_encode(value)) }
end

describe("pipeline: successful request", function()
  it("decodes the response body into res.data", function()
    local client = make_client(ok_body({
      count = 2,
      value = {
        { id = "guid-1", name = "Project1", state = "wellFormed" },
        { id = "guid-2", name = "Project2", state = "wellFormed" },
      },
    }))
    local res, err = client.projects:list()
    assert.is_nil(err)
    assert.equals(200, res.status)
    assert.equals(2, #res.data.value)
    assert.equals("Project1", res.data.value[1].name)
  end)

  it("injects the Authorization header from the auth provider", function()
    local client, sent = make_client(ok_body({ value = {} }))
    client.projects:list()
    assert.equals("Basic " .. util.base64(":test-pat"), sent.req.headers["Authorization"])
  end)

  it("sends the method, path and api-version the endpoint declares", function()
    local client, sent = make_client(ok_body({ value = {} }))
    client.projects:list()
    assert.equals("GET", sent.req.method)
    assert.truthy(sent.req.url:match("_apis/projects"))
    assert.truthy(sent.req.url:match("api%-version=7%.0"))
  end)

  it("delivers the result through opts.callback in async mode", function()
    local client = make_client(ok_body({ value = { { name = "P" } } }))
    local got_res, got_err
    client.projects:list({}, {
      callback = function(res, err)
        got_res, got_err = res, err
      end,
    })
    assert.is_nil(got_err)
    assert.equals("P", got_res.data.value[1].name)
  end)

  it("returns nil data for an empty body (204 No Content)", function()
    local client = make_client({ status = 204, headers = {}, body = "" })
    local res, err = client.projects:list()
    assert.is_nil(err)
    assert.is_nil(res.data)
  end)
end)

describe("pipeline: WIQL round-trip", function()
  it("posts the query and returns work item refs", function()
    local client, sent = make_client(ok_body({
      workItems = { { id = 1, url = "https://…" }, { id = 2, url = "https://…" } },
    }))
    local res, err = client.work_items:run_wiql(
      "SELECT [System.Id] FROM WorkItems",
      { project = "MyProject" }
    )
    assert.is_nil(err)
    assert.equals("POST", sent.req.method)
    assert.truthy(sent.req.body_string:match("System.Id"))
    assert.equals(2, #res.data.workItems)
    assert.equals(1, res.data.workItems[1].id)
  end)

  it("fetches work items by ID batch", function()
    local client, sent = make_client(ok_body({
      count = 2,
      value = {
        { id = 1, rev = 1, fields = { ["System.Title"] = "Item 1" } },
        { id = 2, rev = 3, fields = { ["System.Title"] = "Item 2" } },
      },
    }))
    local res, err = client.work_items:get_batch({ 1, 2 }, { project = "MyProject" })
    assert.is_nil(err)
    assert.truthy(sent.req.url:match("ids=1%%2C2"))
    assert.equals("Item 1", res.data.value[1].fields["System.Title"])
  end)

  it("sends JSON Patch updates with the patch content type", function()
    local client, sent = make_client(ok_body({ id = 10 }))
    local patch = { { op = "add", path = "/fields/System.State", value = "Done" } }
    client.work_items:update(10, patch, { project = "MyProject" })
    assert.equals("PATCH", sent.req.method)
    assert.equals("application/json-patch+json", sent.req.headers["Content-Type"])
    assert.truthy(sent.req.body_string:match("System.State"))
  end)
end)

describe("pipeline: error responses", function()
  it("maps 401 to an auth error carrying the API message", function()
    local client = make_client({
      status  = 401,
      headers = {},
      body    = '{"message":"Unauthorized"}',
    })
    local res, err = client.projects:list()
    assert.is_nil(res)
    assert.equals("auth", err.type)
    assert.equals(401, err.status)
    assert.equals("Unauthorized", err.message)
    assert.is_false(err.retryable)
  end)

  it("maps 404 to a non-retryable http error", function()
    local client = make_client({ status = 404, headers = {}, body = "" })
    local _, err = client.projects:get("missing")
    assert.equals("http", err.type)
    assert.equals(404, err.status)
    assert.is_false(err.retryable)
  end)

  it("maps 429 to a rate_limit error with retry_after", function()
    local client = make_client({ status = 429, headers = { ["retry-after"] = "30" }, body = "" })
    local _, err = client.projects:list()
    assert.equals("rate_limit", err.type)
    assert.equals(30, err.retry_after)
  end)

  it("propagates transport failures", function()
    local errors = require("ado.core.errors")
    local client = make_client(nil, errors.transport(6, "Could not resolve host: bad.example.com"))
    local res, err = client.projects:list()
    assert.is_nil(res)
    assert.equals("transport", err.type)
    assert.truthy(err.message:match("resolve host"))
  end)

  it("returns a parse error for a non-JSON body", function()
    local client = make_client({ status = 200, headers = {}, body = "<html>nope</html>" })
    local res, err = client.projects:list()
    assert.is_nil(res)
    assert.equals("parse", err.type)
    assert.equals("<html>nope</html>", err.raw)
  end)

  it("reports errors through opts.callback in async mode", function()
    local client = make_client({ status = 403, headers = {}, body = "" })
    local got_err
    client.projects:list({}, {
      callback = function(_, err)
        got_err = err
      end,
    })
    assert.equals("auth", got_err.type)
    assert.equals(403, got_err.status)
  end)
end)

describe("pipeline: response metadata", function()
  it("exposes the continuation token for paging", function()
    local client = make_client({
      status  = 200,
      headers = { ["x-ms-continuationtoken"] = "token-2" },
      body    = '{"value":[]}',
    })
    local res = client.projects:list()
    assert.equals("token-2", res.continuation_token)
  end)

  it("exposes the ETag and lower-cases header keys", function()
    local client = make_client({
      status  = 200,
      headers = { ["ETag"] = 'W/"abc"' },
      body    = '{"value":[]}',
    })
    local res = client.projects:list()
    assert.equals('W/"abc"', res.etag)
    assert.equals('W/"abc"', res.headers["etag"])
  end)
end)
