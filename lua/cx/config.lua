local M = {}

M.defaults = {
  command = 'contextualize',
  commands = true,
  picker = 'auto',
  telescope = {
    theme = 'ivy',
    prompt_title = 'Contexts',
    results_title = 'Manifests',
    preview_title = 'Source',
    layout_config = {
      height = 0.46,
    },
  },
  integrations = {},
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend('force', vim.deepcopy(M.defaults), opts or {})
  return M.options
end

return M
