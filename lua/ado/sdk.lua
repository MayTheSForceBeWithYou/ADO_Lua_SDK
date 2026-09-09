--- sdk.lua — public SDK entry that does not go through require("ado")
--
-- Neovim plugins that already own the `ado` package (lua/ado/init.lua)
-- should require this module instead of require("ado"):
--   local sdk = require("ado.sdk")
--   local client, err = sdk.new({ base_url = ..., auth = sdk.auth.pat(token) })
--
-- Standalone require("ado") re-exports this module.

local M = {}

--- Create a new ADO client.
-- @param opts table  configuration (see ado.core.config for accepted fields)
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
