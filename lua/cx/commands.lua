local M = {}

local function create(name, rhs, desc)
  vim.api.nvim_create_user_command(name, rhs, {
    desc = desc,
    force = true,
  })
end

function M.setup()
  create('CxContexts', function() require('cx').contexts() end, 'Browse context manifests')
  create('CxManifests', function() require('cx').manifests() end, 'Browse context manifests')
  create('CxSource', function() require('cx').goto_source({ command = 'edit' }) end, 'Open context manifest source')
  create(
    'CxSourceVsplit',
    function() require('cx').goto_source({ command = 'vsplit' }) end,
    'Open context manifest source'
  )
end

return M
