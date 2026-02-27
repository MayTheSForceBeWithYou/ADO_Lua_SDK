--- tests/client_spec.lua — integration-level tests for ado.new + client shape

local ado = require("ado")

describe("ado.new", function()
  local pat, pat_err = ado.auth.pat("valid-test-token")
  assert(pat, "test setup: pat creation failed: " .. tostring(pat_err))

  it("returns a client with domain modules attached", function()
    local client, err = ado.new({
      base_url = "https://dev.azure.com/myorg",
      auth     = pat,
    })
    assert.is_nil(err)
    assert.is_not_nil(client)
    assert.is_not_nil(client.projects)
    assert.is_not_nil(client.work_items)
    assert.is_not_nil(client.identity)
  end)

  it("attaches domain modules with correct method signatures", function()
    local client = ado.new({
      base_url = "https://dev.azure.com/myorg",
      auth     = pat,
    })
    assert.is_function(client.projects.list)
    assert.is_function(client.projects.get)
    assert.is_function(client.projects.list_teams)
    assert.is_function(client.projects.list_team_members)
    assert.is_function(client.work_items.query_wiql)
    assert.is_function(client.work_items.run_wiql)
    assert.is_function(client.work_items.get)
    assert.is_function(client.work_items.get_batch)
    assert.is_function(client.work_items.update)
    assert.is_function(client.work_items.get_type)
    assert.is_function(client.work_items.get_type_states)
    assert.is_function(client.identity.search)
  end)

  it("returns nil + err when base_url is missing", function()
    local client, err = ado.new({ auth = pat })
    assert.is_nil(client)
    assert.is_not_nil(err)
    assert.truthy(err.message:match("base_url"))
  end)

  it("returns nil + err when auth is missing", function()
    local client, err = ado.new({ base_url = "https://dev.azure.com/myorg" })
    assert.is_nil(client)
    assert.is_not_nil(err)
    assert.truthy(err.message:match("auth"))
  end)

  it("derives vssps_url automatically from dev.azure.com base_url", function()
    local client = ado.new({
      base_url = "https://dev.azure.com/myorg",
      auth     = pat,
    })
    assert.equals("https://vssps.dev.azure.com/myorg", client.config.vssps_url)
  end)

  it("trims trailing slash from base_url", function()
    local client = ado.new({
      base_url = "https://dev.azure.com/myorg/",
      auth     = pat,
    })
    assert.equals("https://dev.azure.com/myorg", client.config.base_url)
  end)

  it("uses provided api_version", function()
    local client = ado.new({
      base_url    = "https://dev.azure.com/myorg",
      auth        = pat,
      api_version = "6.0",
    })
    assert.equals("6.0", client.config.api_version)
  end)
end)

describe("ado.auth.pat", function()
  it("returns nil + err for empty PAT", function()
    local p, err = ado.auth.pat("")
    assert.is_nil(p)
    assert.is_not_nil(err)
    assert.equals("auth", err.type)
  end)
end)

describe("ado.paginator", function()
  it("exposes collect function", function()
    assert.is_function(ado.paginator.collect)
  end)
end)
