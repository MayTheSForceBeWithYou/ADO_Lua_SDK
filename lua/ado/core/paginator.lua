--- core/paginator.lua — continuation-token pagination helper
-- No dependencies; works with any fetch function that returns SDK response shape.

local M = {}

--- Drive pagination to completion, accumulating all pages into one result.
--
-- @param fetch_fn function  called as fetch_fn(token) → res, err
--   On the first call token is nil.
--   res must have shape: { data = { value = {...}, ... }, continuation_token = string|nil }
-- @param opts table
--   opts.data_key   string  field inside res.data to accumulate (default "value")
--   opts.max_pages  number  guard against infinite loops (default 1000)
-- @return table|nil  accumulated result table with .data.value containing all items
-- @return table|nil  error (first return is nil on error)
function M.collect(fetch_fn, opts)
  opts = opts or {}
  local data_key  = opts.data_key  or "value"
  local max_pages = opts.max_pages or 1000

  local all_items = {}
  local token     = nil
  local last_res  = nil
  local pages     = 0

  repeat
    pages = pages + 1
    if pages > max_pages then
      return nil, {
        type      = "http",
        message   = "paginator: exceeded max_pages limit (" .. tostring(max_pages) .. ")",
        retryable = false,
      }
    end

    local res, err = fetch_fn(token)
    if err then
      return nil, err
    end
    last_res = res

    -- Accumulate items
    local page_data = res and res.data and res.data[data_key]
    if page_data then
      for _, item in ipairs(page_data) do
        all_items[#all_items + 1] = item
      end
    end

    token = res and res.continuation_token
  until not token

  -- Return a merged response: last page's metadata + all accumulated items
  local merged = {
    data               = {},
    status             = last_res and last_res.status,
    headers            = last_res and last_res.headers,
    continuation_token = nil,
    etag               = last_res and last_res.etag,
  }
  -- Copy all fields from last page's data, then overwrite the data_key with merged list
  if last_res and last_res.data then
    for k, v in pairs(last_res.data) do
      merged.data[k] = v
    end
  end
  merged.data[data_key] = all_items

  return merged, nil
end

return M
