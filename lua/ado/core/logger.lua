--- core/logger.lua — no-op logger interface
-- All log calls are no-ops by default.
-- A real logger can be injected by passing opts.logger to ado.new().
-- Expected interface: logger.debug/info/warn/error(msg, ctx)

local M = {}

local noop = function() end

--- Create a no-op logger (default).
function M.noop()
  return {
    debug = noop,
    info  = noop,
    warn  = noop,
    error = noop,
  }
end

--- Create a simple stderr logger (useful for CLI debugging).
-- @param level string minimum level: "debug"|"info"|"warn"|"error"
function M.stderr(level)
  local levels = { debug = 1, info = 2, warn = 3, error = 4 }
  local min = levels[level] or 1
  local function log(lname, msg, ctx)
    if (levels[lname] or 0) >= min then
      local line = string.format("[ado.%s] %s", lname, tostring(msg))
      if ctx then
        -- append simple key=value context
        local parts = {}
        for k, v in pairs(ctx) do
          parts[#parts + 1] = tostring(k) .. "=" .. tostring(v)
        end
        if #parts > 0 then
          line = line .. " {" .. table.concat(parts, ", ") .. "}"
        end
      end
      io.stderr:write(line .. "\n")
    end
  end
  return {
    debug = function(msg, ctx) log("debug", msg, ctx) end,
    info  = function(msg, ctx) log("info",  msg, ctx) end,
    warn  = function(msg, ctx) log("warn",  msg, ctx) end,
    error = function(msg, ctx) log("error", msg, ctx) end,
  }
end

return M
