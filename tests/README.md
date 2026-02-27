# Tests — ADO Lua SDK

## Test Framework: busted

The SDK uses **[busted](https://lunarmodules.github.io/busted/)** as its test runner.
busted is LuaRocks-friendly, widely used in the Lua ecosystem, and requires no Neovim.

### Install

```bash
luarocks install busted
```

### Run all tests

```bash
cd /home/n8/dev/Lua/ADO_Lua_SDK
busted tests/
```

### Run a single spec file

```bash
busted tests/projects_spec.lua
```

---

## Test Philosophy

- **No live HTTP.** All unit tests use a mock/fake transport injected into the client.
- **Test the contract, not internals.** Assert the request shape (path, method, query, headers) and the return shape — not implementation details.
- **One spec file per domain module.** `tests/<domain>_spec.lua` mirrors `lua/ado/api/<domain>.lua`.

---

## Fake Transport Pattern

```lua
-- Minimal fake client for tests
local function make_client(response_override)
  local client = {
    config = { api_version = "7.2-preview.1" },
    _last_req = nil,
  }
  function client:request(req, opts)
    self._last_req = req
    if response_override then
      return response_override()
    end
    return { data = {}, status = 200, headers = {}, continuation_token = nil, etag = nil }, nil
  end
  return client
end
```

For error scenarios:

```lua
local function make_error_client(err_table)
  local client = make_client(function()
    return nil, err_table
  end)
  return client
end
```

---

## File Naming Convention

| File | Purpose |
|------|---------|
| `tests/<domain>_spec.lua` | Unit tests for `lua/ado/api/<domain>.lua` |
| `tests/core/<module>_spec.lua` | Unit tests for `lua/ado/core/<module>.lua` |
| `tests/auth/<module>_spec.lua` | Unit tests for `lua/ado/auth/<module>.lua` |

---

## Integration Tests (future)

Integration tests that hit live ADO endpoints should be gated behind an environment variable:

```lua
if not os.getenv("ADO_INTEGRATION_TEST") then
  pending("set ADO_INTEGRATION_TEST=1 to run")
  return
end
```

Do not add integration tests until the core SDK is stable. Keep them in a
separate `tests/integration/` directory.

---

## Assumption Note

The choice of **busted** over **luaunit** was made because:
- busted has better BDD-style describe/it syntax for readability
- broader LuaRocks ecosystem adoption
- native async/pending test support

If you prefer luaunit, adapt the fake transport pattern above — the mock approach is the same.
