--- init.lua — public entry point for the ADO Lua SDK
--
-- Usage:
--   local ado = require("ado")
--   local client, err = ado.new({
--     base_url = "https://dev.azure.com/myorg",
--     auth     = ado.auth.pat("my-token"),
--   })
--
-- Neovim plugins that already own require("ado") should use require("ado.sdk")
-- instead; this file is a thin re-export of that module.

return require("ado.sdk")
