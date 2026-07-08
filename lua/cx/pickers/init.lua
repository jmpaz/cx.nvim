local M = {}

local function vim_ui_contexts(opts)
  local contexts, err = require('cx.contexts').list(opts)
  if not contexts then
    vim.notify(err or 'contextualize contexts list failed', vim.log.levels.WARN)
    return
  end
  vim.ui.select(contexts, {
    prompt = 'Contexts',
    format_item = function(context) return string.format('%s  %s  %s', context.name, context.origin, context.target) end,
  }, function(context)
    if context then
      local entry = require('cx.contexts').source_entry_for_context(context)
      if entry then require('cx.contexts').open_source_entry(entry, 'edit') end
    end
  end)
end

function M.contexts(opts)
  local picker = (opts and opts.picker) or require('cx.config').options.picker
  local has_telescope = pcall(require, 'telescope.pickers')
  if picker == 'telescope' or (picker == 'auto' and has_telescope) then
    return require('cx.pickers.telescope').contexts(opts)
  end
  return vim_ui_contexts(opts)
end

return M
