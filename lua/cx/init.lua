local M = {}

function M.setup(opts)
  local config = require('cx.config').setup(opts)
  if config.commands ~= false then require('cx.commands').setup() end
  local mini_files = config.integrations and config.integrations.mini_files
  if mini_files then require('cx.integrations.mini_files').setup(mini_files == true and {} or mini_files) end
end

function M.contexts(opts) return require('cx.pickers').contexts(opts) end

function M.manifests(opts) return require('cx.pickers').contexts(opts) end

function M.goto_source(opts) return require('cx.contexts').goto_source(opts) end

return M
