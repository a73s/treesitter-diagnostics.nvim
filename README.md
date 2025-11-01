Gives you basic diagnostics from the treesitter parser. Its not perfect, and its not quite an lsp, but its lightweight, great for large projects, and better than nothing. Pairs great with ctags.

Example config for lazy.nvim
```lua
  {
    'a73s/treesitter-diagnostics',
    opts = {
      patters = {
        '*.h',
        '*.c',
        '*.cpp',
        '*.java',
        '*.cs',
        '*.ts',
        '*.js',
        '*.json',
        '*.xml',
        '*.html',
        '*.yaml',
        '*.cu',
      },
    },
  },

```
