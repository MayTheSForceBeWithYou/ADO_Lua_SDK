--- examples/plugin_integration.lua
-- Full SDK usage example showing how a Neovim plugin would integrate with the SDK.
-- Demonstrates: init, sync call, async callback, paginator, identity search.
--
-- Run (sync demo, no Neovim needed):
--   ADO_PAT=xxx ADO_ORG_URL=https://dev.azure.com/myorg luajit examples/plugin_integration.lua

local ado = require("ado")

-- ---------------------------------------------------------------------------
-- 1. Create a client
-- ---------------------------------------------------------------------------
local pat_token = os.getenv("ADO_PAT") or "your-pat-token-here"
local org_url   = os.getenv("ADO_ORG_URL") or "https://dev.azure.com/yourorg"
local project   = os.getenv("ADO_PROJECT") or "YourProject"

local auth, auth_err = ado.auth.pat(pat_token)
if not auth then
  io.stderr:write("Failed to create PAT auth: " .. tostring(auth_err.message) .. "\n")
  os.exit(1)
end

local client, client_err = ado.new({
  base_url    = org_url,
  auth        = auth,
  api_version = "7.0",
  timeout     = 30000,
  cache       = { enabled = true, ttl = 120 },
})
if not client then
  io.stderr:write("Failed to create client: " .. tostring(client_err.message) .. "\n")
  os.exit(1)
end

-- ---------------------------------------------------------------------------
-- 2. Synchronous: list projects
-- ---------------------------------------------------------------------------
print("=== Projects ===")
local projects_res, projects_err = client.projects:list()
if projects_err then
  io.stderr:write("projects:list error: " .. projects_err.message .. "\n")
else
  local items = projects_res.data and projects_res.data.value or {}
  for i, p in ipairs(items) do
    print(string.format("  %d. %s (%s)", i, p.name or "?", p.id or "?"))
    if i >= 5 then print("  (…)"); break end
  end
end

-- ---------------------------------------------------------------------------
-- 3. Paginate all projects using paginator.collect
-- ---------------------------------------------------------------------------
print("\n=== All projects via paginator ===")
local all_projects, pag_err = ado.paginator.collect(function(token)
  local params = token and { continuationToken = token } or {}
  return client.projects:list(params)
end)
if pag_err then
  io.stderr:write("paginator error: " .. pag_err.message .. "\n")
else
  local items = all_projects.data and all_projects.data.value or {}
  print(string.format("  Total projects: %d", #items))
end

-- ---------------------------------------------------------------------------
-- 4. Query work items with structured WIQL builder
-- ---------------------------------------------------------------------------
print("\n=== Recent active work items ===")
local wi_res, wi_err = client.work_items:query_wiql({
  project = project,
  states  = { "Active", "In Progress" },
  limit   = 10,
})
if wi_err then
  io.stderr:write("work_items:query_wiql error: " .. wi_err.message .. "\n")
else
  local refs = wi_res.data and wi_res.data.workItems or {}
  print(string.format("  Found %d work item references", #refs))

  -- Fetch full details for the first batch
  if #refs > 0 then
    local ids = {}
    for _, ref in ipairs(refs) do ids[#ids + 1] = ref.id end
    local batch, batch_err = client.work_items:get_batch(ids, { project = project })
    if batch_err then
      io.stderr:write("  get_batch error: " .. batch_err.message .. "\n")
    else
      local wis = batch.data and batch.data.value or {}
      for _, wi in ipairs(wis) do
        local f = wi.fields or {}
        print(string.format("  #%d: [%s] %s",
          wi.id or 0,
          f["System.State"] or "?",
          f["System.Title"] or "(no title)"))
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- 5. Identity search
-- ---------------------------------------------------------------------------
print("\n=== Identity search ===")
local id_res, id_err = client.identity:search("admin")
if id_err then
  io.stderr:write("identity:search error: " .. id_err.message .. "\n")
else
  local identities = id_res.data and id_res.data.value or {}
  print(string.format("  Found %d identities matching 'admin'", #identities))
  for i, id_item in ipairs(identities) do
    print(string.format("  %d. %s", i, id_item.providerDisplayName or id_item.subjectDescriptor or "?"))
    if i >= 3 then print("  (…)"); break end
  end
end

-- ---------------------------------------------------------------------------
-- 6. Async pattern (Neovim only — vim transport)
-- ---------------------------------------------------------------------------
--[[
-- In a Neovim plugin, use the callback pattern for non-blocking requests:

local async_client, _ = ado.new({
  base_url  = org_url,
  auth      = auth,
  transport = "vim",   -- uses vim.system for async curl
})

async_client.projects:list(nil, {
  callback = function(res, err)
    -- Called from Neovim's event loop after completion
    if err then
      vim.notify("Error: " .. err.message, vim.log.levels.ERROR)
      return
    end
    local projects = res.data.value
    -- Update UI here...
  end
})
-- Execution continues immediately; callback fires when curl completes.
--]]

print("\nDone.")
