local M = {}

local function clamp(value, min, max) return math.max(min, math.min(max, value)) end

local function display_width(contexts, key, min, max)
  local width = min
  for _, context in ipairs(contexts) do
    width = math.max(width, vim.fn.strdisplaywidth(context[key] or ''))
  end
  return clamp(width, min, max)
end

local function source_width(name_width, origin_width)
  local available = math.max((vim.o.columns or 80) - name_width - origin_width - 8, 32)
  return clamp(math.floor(available * 0.45), 18, 46)
end

local function source_label(contexts, context)
  local entry = contexts.source_entry_for_context(context)
  local label = entry and contexts.compact_path(entry.path) or context.source
  if entry and entry.line and entry.line > 1 then label = label .. ':' .. entry.line end
  return label
end

local function create_entry_maker(contexts, entries)
  local entry_display = require('telescope.pickers.entry_display')
  local name_width = display_width(entries, 'name', 12, 22)
  local origin_width = display_width(entries, 'origin', 3, 12)
  local displayer = entry_display.create({
    separator = ' ',
    items = {
      { width = name_width },
      { width = origin_width },
      { width = source_width(name_width, origin_width) },
      { remaining = true },
    },
  })

  return function(context)
    local source_entry = contexts.source_entry_for_context(context)
    local source = source_label(contexts, context)
    local target = contexts.compact_path(context.target)
    local display = function()
      return displayer({
        { context.name, 'TelescopeResultsIdentifier' },
        { context.origin, 'TelescopeResultsNumber' },
        { source, 'TelescopeResultsComment' },
        target,
      })
    end

    return {
      value = context,
      display = display,
      ordinal = table.concat({ context.name, context.source, context.origin, context.target, source, target }, ' '),
      path = source_entry and source_entry.path or context.target,
      lnum = source_entry and source_entry.line or 1,
    }
  end
end

local function telescope_opts(opts)
  local themes = require('telescope.themes')
  local configured = vim.deepcopy(require('cx.config').options.telescope or {})
  local merged = vim.tbl_deep_extend('force', configured, opts or {})
  local theme = merged.theme
  merged.theme = nil
  if theme == 'ivy' then return themes.get_ivy(merged) end
  if theme == 'dropdown' then return themes.get_dropdown(merged) end
  if theme == 'cursor' then return themes.get_cursor(merged) end
  return merged
end

local function open_context_source(context, command)
  local contexts = require('cx.contexts')
  local entry = contexts.source_entry_for_context(context)
  if not entry then
    vim.notify('context has no file-backed manifest source: ' .. context.name, vim.log.levels.WARN)
    return
  end
  contexts.open_source_entry(entry, command)
end

function M.contexts(opts)
  opts = opts or {}
  local contexts = require('cx.contexts')
  local entries, err = contexts.list(opts)
  if not entries then
    vim.notify(err or 'contextualize contexts list failed', vim.log.levels.WARN)
    return
  end

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  local function selected_context(prompt_bufnr)
    local entry = action_state.get_selected_entry()
    actions.close(prompt_bufnr)
    return entry and entry.value or nil
  end

  local function open_selected(prompt_bufnr, command)
    local context = selected_context(prompt_bufnr)
    if context then open_context_source(context, command) end
  end

  local picker_opts = telescope_opts(opts.telescope or opts)
  pickers
    .new(picker_opts, {
      finder = finders.new_table({
        results = entries,
        entry_maker = create_entry_maker(contexts, entries),
      }),
      sorter = conf.generic_sorter(picker_opts),
      previewer = conf.file_previewer(picker_opts),
      attach_mappings = function(_, map)
        actions.select_default:replace(function(prompt_bufnr) open_selected(prompt_bufnr, 'edit') end)
        map('i', '<C-v>', function(prompt_bufnr) open_selected(prompt_bufnr, 'vsplit') end)
        map('n', '<C-v>', function(prompt_bufnr) open_selected(prompt_bufnr, 'vsplit') end)
        map('i', '<C-x>', function(prompt_bufnr) open_selected(prompt_bufnr, 'split') end)
        map('n', '<C-x>', function(prompt_bufnr) open_selected(prompt_bufnr, 'split') end)
        map('i', '<C-t>', function(prompt_bufnr) open_selected(prompt_bufnr, 'tabedit') end)
        map('n', '<C-t>', function(prompt_bufnr) open_selected(prompt_bufnr, 'tabedit') end)
        return true
      end,
    })
    :find()
end

return M
