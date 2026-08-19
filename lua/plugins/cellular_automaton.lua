-- When nothing works.
return {
  {
    'eandrju/cellular-automaton.nvim',
    cmd = 'CellularAutomaton',
    keys = {
      { '<leader>zOf', '<cmd>CellularAutomaton make_it_rain<cr>', desc = 'fml' },
      { '<leader>zOw', '<cmd>CellularAutomaton scramble<cr>', desc = 'too_much_work' },
    },
  },
}
