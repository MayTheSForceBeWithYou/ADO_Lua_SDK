--- init.lua — public entry point for the ADO Lua SDK
--
-- Usage:
--   local ado = require("ado")
--   local client, err = ado.new({
--     base_url = "https://dev.azure.com/myorg",
--     auth     = ado.auth.pat("my-token"),
--   })

local M = {}

--- Create a new ADO client.
-- @param opts table  configuration (see config.lua for accepted fields)
-- @return client|nil, err|nil
function M.new(opts)
  return require("ado.client").new(opts)
end

--- Auth provider constructors.
M.auth = {
  --- Create a PAT (Personal Access Token) auth provider.
  -- @param token string
  -- @return provider|nil, err|nil
  pat = function(token)
    return require("ado.auth.pat").new(token)
  end,

  --- Token store constructors (for OAuth, v2+).
  stores = {
    --- In-memory token store (no persistence).
    memory = function()
      return require("ado.auth.stores.memory").new()
    end,
  },
}

--- Pagination helper.
M.paginator = require("ado.core.paginator")

return M
