return {
  {
    "sainnhe/sonokai",
    priority = 1000,
    lazy = true,
    config = function()
      vim.g.sonokai_transparent_background = 2
      vim.g.sonokai_enable_italic = true
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "sonokai",
    },
  },
}
