local function contexts(opts) require('cx.pickers.telescope').contexts(opts) end

return require('telescope').register_extension({
  exports = {
    contexts = contexts,
    manifests = contexts,
  },
})
