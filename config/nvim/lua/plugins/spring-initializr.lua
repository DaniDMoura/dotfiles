return {
  dir = vim.fn.stdpath("config"),
  name = "spring-initializr",
  config = function()
    require("spring_initializr").setup()
  end,
}
