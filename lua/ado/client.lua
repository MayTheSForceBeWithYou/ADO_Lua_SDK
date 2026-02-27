--- client.lua — Client constructor; attaches domain modules
-- Depends on: config, core/pipeline, http/transport, core/cache, core/logger

local config_mod   = require("ado.config")
local pipeline_mod = require("ado.core.pipeline")
local transport_mod = require("ado.http.transport")
local cache_mod    = require("ado.core.cache")
local logger_mod   = require("ado.core.logger")

local M = {}
local Client = {}
Client.__index = Client

--- Create a new SDK client.
-- @param opts table  see config.normalize for accepted fields
-- @return client|nil, err|nil
function M.new(opts)
  local config, err = config_mod.normalize(opts)
  if err then
    return nil, err
  end

  -- Logger
  local logger
  if config.logger then
    logger = config.logger
  else
    logger = logger_mod.noop()
  end

  -- Cache
  local cache = cache_mod.new(config.cache)

  -- Transport
  local transport = transport_mod.new({ backend = config.transport })

  -- Assemble client
  local self = setmetatable({
    config    = config,
    auth      = config.auth,
    logger    = logger,
    cache     = cache,
    transport = transport,
  }, Client)

  -- Build pipeline (needs self fully formed)
  self.pipeline = pipeline_mod.new(self)

  -- Attach domain modules (alphabetical order)
  self.identity   = require("ado.api.identity")(self)
  self.projects   = require("ado.api.projects")(self)
  self.work_items = require("ado.api.work_items")(self)

  return self, nil
end

--- Execute a request through the pipeline.
-- This is the single entry point for all API modules.
-- @param req_spec table  see http/request.lua
-- @param opts     table  see core/pipeline.lua
-- @return res|nil, err|nil
function Client:request(req_spec, opts)
  return self.pipeline:execute(req_spec, opts)
end

return M
