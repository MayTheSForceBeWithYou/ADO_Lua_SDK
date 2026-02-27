--- api/projects.lua — projects and teams endpoints
-- Factory: require("ado.api.projects")(client) → module

return function(client)
  local M = {}

  --- List all projects in the organization.
  -- GET /_apis/projects
  -- @param params table  optional query params (e.g. { stateFilter="wellFormed", top=100 })
  -- @param opts   table  pipeline options (callback, cache, …)
  -- @return res|nil, err|nil
  function M:list(params, opts)
    return client:request({
      method = "GET",
      path   = "/_apis/projects",
      params = params,
    }, opts)
  end

  --- Get a single project by ID or name.
  -- GET /_apis/projects/{projectId}?includeCapabilities=true
  -- @param id     string  project ID or name
  -- @param params table   optional additional params
  -- @param opts   table
  function M:get(id, params, opts)
    local merged = { includeCapabilities = "true" }
    if params then
      for k, v in pairs(params) do merged[k] = v end
    end
    return client:request({
      method = "GET",
      path   = "/_apis/projects/" .. tostring(id),
      params = merged,
    }, opts)
  end

  --- List teams for a project.
  -- GET /_apis/projects/{project}/teams
  -- @param project string  project ID or name
  -- @param params  table   optional: { ["$mine"] = true, top = 100 }
  -- @param opts    table
  function M:list_teams(project, params, opts)
    return client:request({
      method = "GET",
      path   = "/_apis/projects/" .. tostring(project) .. "/teams",
      params = params,
    }, opts)
  end

  --- List members of a team.
  -- GET /_apis/projects/{project}/teams/{teamId}/members
  -- @param project string
  -- @param team_id string
  -- @param params  table  optional
  -- @param opts    table
  function M:list_team_members(project, team_id, params, opts)
    return client:request({
      method = "GET",
      path   = "/_apis/projects/" .. tostring(project)
               .. "/teams/" .. tostring(team_id) .. "/members",
      params = params,
    }, opts)
  end

  return M
end
