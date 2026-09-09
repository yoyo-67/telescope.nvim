---@brief [[
--- Caps how many results a single search feeds into a picker.
---
--- Telescope scores and stores every line a finder produces, so an unfiltered
--- grep over a large tree (100k+ lines) stalls the editor in Lua long after the
--- underlying command has finished. Capping used to be the caller's job -- a
--- `| head -n N` bolted onto `vimgrep_arguments` -- but a shell pipeline is not
--- killable: telescope kills the shell, and the grep and the `head` reading it
--- survive as orphans that keep scanning. Every keystroke leaked one.
---
--- Capping here instead keeps the finder a single, killable process.
---@brief ]]

local result_cap = {}

--- Wrap a picker's result/complete callbacks so the search stops after `limit`
--- entries.
---
--- The entry that reaches the limit is still processed -- the cap is a count of
--- results kept, not a count of results dropped. Reaching it completes the
--- search (a stopped finder never calls `process_complete` itself, and a picker
--- that is never completed reports as still running forever) and calls `on_cap`
--- so the caller can stop the job that is still producing lines.
---
---@param process_result function: called per entry, truthy return stops the finder
---@param process_complete function: called once when the search is done
---@param limit number|nil: max entries to process; nil or <= 0 means no cap
---@param on_cap function|nil: called once, when the limit is reached
---@return function process_result, function process_complete
function result_cap.wrap(process_result, process_complete, limit, on_cap)
  if not limit or limit <= 0 then
    return process_result, process_complete
  end

  local count = 0
  local completed = false

  local complete_once = function(...)
    if completed then
      return
    end
    completed = true
    return process_complete(...)
  end

  local capped_result = function(entry)
    if completed then
      return true
    end

    -- A truthy return here means the picker itself is done with this search
    -- (a stale find_id, say). That is not a cap, so it must not complete it.
    if process_result(entry) then
      return true
    end

    count = count + 1
    if count < limit then
      return
    end

    complete_once()
    if on_cap then
      on_cap()
    end
    return true
  end

  return capped_result, complete_once
end

return result_cap
