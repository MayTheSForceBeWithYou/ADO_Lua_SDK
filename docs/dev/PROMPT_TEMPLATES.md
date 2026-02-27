# Prompt Templates — ADO Lua SDK

Copy-paste these into Claude Code at the start of an implementation session.
Fill in the bracketed placeholders before sending.

---

## Template 1 — Implement One Endpoint

> Use when: adding a single function to an existing or new domain module.

```
Use `ado_docs.endpoint` to locate [METHOD] [ROUTE].
Then call `ado_docs.pack` with a 12000-character budget for that endpoint.

Implement `client.[DOMAIN].[FUNCTION_NAME](params, opts)` in
`lua/ado/api/[DOMAIN].lua` using `client:request()`.

Requirements:
- Follow the function signature: `function M:fn(params, opts)`
- Return `res, err` per the shape in claude.md — never throw
- Do not add retry, pagination, or auth logic inside the module
- Add or update tests in `tests/[DOMAIN]_spec.lua` using a mock transport
- Run `busted tests/` and confirm all tests pass
```

**Example filled in:**
```
Use `ado_docs.endpoint` to locate GET /_apis/git/repositories.
Then call `ado_docs.pack` with a 12000-character budget for that endpoint.

Implement `client.git.list_repositories(params, opts)` in
`lua/ado/api/git.lua` using `client:request()`.
...
```

---

## Template 2 — Implement a Minimal v1 Module

> Use when: standing up a brand-new domain module from scratch.

```
Use `ado_docs.catalog` for service area [SERVICE_AREA] to get the full
endpoint list.

From that list, propose a minimal v1 surface of 5–10 functions. Prioritize
the most commonly used read (GET) and write (POST/PATCH) operations.
Confirm your selection with me before implementing.

For each selected endpoint:
1. Call `ado_docs.pack` with an 8000–12000 character budget
2. Implement the function in `lua/ado/api/[DOMAIN].lua`
3. Add mock-transport tests in `tests/[DOMAIN]_spec.lua`

Constraints:
- No new abstractions beyond what exists in `lua/ado/core/`
- Register the module in `lua/ado/client.lua`
- All functions follow `function M:fn(params, opts)` signature
- Run `busted tests/` after all functions are implemented
```

---

## Template 3 — Add Pagination Support to an Endpoint

> Use when: an endpoint returns continuation tokens and you need to expose
> that cleanly, or add a `paginator.collect` usage example.

```
Use `ado_docs.pack` (12000 chars) for [METHOD] [ROUTE] to confirm:
- The exact response header name that carries the continuation token
- Whether the token is passed back as a query param or request header

Then:
1. Ensure the endpoint function in `lua/ado/api/[DOMAIN].lua` passes
   `continuation_token` from `params` into the correct query param
2. Confirm the pipeline extracts `continuation_token` from the response
   headers and surfaces it in the success return table
3. Add or update tests asserting:
   - continuation_token is forwarded in the request when provided
   - continuation_token from the response is present in the return table
4. Add a usage example using `paginator.collect` in the test or a docstring

Run `busted tests/` and confirm all tests pass.
```

---

## Template 4 — OAuth Flow Work Session

> Use when: implementing or extending device code, auth code, or PKCE flows
> in `lua/ado/auth/oauth.lua` and the token store layer.

```
We are implementing OAuth flows for the ADO Lua SDK.
Use `ado_docs.search` or `ado_docs.pack` only where ADO-specific OAuth
endpoint details (device code URL, token URL, scopes) need to be confirmed.
Do not use random web results for Azure AD / Entra OAuth specifics — use MCP.

Scope of this session: [device_code | auth_code | pkce | token_refresh — pick one]

Requirements:
- All flow logic lives in `lua/ado/auth/oauth.lua`
- Token persistence uses the token store interface: `store:get`, `store:set`, `store:delete`
- No `vim.*` calls anywhere in `lua/ado/auth/**`
- The SDK core must remain runtime-agnostic — no OS-specific calls except in
  `lua/ado/auth/stores/file.lua` (file permissions: 0600 on Unix)
- Return `res, err` on all public functions — never throw
- Tests use a fake token store (table with get/set/delete methods)
- Run `busted tests/` and confirm all tests pass

Start by reading `lua/ado/auth/oauth.lua` and `lua/ado/auth/token_store.lua`
to understand the existing interface before making changes.
```

---

## General Tips

- Always run `ado_docs.pack` **before** writing code for an endpoint — never guess query param names.
- If `ado_docs.pack` output is ambiguous about a param, use `ado_docs.search` with a more specific query.
- If you're unsure whether a function belongs in `core/` or `api/`, it belongs in `core/` if it's reusable across multiple domain modules.
- Keep templates short and task-scoped. One session = one module or one endpoint family.
