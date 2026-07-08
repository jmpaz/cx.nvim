local M = {}

local uv, fn = vim.uv or vim.loop, vim.fn

local function expand_home(path) return (path or ''):gsub('^~', vim.env.HOME or '~') end

local function read_lines(path)
  local fd = io.open(path, 'r')
  if not fd then return nil end
  local lines = {}
  for line in fd:lines() do
    lines[#lines + 1] = line
  end
  fd:close()
  return lines
end

local function read_json(path)
  local fd = io.open(path, 'r')
  if not fd then return nil end
  local content = fd:read('*a')
  fd:close()
  local decoder = vim.json and vim.json.decode or fn.json_decode
  local ok, decoded = pcall(decoder, content)
  if ok and type(decoded) == 'table' then return decoded end
end

function M.normalize_path(path)
  if not path or path == '' then return nil end
  return fn.fnamemodify(expand_home(path), ':p'):gsub('/+$', '')
end

function M.compact_path(path)
  if not path or path == '' then return '' end
  path = expand_home(path)
  local home = vim.env.HOME
  if home and home ~= '' and path == home then return '~' end
  local prefix = home and (home .. '/') or nil
  if prefix and path:sub(1, #prefix) == prefix then return '~/' .. path:sub(#prefix + 1) end
  return path
end

function M.exists(path) return path and uv.fs_stat(path) ~= nil end

function M.join(a, b) return a:sub(-1) == '/' and (a .. b) or (a .. '/' .. b) end

function M.relative_path(path, root)
  path = M.normalize_path(path)
  root = M.normalize_path(root)
  if not path or not root then return nil end
  if path == root then return '' end
  local prefix = root .. '/'
  if path:sub(1, #prefix) ~= prefix then return nil end
  return path:sub(#prefix + 1)
end

local function is_dir(path)
  local stat = path and uv.fs_stat(path)
  return stat and stat.type == 'directory'
end

local function dirname(path) return fn.fnamemodify(path, ':h') end

function M.parse_contexts_json(output)
  local decoder = vim.json and vim.json.decode or fn.json_decode
  local ok, decoded = pcall(decoder, output or '')
  if not ok or type(decoded) ~= 'table' then return nil end
  local contexts = {}
  for _, item in ipairs(decoded) do
    if type(item) == 'table' and item.name and item.source and item.origin and item.target then
      contexts[#contexts + 1] = {
        name = tostring(item.name),
        source = tostring(item.source),
        origin = tostring(item.origin),
        target = tostring(item.target),
      }
    end
  end
  return contexts
end

function M.parse_contexts_table(output)
  local contexts = {}
  for line in (output or ''):gmatch('[^\r\n]+') do
    local trimmed = line:gsub('^%s+', ''):gsub('%s+$', '')
    if trimmed ~= '' and not trimmed:match('^Context registry:') and not trimmed:match('^name%s+') then
      local name, source, origin, target = trimmed:match('^(%S+)%s+(.+)%s+(%S+)%s+(/.*)$')
      if name then
        contexts[#contexts + 1] = {
          name = name,
          source = source:gsub('%s+$', ''),
          origin = origin,
          target = target,
        }
      end
    end
  end
  return contexts
end

local function run_contexts_list(json_output, opts)
  local config = require('cx.config').options
  local command = (opts and opts.command) or config.command
  if fn.executable(command) == 0 then return nil, command .. ' not found on PATH' end
  local args = { command, 'contexts', 'list' }
  if json_output then args[#args + 1] = '--json' end
  local registry = opts and opts.registry
  if registry then
    args[#args + 1] = '--registry'
    args[#args + 1] = registry
  end
  local result = vim.system(args, { text = true }):wait()
  if result.code ~= 0 then
    local message = (result.stderr and result.stderr ~= '') and result.stderr or (result.stdout or '')
    return nil, message:gsub('%s+$', '')
  end
  return result.stdout
end

function M.list(opts)
  local output, err = run_contexts_list(true, opts)
  if output then
    local parsed = M.parse_contexts_json(output)
    if parsed then return parsed end
  end

  local fallback, fallback_err = run_contexts_list(false, opts)
  if not fallback then return nil, fallback_err or err or 'contextualize contexts list failed' end
  return M.parse_contexts_table(fallback)
end

function M.context_manifest_line(source, name)
  if not source:match('%.md$') and not source:match('%.markdown$') then return 1 end
  local lines = read_lines(source)
  if not lines then return 1 end
  local first_yaml_line
  local in_yaml, start_line = false, nil
  for i, line in ipairs(lines) do
    if not in_yaml then
      if line:match('^```%s*ya?ml%s*$') then
        in_yaml = true
        start_line = i + 1
        first_yaml_line = first_yaml_line or start_line
      end
    elseif line:match('^```%s*$') then
      in_yaml = false
      start_line = nil
    elseif name and line:match('^%s*name:%s*' .. vim.pesc(name) .. '%s*$') then
      return start_line or i
    end
  end
  return first_yaml_line or 1
end

function M.source_entry_for_context(context)
  if not context or context.source == 'inline text' or context.source == 'inline data' then return nil end
  local source = expand_home(context.source)
  if not source:match('^/') then
    local target = M.normalize_path(context.target)
    if not target then return nil end
    source = M.join(target, source)
  end
  return {
    path = source,
    line = M.context_manifest_line(source, context.name),
    rel = context.name,
    context = context,
  }
end

local function find_context_root(path)
  path = M.normalize_path(path)
  if not path then return nil end
  local current = is_dir(path) and path or dirname(path)
  while current and current ~= '' and current ~= '/' do
    if M.exists(M.join(current, 'index.json')) then return current end
    local parent = dirname(current)
    if parent == current then break end
    current = parent
  end
end

function M.manifest_source_entry(path, opts)
  path = M.normalize_path(path)
  if not path then return nil end
  if is_dir(path) then
    local manifest_path = M.join(path, 'manifest.yaml')
    if M.exists(manifest_path) then path = manifest_path end
  end
  local root = find_context_root(path)
  if not root then return nil end
  local index = read_json(M.join(root, 'index.json'))
  local source = index and index.manifest_source
  local manifests = type(source) == 'table' and source.manifests or nil
  if type(manifests) ~= 'table' or type(source.path) ~= 'string' then return nil end

  local rel = M.relative_path(path, root)
  if not rel or rel == '' then return nil end
  local direct = manifests[rel]
  if type(direct) == 'table' then return { path = source.path, line = direct.line or 1, rel = rel } end
  if opts and opts.manifest_only then return nil end

  local suffix = '/manifest.yaml'
  local best_rel, best_entry
  for manifest_rel, entry in pairs(manifests) do
    if type(manifest_rel) == 'string' and manifest_rel:sub(-#suffix) == suffix then
      local dir = manifest_rel:sub(1, #manifest_rel - #suffix)
      if rel == dir or rel:sub(1, #dir + 1) == dir .. '/' then
        if not best_rel or #dir > #best_rel then
          best_rel = dir
          best_entry = entry
        end
      end
    end
  end
  if type(best_entry) == 'table' then
    return { path = source.path, line = best_entry.line or 1, rel = best_rel .. suffix }
  end
  local root_entry = manifests['manifest.yaml']
  if type(root_entry) == 'table' then
    return { path = source.path, line = root_entry.line or 1, rel = 'manifest.yaml' }
  end
end

function M.source_entry_for_path(path, opts)
  local entry = M.manifest_source_entry(path, opts)
  if entry then return entry end
  if opts and opts.manifest_only and not path:match('/manifest%.ya?ml$') then return nil end
  local contexts = M.list(opts)
  if not contexts then return nil end
  local best
  for _, context in ipairs(contexts) do
    local target = M.normalize_path(context.target)
    local rel = M.relative_path(path, target)
    if rel and (not best or #target > #best.target) then
      best = vim.tbl_extend('force', context, { target = target })
    end
  end
  return M.source_entry_for_context(best)
end

function M.is_context_path(path)
  path = M.normalize_path(path)
  return path and path:find('/%.context/') ~= nil
end

function M.open_file(path, line, command)
  if not M.exists(path) then
    vim.notify('manifest source not found: ' .. path, vim.log.levels.WARN)
    return false
  end
  vim.cmd(string.format('%s +%d %s', command or 'edit', tonumber(line) or 1, fn.fnameescape(path)))
  return true
end

function M.open_source_entry(entry, command)
  if not entry or not entry.path then return false end
  return M.open_file(entry.path, entry.line, command)
end

function M.goto_source(opts)
  opts = opts or {}
  local path = opts.path or vim.api.nvim_buf_get_name(0)
  local entry = M.source_entry_for_path(path, opts)
  if entry then return M.open_source_entry(entry, opts.command) end
  if M.is_context_path(path) then
    vim.notify('context source metadata is unavailable for this generated file', vim.log.levels.WARN)
  end
  return false
end

return M
