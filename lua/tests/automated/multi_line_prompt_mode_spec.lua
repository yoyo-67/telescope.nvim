local pickers = require "telescope.pickers"
local Picker = pickers._Picker

-- A |prompt-buffer| leaves insert mode by itself when it goes away, so closing a
-- normal picker lands back in normal mode. `multi_line_prompt` swaps in a
-- scratch buffer, which does not -- insert mode then leaks into whatever buffer
-- the action opened.
local function picker(fields)
  return setmetatable(fields, Picker)
end

describe("Picker:_should_stop_insert", function()
  it("stops insert for a multi_line_prompt picker opened from normal mode", function()
    local p = picker { multi_line_prompt = true, _original_mode = "n" }
    assert.is_true(p:_should_stop_insert "i")
  end)

  it("leaves a prompt-buffer picker alone -- it exits insert on its own", function()
    local p = picker { multi_line_prompt = false, _original_mode = "n" }
    assert.is_false(p:_should_stop_insert "i")
  end)

  it("stays in insert when the picker was opened from insert mode", function()
    local p = picker { multi_line_prompt = true, _original_mode = "i" }
    assert.is_false(p:_should_stop_insert "i")
  end)

  it("does nothing when the mode is already normal", function()
    local p = picker { multi_line_prompt = true, _original_mode = "n" }
    assert.is_false(p:_should_stop_insert "n")
  end)

  it("treats visual mode as nothing to restore", function()
    local p = picker { multi_line_prompt = true, _original_mode = "n" }
    assert.is_false(p:_should_stop_insert "v")
  end)
end)
