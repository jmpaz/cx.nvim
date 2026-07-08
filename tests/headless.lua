vim.opt.runtimepath:prepend(vim.fn.getcwd())

local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, 'p')
local bin = tmp .. '/contextualize'
local source = tmp .. '/source.md'
local target = tmp .. '/target'
local context = target .. '/.context/demo'
vim.fn.mkdir(context, 'p')
vim.fn.writefile({
  '# source',
  '',
  '```yaml',
  'name: demo',
  'root: .',
  '```',
}, source)
vim.fn.writefile({
  vim.json.encode({
    manifest_source = {
      path = source,
      manifests = {
        ['manifest.yaml'] = { line = 4 },
      },
    },
  }),
}, context .. '/index.json')
vim.fn.writefile({
  '#!/usr/bin/env sh',
  'if [ "$1" = "contexts" ] && [ "$2" = "list" ]; then',
  '  for arg in "$@"; do',
  '    if [ "$arg" = "--json" ]; then',
  '      printf "%s\\n" ' .. vim.fn.shellescape(vim.json.encode({
    {
      name = 'demo',
      source = source,
      origin = 'nix',
      target = target,
    },
  })),
  '      exit 0',
  '    fi',
  '  done',
  '  printf "Context registry: total=1\\n  name  source  origin  target\\n  demo  '
    .. source
    .. '  nix  '
    .. target
    .. '\\n"',
  '  exit 0',
  'fi',
  'exit 1',
}, bin)
vim.fn.setfperm(bin, 'rwxr-xr-x')
vim.env.PATH = tmp .. ':' .. vim.env.PATH

require('cx').setup({ commands = true, picker = 'vim.ui' })

local contexts = require('cx.contexts')
local entries = assert(contexts.list())
assert(#entries == 1)
assert(entries[1].name == 'demo')
assert(entries[1].origin == 'nix')
assert(entries[1].source == source)
assert(entries[1].target == target)

local source_entry = assert(contexts.source_entry_for_context(entries[1]))
assert(source_entry.path == source)
assert(source_entry.line == 4)

local generated_entry = assert(contexts.source_entry_for_path(context .. '/manifest.yaml'))
assert(generated_entry.path == source)
assert(generated_entry.line == 4)

assert(vim.api.nvim_get_commands({})['CxContexts'])
assert(vim.api.nvim_get_commands({})['CxSource'])

print('cx.nvim headless checks ok')
