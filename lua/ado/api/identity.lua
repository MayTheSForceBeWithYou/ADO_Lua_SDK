--- api/identity.lua — identity/graph search via VSSPS endpoint
-- Factory: require("ado.api.identity")(client) → module
--
-- Uses client.config.vssps_url instead of base_url (different host).

return function(client)
  local M = {}

  --- Search for identities (users, groups) by display name or email.
  -- GET {vssps_url}/_apis/identities
  --   ?searchFilter=General&filterValue={query}&queryMembership=None
  --
  -- Note: vssps does not support api-version > 7.0; pinned in params.
  --
  -- @param query  string  display name or email fragment to search
  -- @param params table   optional overrides (e.g. searchFilter, queryMembership)
  -- @param opts   table   pipeline options
  function M:search(query, params, opts)
    local q_params = {
      searchFilter    = "General",
      filterValue     = tostring(query or ""),
      queryMembership = "None",
      ["api-version"] = "7.0",
    }
    if params then
      for k, v in pairs(params) do
        q_params[k] = v
      end
    end

    return client:request({
      method   = "GET",
      base_url = client.config.vssps_url,
      path     = "/_apis/identities",
      params   = q_params,
    }, opts)
  end

  return M
end
