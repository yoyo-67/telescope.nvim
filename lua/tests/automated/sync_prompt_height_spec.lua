local pickers = require "telescope.pickers"
local state = require "telescope.state"

local Picker = pickers._Picker

-- A picker stripped down to what _sync_prompt_height touches. `find` reaches
-- this code with real windows but before it has registered them in the global
-- state, which is the case being pinned here.
local function fake_picker()
  local bufnr = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(bufnr, false, {
    relative = "editor",
    width = 20,
    height = 1,
    row = 1,
    col = 1,
  })

  local picker = setmetatable({
    multi_line_prompt = true,
    max_prompt_height = 5,
    prompt_bufnr = bufnr,
    prompt_win = win,
    layout_updates = 0,
  }, Picker)

  picker.full_layout_update = function(self)
    self.layout_updates = self.layout_updates + 1
  end

  return picker
end

local function cleanup(picker)
  pcall(vim.api.nvim_win_close, picker.prompt_win, true)
  pcall(vim.api.nvim_buf_delete, picker.prompt_bufnr, { force = true })
  TelescopeGlobalState[picker.prompt_bufnr] = nil
end

describe("Picker:_sync_prompt_height", function()
  it("does not update the layout before the windows are registered", function()
    local picker = fake_picker()

    assert.has_no.errors(function()
      picker:_sync_prompt_height()
    end)
    assert.are.equal(0, picker.layout_updates)

    cleanup(picker)
  end)

  it("updates the layout once the windows are registered", function()
    local picker = fake_picker()
    state.set_status(picker.prompt_bufnr, { prompt_win = picker.prompt_win })

    picker:_sync_prompt_height()
    assert.are.equal(1, picker.layout_updates)

    cleanup(picker)
  end)

  it("still syncs a height change that happens after registration", function()
    local picker = fake_picker()

    -- the pre-registration call must not swallow the height it saw
    picker:_sync_prompt_height()
    state.set_status(picker.prompt_bufnr, { prompt_win = picker.prompt_win })
    vim.api.nvim_buf_set_lines(picker.prompt_bufnr, 0, -1, false, { "a", "b", "c" })
    picker:_sync_prompt_height()

    assert.are.equal(1, picker.layout_updates)
    assert.are.equal(3, picker.__prompt_height)

    cleanup(picker)
  end)
end)
