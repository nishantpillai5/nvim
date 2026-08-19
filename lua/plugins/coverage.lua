return {
  {
    'andythigpen/nvim-coverage',
    version = '*',
    dependencies = { 'nvim-lua/plenary.nvim' },
    cmd = {
      'Coverage',
      'CoverageLoad',
      'CoverageLoadLcov',
      'CoverageShow',
      'CoverageHide',
      'CoverageToggle',
      'CoverageClear',
      'CoverageSummary',
    },
    opts = {
      auto_reload = true,
    },
  },
}
