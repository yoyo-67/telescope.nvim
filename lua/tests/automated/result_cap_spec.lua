local result_cap = require "telescope.pickers.result_cap"

local function recorder()
  local calls = { results = {}, completes = 0, capped = 0 }
  local process_result = function(entry)
    table.insert(calls.results, entry)
  end
  local process_complete = function()
    calls.completes = calls.completes + 1
  end
  local on_cap = function()
    calls.capped = calls.capped + 1
  end
  return calls, process_result, process_complete, on_cap
end

describe("pickers.result_cap", function()
  it("passes the callbacks through untouched when there is no limit", function()
    local calls, pr, pc, on_cap = recorder()
    local result, complete = result_cap.wrap(pr, pc, nil, on_cap)

    assert.are.equal(pr, result)
    assert.are.equal(pc, complete)

    for i = 1, 10 do
      assert.is_nil(result { i })
    end
    complete()

    assert.are.equal(10, #calls.results)
    assert.are.equal(1, calls.completes)
    assert.are.equal(0, calls.capped)
  end)

  it("forwards every entry below the limit", function()
    local calls, pr, pc, on_cap = recorder()
    local result = result_cap.wrap(pr, pc, 5, on_cap)

    for i = 1, 4 do
      assert.is_nil(result { i })
    end

    assert.are.equal(4, #calls.results)
    assert.are.equal(0, calls.completes)
    assert.are.equal(0, calls.capped)
  end)

  it("stops the finder once the limit is reached", function()
    local calls, pr, pc, on_cap = recorder()
    local result = result_cap.wrap(pr, pc, 3, on_cap)

    assert.is_nil(result { 1 })
    assert.is_nil(result { 2 })
    assert.is_true(result { 3 })

    -- the capping entry is still shown, the finder just stops after it
    assert.are.equal(3, #calls.results)
    assert.are.equal(1, calls.completes, "capping must complete the search")
    assert.are.equal(1, calls.capped, "capping must stop the job")
  end)

  it("completes exactly once when the finder also completes after a cap", function()
    local calls, pr, pc, on_cap = recorder()
    local result, complete = result_cap.wrap(pr, pc, 2, on_cap)

    assert.is_nil(result { 1 })
    assert.is_true(result { 2 })
    complete()

    assert.are.equal(1, calls.completes)
  end)

  it("completes exactly once when a capped finder keeps pushing entries", function()
    local calls, pr, pc, on_cap = recorder()
    local result = result_cap.wrap(pr, pc, 2, on_cap)

    result { 1 }
    result { 2 }
    assert.is_true(result { 3 })
    assert.is_true(result { 4 })

    assert.are.equal(1, calls.completes)
    assert.are.equal(1, calls.capped, "the job is only stopped once")
    assert.are.equal(2, #calls.results, "entries past the cap are not processed")
  end)

  it("stops immediately without counting when the base processor stops", function()
    local calls = { completes = 0, capped = 0, seen = 0 }
    local pr = function()
      calls.seen = calls.seen + 1
      return true -- e.g. a stale find_id
    end
    local pc = function()
      calls.completes = calls.completes + 1
    end
    local on_cap = function()
      calls.capped = calls.capped + 1
    end

    local result = result_cap.wrap(pr, pc, 2, on_cap)

    assert.is_true(result { 1 })
    assert.are.equal(1, calls.seen)
    assert.are.equal(0, calls.completes, "a stale search must not be completed")
    assert.are.equal(0, calls.capped)
  end)

  it("treats a non-positive limit as no limit", function()
    local calls, pr, pc, on_cap = recorder()
    local result, complete = result_cap.wrap(pr, pc, 0, on_cap)

    assert.are.equal(pr, result)
    assert.are.equal(pc, complete)
  end)
end)
