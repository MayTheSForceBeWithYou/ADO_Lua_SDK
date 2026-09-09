--- api/work_items.lua — work item tracking endpoints
-- Factory: require("ado.api.work_items")(client) → module

return function(client)
  local M = {}

  -- -------------------------------------------------------------------------
  -- WIQL builder helpers
  -- -------------------------------------------------------------------------

  --- Escape a value for inclusion in a WIQL string literal.
  -- In WIQL, single quotes inside strings are escaped as ''.
  local function wiql_escape(s)
    return tostring(s):gsub("'", "''")
  end

  --- Build a WIQL SELECT/FROM/WHERE/ORDER query from structured params.
  -- @param params table
  --   params.project     string   required — filters [System.TeamProject]
  --   params.area_path   string   optional — filters [System.AreaPath] UNDER 'path'
  --   params.states      table    optional — list of state strings
  --   params.types       table    optional — list of work item type strings
  --   params.assigned_to string   optional — filters [System.AssignedTo]
  --   params.tags        string   optional — filters [System.Tags] CONTAINS 'tag'
  --   params.limit       number   optional — TOP N clause (default 200)
  --   params.fields      table    optional — list of field refs for SELECT
  -- @return string  WIQL query
  local function build_wiql(params)
    -- SELECT
    local fields = params.fields
    local select_fields
    if fields and #fields > 0 then
      select_fields = table.concat(fields, ", ")
    else
      select_fields = "[System.Id], [System.Title], [System.State], " ..
                      "[System.AssignedTo], [System.WorkItemType], [System.ChangedDate]"
    end

    local top = params.limit or 200
    local wiql = "SELECT " .. select_fields ..
                 " FROM WorkItems"

    -- WHERE clauses
    local conditions = {}

    if params.project then
      conditions[#conditions + 1] =
        "[System.TeamProject] = '" .. wiql_escape(params.project) .. "'"
    end

    if params.area_path then
      conditions[#conditions + 1] =
        "[System.AreaPath] UNDER '" .. wiql_escape(params.area_path) .. "'"
    end

    if params.states and #params.states > 0 then
      local quoted = {}
      for _, s in ipairs(params.states) do
        quoted[#quoted + 1] = "'" .. wiql_escape(s) .. "'"
      end
      conditions[#conditions + 1] =
        "[System.State] IN (" .. table.concat(quoted, ", ") .. ")"
    end

    if params.types and #params.types > 0 then
      local quoted = {}
      for _, t in ipairs(params.types) do
        quoted[#quoted + 1] = "'" .. wiql_escape(t) .. "'"
      end
      conditions[#conditions + 1] =
        "[System.WorkItemType] IN (" .. table.concat(quoted, ", ") .. ")"
    end

    if params.assigned_to then
      conditions[#conditions + 1] =
        "[System.AssignedTo] = '" .. wiql_escape(params.assigned_to) .. "'"
    end

    if params.tags then
      conditions[#conditions + 1] =
        "[System.Tags] CONTAINS '" .. wiql_escape(params.tags) .. "'"
    end

    if #conditions > 0 then
      wiql = wiql .. " WHERE " .. table.concat(conditions, " AND ")
    end

    wiql = wiql .. " ORDER BY [System.ChangedDate] DESC"

    -- Wrap in TOP if needed (WIQL uses $top query param, not in the query itself)
    -- The top param is passed separately via query params
    return wiql, top
  end

  -- -------------------------------------------------------------------------
  -- Public API
  -- -------------------------------------------------------------------------

  --- Execute a structured WIQL query built from params.
  -- POST /{project}/_apis/wit/wiql
  -- @param params table  see build_wiql above; params.project is required
  -- @param opts   table  pipeline options
  function M:query_wiql(params, opts)
    params = params or {}
    local project = params.project
    if not project then
      return nil, {
        type      = "http",
        message   = "work_items:query_wiql requires params.project",
        retryable = false,
      }
    end
    local wiql_str, top = build_wiql(params)
    return client:request({
      method = "POST",
      path   = "/" .. tostring(project) .. "/_apis/wit/wiql",
      params = { ["$top"] = top },
      body   = { query = wiql_str },
    }, opts)
  end

  --- Execute a raw WIQL string.
  -- POST /{project}/_apis/wit/wiql
  -- @param wiql_string string  raw WIQL query
  -- @param params      table   must contain params.project; optional $top
  -- @param opts        table
  function M:run_wiql(wiql_string, params, opts)
    params = params or {}
    local project = params.project
    if not project then
      return nil, {
        type      = "http",
        message   = "work_items:run_wiql requires params.project",
        retryable = false,
      }
    end
    local query_params = {}
    if params["$top"] then query_params["$top"] = params["$top"] end
    return client:request({
      method = "POST",
      path   = "/" .. tostring(project) .. "/_apis/wit/wiql",
      params = query_params,
      body   = { query = wiql_string },
    }, opts)
  end

  --- Get a single work item by ID.
  -- GET /{project}/_apis/wit/workitems/{id}
  -- @param id     number|string
  -- @param params table  optional (e.g. { fields = "...", ["$expand"] = "all" })
  -- @param opts   table  must contain opts.project or params.project
  function M:get(id, params, opts)
    params = params or {}
    opts   = opts or {}
    local project = params.project or opts.project or client.config.project
    if not project then
      return nil, {
        type      = "http",
        message   = "work_items:get requires project in params or opts",
        retryable = false,
      }
    end
    -- Remove project from query params (it's in the path)
    local query = {}
    for k, v in pairs(params) do
      if k ~= "project" then query[k] = v end
    end
    return client:request({
      method = "GET",
      path   = "/" .. tostring(project) .. "/_apis/wit/workitems/" .. tostring(id),
      params = query,
    }, opts)
  end

  --- Get multiple work items by ID list.
  -- GET /{project}/_apis/wit/workitems?ids=1,2,3
  -- @param ids    table  list of work item IDs e.g. {1, 2, 3}
  -- @param params table  optional additional params
  -- @param opts   table  must contain opts.project or params.project
  function M:get_batch(ids, params, opts)
    params = params or {}
    opts   = opts or {}
    local project = params.project or opts.project or client.config.project
    if not project then
      return nil, {
        type      = "http",
        message   = "work_items:get_batch requires project in params or opts",
        retryable = false,
      }
    end
    if not ids or #ids == 0 then
      return nil, {
        type      = "http",
        message   = "work_items:get_batch requires a non-empty ids table",
        retryable = false,
      }
    end

    local id_strs = {}
    for _, id in ipairs(ids) do id_strs[#id_strs + 1] = tostring(id) end
    local query = { ids = table.concat(id_strs, ",") }
    for k, v in pairs(params) do
      if k ~= "project" then query[k] = v end
    end

    return client:request({
      method = "GET",
      path   = "/" .. tostring(project) .. "/_apis/wit/workitems",
      params = query,
    }, opts)
  end

  --- Update a work item using JSON Patch operations.
  -- PATCH /{project}/_apis/wit/workitems/{id}
  -- @param id    number|string
  -- @param patch table  array of JSON Patch ops:
  --   { { op="add", path="/fields/System.Title", value="New title" }, ... }
  -- @param params table  optional; must contain project
  -- @param opts   table
  function M:update(id, patch, params, opts)
    params = params or {}
    opts   = opts or {}
    local project = params.project or opts.project or client.config.project
    if not project then
      return nil, {
        type      = "http",
        message   = "work_items:update requires project in params or opts",
        retryable = false,
      }
    end
    -- JSON Patch requires a special Content-Type
    local query = {}
    for k, v in pairs(params) do
      if k ~= "project" then query[k] = v end
    end
    return client:request({
      method  = "PATCH",
      path    = "/" .. tostring(project) .. "/_apis/wit/workitems/" .. tostring(id),
      params  = query,
      body    = patch,
      headers = { ["Content-Type"] = "application/json-patch+json" },
    }, opts)
  end

  --- Get a work item type definition.
  -- GET /{project}/_apis/wit/workitemtypes/{name}
  -- @param name   string  e.g. "Bug", "User Story"
  -- @param params table   must contain project
  -- @param opts   table
  function M:get_type(name, params, opts)
    params = params or {}
    opts   = opts or {}
    local project = params.project or opts.project or client.config.project
    if not project then
      return nil, {
        type      = "http",
        message   = "work_items:get_type requires project in params or opts",
        retryable = false,
      }
    end
    local query = {}
    for k, v in pairs(params) do
      if k ~= "project" then query[k] = v end
    end
    return client:request({
      method = "GET",
      path   = "/" .. tostring(project) .. "/_apis/wit/workitemtypes/" .. tostring(name),
      params = query,
    }, opts)
  end

  --- Get all update revisions for a work item.
  -- GET /{project}/_apis/wit/workItems/{id}/updates
  -- Returns an object with a .value array of update records.  Each record has:
  --   rev          number
  --   revisedBy    table  { displayName, uniqueName, … }
  --   revisedDate  string ISO‑8601 timestamp
  --   fields       table  map of fieldRef → { oldValue, newValue }
  -- @param id     number|string  Work item ID
  -- @param params table          optional; must contain project
  -- @param opts   table
  function M:get_updates(id, params, opts)
    params = params or {}
    opts   = opts or {}
    local project = params.project or opts.project or client.config.project
    if not project then
      return nil, {
        type      = "http",
        message   = "work_items:get_updates requires project in params or opts",
        retryable = false,
      }
    end
    local query = {}
    for k, v in pairs(params) do
      if k ~= "project" then query[k] = v end
    end
    return client:request({
      method = "GET",
      path   = "/" .. tostring(project) .. "/_apis/wit/workItems/" .. tostring(id) .. "/updates",
      params = query,
    }, opts)
  end

  --- List discussion comments on a work item (newest first).
  -- GET /{project}/_apis/wit/workItems/{id}/comments
  -- Comments are a preview API; api-version is pinned to 7.0-preview.3.
  -- Response data.comments is an array of { id, text, createdBy, createdDate, ... }.
  -- @param id     number|string
  -- @param params table  must contain project; optional order, $expand, …
  -- @param opts   table
  function M:get_comments(id, params, opts)
    params = params or {}
    opts   = opts or {}
    local project = params.project or opts.project or client.config.project
    if not project then
      return nil, {
        type      = "http",
        message   = "work_items:get_comments requires project in params or opts",
        retryable = false,
      }
    end
    local query = {
      ["api-version"] = "7.0-preview.3",
      order           = "desc",
    }
    for k, v in pairs(params) do
      if k ~= "project" then query[k] = v end
    end
    return client:request({
      method = "GET",
      path   = "/" .. tostring(project) .. "/_apis/wit/workItems/" .. tostring(id) .. "/comments",
      params = query,
    }, opts)
  end

  --- Add a discussion comment on a work item.
  -- POST /{project}/_apis/wit/workItems/{id}/comments
  -- Body: { text = "<html or plain text>" }
  -- @param id     number|string
  -- @param text   string  comment body (required, non-empty)
  -- @param params table    must contain project
  -- @param opts   table
  function M:add_comment(id, text, params, opts)
    params = params or {}
    opts   = opts or {}
    local project = params.project or opts.project or client.config.project
    if not project then
      return nil, {
        type      = "http",
        message   = "work_items:add_comment requires project in params or opts",
        retryable = false,
      }
    end
    if type(text) ~= "string" or not text:match("%S") then
      return nil, {
        type      = "http",
        message   = "work_items:add_comment requires non-empty text",
        retryable = false,
      }
    end
    return client:request({
      method = "POST",
      path   = "/" .. tostring(project) .. "/_apis/wit/workItems/" .. tostring(id) .. "/comments",
      params = { ["api-version"] = "7.0-preview.3" },
      body   = { text = text },
    }, opts)
  end

  --- Get the states for a work item type.
  -- GET /{project}/_apis/wit/workitemtypes/{name}/states
  -- @param name   string
  -- @param params table  must contain project
  -- @param opts   table
  function M:get_type_states(name, params, opts)
    params = params or {}
    opts   = opts or {}
    local project = params.project or opts.project or client.config.project
    if not project then
      return nil, {
        type      = "http",
        message   = "work_items:get_type_states requires project in params or opts",
        retryable = false,
      }
    end
    local query = {}
    for k, v in pairs(params) do
      if k ~= "project" then query[k] = v end
    end
    return client:request({
      method = "GET",
      path   = "/" .. tostring(project) .. "/_apis/wit/workitemtypes/" .. tostring(name) .. "/states",
      params = query,
    }, opts)
  end

  return M
end
