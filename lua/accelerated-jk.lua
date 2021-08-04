local M = {}

local opts = {
  mappings = { j = 'gj', k = 'gk' },
  acceleration_limit = 150,
  acceleration_table = { 7, 12, 17, 21, 24, 26, 28, 30 },
  deceleration_table = { { 150, 9999 } },
}
local MAX_ACC_COUNT = opts.acceleration_table[#opts.acceleration_table]
local MAX_ACC_INDEX = #opts.acceleration_table

function M.setup(user_opts)
  opts = vim.tbl_extend('force', opts, user_opts or {})
  for lhs, rhs in pairs(opts.mappings) do
    vim.api.nvim_set_keymap(
      'n',
      lhs,
      ([[<cmd>lua require'accelerated-jk'.command('%s')<cr>]]):format(rhs),
      { silent = true }
    )
  end

  MAX_ACC_COUNT = opts.acceleration_table[#opts.acceleration_table]
  MAX_ACC_INDEX = #opts.acceleration_table
end

----

local key_count = 0

local function deceleration(delay)
  local count = opts.deceleration_table[#opts.deceleration_table][2]
  local prev_dec_count = 0
  local elapsed, dec_count
  for _, item in ipairs(opts.deceleration_table) do
    elapsed, dec_count = unpack(item)
    if elapsed > delay then
      count = prev_dec_count
      break
    end
    prev_dec_count = dec_count
  end
  key_count = key_count - count < 0 and 0 or key_count - count
end

local function acceleration_step()
  for idx, count in ipairs(opts.acceleration_table) do
    if count > key_count then
      return idx
    end
  end
  return MAX_ACC_INDEX
end

local last_cmd
local last_time = 0

function M.command(cmd)
  if vim.v.count > 0 then
    vim.cmd('normal!' .. vim.v.count .. cmd)
    return
  end

  if cmd ~= last_cmd then
    last_time = 0
  end

  local time = vim.loop.hrtime()

  local elapsed = (time - last_time) / 1e6
  if elapsed > opts.acceleration_limit then
    deceleration(elapsed)
  end

  vim.cmd('normal!' .. acceleration_step() .. cmd)

  if key_count < MAX_ACC_COUNT then
    key_count = key_count + 1
  end

  last_cmd = cmd
  last_time = time
end

return M
