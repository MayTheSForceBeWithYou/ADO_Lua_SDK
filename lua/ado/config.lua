--- config.lua — compatibility re-export
-- Prefer require("ado.core.config") from SDK internals so a host plugin's
-- lua/ado/config.lua cannot shadow client construction.

return require("ado.core.config")
