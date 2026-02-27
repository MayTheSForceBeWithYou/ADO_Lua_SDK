--- core/retry.lua — retry policy
-- Depends on: backoff, errors (for retryable flag check)

local backoff = require("ado.core.backoff")

local M = {}
local Policy = {}
Policy.__index = Policy

--- Create a new retry policy.
-- @param opts table
--   opts.max_attempts  number  total attempts including the first (default 3)
--   opts.backoff_opts  table   forwarded to backoff.compute (optional)
-- @return policy
function M.new(opts)
  opts = opts or {}
  return setmetatable({
    max_attempts = opts.max_attempts or 3,
    backoff_opts = opts.backoff_opts or {},
  }, Policy)
end

--- Check whether a retry should be attempted.
-- @param attempt number  the attempt number just completed (1 = first try)
-- @param err     table   SDK error table
-- @return boolean
function Policy:should_retry(attempt, err)
  if not err then return false end
  if err.retryable ~= true then return false end
  return attempt < self.max_attempts
end

--- Block (sleep) for the appropriate backoff period before the next attempt.
-- Uses os.execute("sleep N") — synchronous, Unix-only in v1.
-- @param attempt number  the attempt that just completed
function Policy:wait(attempt)
  local delay = backoff.compute(attempt, self.backoff_opts)
  if delay > 0 then
    -- os.execute is blocking and Unix-only; acceptable for v1 curl transport
    os.execute("sleep " .. string.format("%.3f", delay))
  end
end

return M
