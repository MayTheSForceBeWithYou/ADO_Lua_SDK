--- tests/smoke_test.lua — integration smoke tests (live ADO required)
--
-- Run with:
--   ADO_INTEGRATION_TEST=1 ADO_PAT=xxx ADO_ORG_URL=https://dev.azure.com/myorg \
--     busted tests/smoke_test.lua
--
-- Skips all tests when ADO_INTEGRATION_TEST env var is not set.

local ado = require("ado")

local ENABLED   = os.getenv("ADO_INTEGRATION_TEST") == "1"
local PAT       = os.getenv("ADO_PAT") or ""
local ORG_URL   = os.getenv("ADO_ORG_URL") or ""
local PROJECT   = os.getenv("ADO_PROJECT") or ""  -- optional; some tests require it

local function skip_unless_enabled()
  if not ENABLED then
    pending("set ADO_INTEGRATION_TEST=1 to run integration tests")
  end
end

describe("smoke: ado.new", function()
  it("creates a client with valid credentials", function()
    skip_unless_enabled()
    local client, err = ado.new({
      base_url = ORG_URL,
      auth     = ado.auth.pat(PAT),
    })
    assert.is_nil(err)
    assert.is_not_nil(client)
  end)

  it("returns auth error with invalid PAT", function()
    skip_unless_enabled()
    local client, _ = ado.new({
      base_url = ORG_URL,
      auth     = ado.auth.pat("invalid-pat-token"),
    })
    -- Client creates fine; error comes on first request
    local res, err = client.projects:list()
    assert.is_nil(res)
    assert.is_not_nil(err)
    assert.equals("auth", err.type)
  end)
end)

describe("smoke: projects:list", function()
  it("returns a list of projects", function()
    skip_unless_enabled()
    local client = ado.new({ base_url = ORG_URL, auth = ado.auth.pat(PAT) })
    local res, err = client.projects:list()
    assert.is_nil(err)
    assert.is_not_nil(res)
    assert.is_not_nil(res.data)
    assert.is_not_nil(res.data.value)
    assert.truthy(#res.data.value >= 0)
  end)
end)

describe("smoke: work_items WIQL + get_batch round-trip", function()
  it("queries work items and fetches them by ID", function()
    skip_unless_enabled()
    if PROJECT == "" then
      pending("set ADO_PROJECT to run this test")
    end

    local client = ado.new({ base_url = ORG_URL, auth = ado.auth.pat(PAT) })

    -- Query top 5 work items
    local res, err = client.work_items:query_wiql({
      project = PROJECT,
      limit   = 5,
    })
    assert.is_nil(err)
    assert.is_not_nil(res)

    local wi_refs = res.data and res.data.workItems
    if not wi_refs or #wi_refs == 0 then
      pending("no work items found in project " .. PROJECT)
    end

    -- Extract IDs from WIQL response
    local ids = {}
    for _, ref in ipairs(wi_refs) do
      ids[#ids + 1] = ref.id
    end

    -- Batch fetch
    local batch_res, batch_err = client.work_items:get_batch(ids, { project = PROJECT })
    assert.is_nil(batch_err)
    assert.is_not_nil(batch_res)
    assert.is_not_nil(batch_res.data)
    assert.equals(#ids, #(batch_res.data.value or {}))
  end)
end)

describe("smoke: paginator collects all projects", function()
  it("collects all projects using paginator", function()
    skip_unless_enabled()
    local client = ado.new({ base_url = ORG_URL, auth = ado.auth.pat(PAT) })

    local all, err = ado.paginator.collect(function(token)
      local params = token and { continuationToken = token } or {}
      return client.projects:list(params)
    end)

    assert.is_nil(err)
    assert.is_not_nil(all)
    assert.is_not_nil(all.data.value)
  end)
end)

describe("smoke: identity:search", function()
  it("returns identity results for a search query", function()
    skip_unless_enabled()
    local client = ado.new({ base_url = ORG_URL, auth = ado.auth.pat(PAT) })
    -- Search for something likely to exist (organization-level)
    local res, err = client.identity:search("azure")
    assert.is_nil(err)
    assert.is_not_nil(res)
  end)
end)
