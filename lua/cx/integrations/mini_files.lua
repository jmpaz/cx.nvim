local M = {}

function M.setup(opts)
  opts = vim.tbl_extend('force', { mapping = 'gd' }, opts or {})
  vim.api.nvim_create_autocmd('User', {
    pattern = 'MiniFilesBufferCreate',
    callback = function(args)
      vim.keymap.set('n', opts.mapping, function()
        local ok, mini_files = pcall(require, 'mini.files')
        if not ok then return end
        local entry = mini_files.get_fs_entry()
        if not entry or not entry.path then return end
        local contexts = require('cx.contexts')
        local source_entry = contexts.source_entry_for_path(entry.path, {})
        if source_entry then
          mini_files.close()
          contexts.open_source_entry(source_entry, 'edit')
          return
        end
        if contexts.is_context_path(entry.path) then
          vim.notify('context source metadata is unavailable for this generated file', vim.log.levels.WARN)
        end
      end, { buffer = args.data.buf_id, desc = 'goto context manifest source' })
    end,
  })
end

return M
