--- core/backoff.lua — exponential backoff with optional jitter
-- No dependencies.

local M = {}

--- Compute a backoff delay for a given attempt number.
-- @param attempt number  1-based attempt index
-- @param opts    table   optional overrides
--   opts.base   number  base delay in seconds (default 1)
--   opts.max    number  maximum delay in seconds (default 30)
--   opts.jitter boolean whether to add random jitter (default true)
-- @return number  delay in seconds (may be fractional)
function M.compute(attempt, opts)
  opts = opts or {}
  local base = opts.base or 1
  local max_delay = opts.max or 30
  local jitter = opts.jitter
  if jitter == nil then jitter = true end

  -- base * 2^(attempt-1)
  local delay = base * (2 ^ (attempt - 1))
  if delay > max_delay then delay = max_delay end

  if jitter then
    -- Full jitter: random value in [0, delay]
    delay = math.random() * delay
  end

  return delay
end

return M
