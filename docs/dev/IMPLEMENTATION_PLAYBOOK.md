# Implementation Playbook — ADO Lua SDK

## How to Add a New Endpoint Function

### 1. Look up the endpoint via MCP

```
ado_docs.endpoint(route="/_apis/<path>", method="GET")
ado_docs.pack(endpoint="GET /_apis/<path>", char_budget=12000)
```

Read the packed docs carefully:
- Required path parameters
- Required and optional query parameters
- Request body schema (for POST/PATCH/PUT)
- Response schema and relevant headers (especially continuation token headers)

---

### 2. Locate or create the domain module

**File:** `lua/ado/api/<domain>.lua`

Module pattern (always use this skeleton):

```lua
-- lua/ado/api/<domain>.lua
return function(client)
  local M = {}

  -- example endpoint
  function M:list(params, opts)
    params = params or {}
    return client:request({
      method = "GET",
      path   = "/_apis/<path>",
      query  = {
        ["api-version"] = client.config.api_version,
        -- add other query params from MCP docs here
      },
    }, opts)
  end

  return M
end
```

**Function signature standard:** `function M:fn_name(params, opts)`
- `params` — optional table of endpoint-specific inputs (path vars, query params, body)
- `opts` — optional table; pass-through to `client:request()`; supports `async` + `callback`
- `self` (via `:`) gives access to the module table if needed, but most functions won't need it

---

### 3. Register the module in client.lua

In `lua/ado/client.lua`, inside `Client.new`:

```lua
self.<domain> = require("ado.api.<domain>")(self)
```

Keep registrations alphabetical for readability.

---

### 4. Add error type mappings (only if new types are needed)

File: `lua/ado/core/errors.lua`

Only add a new error type if the endpoint returns a domain-specific error shape
that is not covered by the existing types:
`http | auth | transport | rate_limit | parse`

Do not add ad-hoc error handling inside API modules.

---

### 5. Write tests

**File:** `tests/<domain>_spec.lua`

Test structure (busted):

```lua
local subject = require("ado.api.<domain>")

describe("<domain>", function()
  local client, module

  before_each(function()
    -- Build a minimal fake client
    client = {
      config = { api_version = "7.2-preview.1" },
      request = function(self, req, opts)
        -- store last call for assertions
        client._last_req = req
        -- return a canned success response
        return { data = {}, status = 200, headers = {} }, nil
      end,
    }
    module = subject(client)
  end)

  it("calls the correct path", function()
    module:list()
    assert.are.equal("/_apis/<path>", client._last_req.path)
    assert.are.equal("GET", client._last_req.method)
  end)

  it("passes api-version query param", function()
    module:list()
    assert.are.equal("7.2-preview.1", client._last_req.query["api-version"])
  end)

  it("forwards continuation_token when provided", function()
    module:list({ continuation_token = "tok123" })
    assert.are.equal("tok123", client._last_req.query["continuationToken"])
  end)

  it("returns nil + err table on transport error", function()
    client.request = function() return nil, { type = "transport", message = "fail", retryable = true } end
    local res, err = module:list()
    assert.is_nil(res)
    assert.are.equal("transport", err.type)
  end)
end)
```

---

### 6. Run tests

```bash
cd /home/n8/dev/Lua/ADO_Lua_SDK
busted tests/
```

All existing tests must continue to pass after your change.

---

## File Touch Points Summary

| File | When to touch |
|------|--------------|
| `lua/ado/api/<domain>.lua` | Always — this is where endpoint functions live |
| `lua/ado/client.lua` | Only when adding a new domain module |
| `lua/ado/core/errors.lua` | Only when a new error category is needed |
| `tests/<domain>_spec.lua` | Always — every endpoint needs mock-transport coverage |

---

## Return Shape Rules

All functions must return exactly one of:

**Success:**
```lua
return {
  data               = <table or scalar>,   -- parsed JSON response body
  status             = <number>,            -- HTTP status code
  headers            = <table>,             -- normalized response headers
  continuation_token = <string or nil>,     -- from x-ms-continuationtoken header
  etag               = <string or nil>,     -- from ETag header
}, nil
```

**Failure:**
```lua
return nil, {
  type        = "http"|"auth"|"transport"|"rate_limit"|"parse",
  message     = <string>,
  status      = <number or nil>,
  code        = <string or nil>,    -- e.g. "TF400813"
  retryable   = <boolean>,
  retry_after = <number or nil>,    -- seconds
  request_id  = <string or nil>,
  raw         = <any>,
}
```

API modules do not construct error tables directly — they return whatever
`client:request()` returns. The pipeline and `core/errors.lua` own error construction.

---

## Anti-Patterns — Do Not Do These

- Do NOT call `error()` or `assert()` in SDK runtime paths
- Do NOT add retry logic inside an API module
- Do NOT implement pagination loops inside an API module
- Do NOT access `vim.*` anywhere in `lua/ado/**`
- Do NOT store state on the module table between calls
- Do NOT add a new dependency for something the blueprint already covers
