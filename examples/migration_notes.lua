--- examples/migration_notes.lua
-- Function-by-function migration guide from the plugin's embedded SDK
-- (much-ADO-about-nvim/lua/ado/sdk/) to this standalone SDK.
--
-- Old API used a connection object with domain sub-APIs accessed via getter methods.
-- New API uses a flat client with domain modules as direct properties.
--
-- Key behavioral differences:
--   Old:  callback(err, result) convention
--   New:  result, err return values (errors are second return, nil on success)
--
--   Old:  async-only (always callback)
--   New:  sync by default; async via opts.callback

--[[
=============================================================================
MIGRATION TABLE
=============================================================================

| Old (plugin embedded SDK)                                          | New (ado SDK)                                                |
|--------------------------------------------------------------------|--------------------------------------------------------------|
| sdk.new(org_url, sdk.auth.pat(pat))                                | ado.new({ base_url=org_url, auth=ado.auth.pat(pat) })        |
| conn:get_core_api():get_projects(cb)                               | client.projects:list()                                       |
| conn:get_core_api():get_project(id, cb)                            | client.projects:get(id)                                      |
| conn:get_core_api():get_teams(proj, {mine=true}, cb)               | client.projects:list_teams(proj, {["$mine"]=true})           |
| conn:get_core_api():get_team_members(proj, tid, cb)                | client.projects:list_team_members(proj, tid)                 |
| conn:get_work_item_tracking_api():query_by_wiql(q, proj, cb)       | client.work_items:run_wiql(q, {project=proj})                |
| conn:get_work_item_tracking_api():get_work_items(ids, proj, cb)    | client.work_items:get_batch(ids, {project=proj})             |
| conn:get_work_item_tracking_api():get_work_item(id, proj, cb)      | client.work_items:get(id, {project=proj})                    |
| conn:get_work_item_tracking_api():update_work_item(id, proj, p, cb)| client.work_items:update(id, patch, {project=proj})          |
| conn:get_work_item_tracking_api():get_work_item_type(n, proj, cb)  | client.work_items:get_type(n, {project=proj})                |
| conn:get_work_item_tracking_api():get_work_item_type_states(n,p,cb)| client.work_items:get_type_states(n, {project=proj})         |
| conn:get_identity_api():search(q, cb)                              | client.identity:search(q)                                    |

=============================================================================
CALLBACK ADAPTER PATTERN
=============================================================================

If the plugin still needs a callback-style interface during transition,
wrap the sync calls:

  local function with_callback(fn_result_fn, cb)
    -- fn_result_fn is a function that returns res, err
    local res, err = fn_result_fn()
    if err then
      cb(err, nil)
    else
      cb(nil, res)
    end
  end

  -- Usage:
  with_callback(
    function() return client.projects:list() end,
    function(err, res) ... end
  )

Or use the native async path (Neovim transport):

  local async_client = ado.new({
    base_url  = org_url,
    auth      = ado.auth.pat(pat),
    transport = "vim",
  })

  async_client.projects:list(nil, {
    callback = function(res, err)
      -- callback(err, result) ordering from old SDK is REVERSED here:
      -- new SDK uses callback(result, err)
      if err then ... end
      local projects = res.data.value
    end
  })

=============================================================================
INIT CHANGE
=============================================================================

OLD:
  local sdk = require("ado.sdk")
  local conn, err = sdk.new("https://dev.azure.com/myorg", sdk.auth.pat(pat_token))

NEW:
  local ado = require("ado")
  local client, err = ado.new({
    base_url = "https://dev.azure.com/myorg",
    auth     = ado.auth.pat(pat_token),
  })

=============================================================================
PATCH FORMAT CHANGE
=============================================================================

OLD:  patch was sent as a plain table merged with work item fields
NEW:  patch must be a JSON Patch operations array:

  local patch = {
    { op = "add", path = "/fields/System.Title", value = "Updated Title" },
    { op = "add", path = "/fields/System.State", value = "Resolved" },
  }
  client.work_items:update(work_item_id, patch, { project = project })

=============================================================================
VSSPS / IDENTITY URL
=============================================================================

The identity API was previously accessed via the same base URL.
The SDK now automatically routes identity:search() to the correct
vssps.dev.azure.com endpoint. No manual URL construction needed.

]]

-- This file is documentation-only; no executable code.
