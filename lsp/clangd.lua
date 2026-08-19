return {
  cmd = { 'clangd', '--offset-encoding=utf-16', '--background-index' },
  filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
  root_markers = { '.clangd', 'compile_commands.json', 'compile_flags.txt', '.git' },
}
