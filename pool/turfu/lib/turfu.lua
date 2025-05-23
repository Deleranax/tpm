-- Turfu library
-- Copyright (C) 2025 Deleranax
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.

local turfu = {}

local ctable = require("commons.table")

--- Construct a future object that need to be repeatedly polled until available.
---
--- Future object represent a value that is not yet available, but will eventually become available (with a certainty of
--- 100%, as this is not an Optional). The provided poll function will never be called after it has returned true.
---
--- @param poll function Polling function, accepting nothing and returning true and the result when available (false and nil otherwise).
function turfu.Future(poll)
    local Future = {}
    local available = false
    local result

    --- @return boolean True if pending (false otherwise).
    function Future.isPending()
        return not available
    end

    --- @return boolean True if available (false otherwise).
    function Future.isAvailable()
        return available == true
    end

    --- Get the result.
    ---
    --- Note that this function will return nil when the result is not available, BUT the result can be nil.
    ---
    --- @return any Result (or nil).
    function Future.result()
        return result
    end

    --- Poll the future.
    ---
    --- @return boolean True and result when available (false and nil otherwise).
    function Future.poll()
        if not available then
            available, result = poll()
        end

        return available == true, result
    end

    return Future
end

--- Transform a for-each loop into a future object.
---
--- This function is designed to be used with pairs/ipairs. (e.g., by replace the three first argument with the result
--- of pairs or ipairs: map(ipairs(list), fnc)).
---
--- @param iter function Iterator, accepting the list and an index and returning a value and the next index (e.g. next).
--- @param list table List to iterate on.
--- @param initial any Initial index (e.g. 0 or nil).
--- @param fnc function Loop body, accepting an index and a value, returning a value.
--- @return table A Future object, eventually returning a table of the result (indexed with the iterator's provided index).
function turfu.foreach(iter, list, initial, fnc)

    local index = initial
    local results = {}

    local function poll()
        local input
        index, input = iter(list, index)

        if index == nil then
            return true, results
        else
           results[index] = fnc(index, input)
        end
    end

    return turfu.Future(poll)
end

--- Merge futures into a single future, eventually returning a merged result.
---
--- The futures will be executed in the exact same order they are provided.
---
--- @param merge function Merging function, accepting a list of the results (indexed in the same way the futures were provided) and returning a result.
--- @vararg table List of futures to merge.
--- @return table A Future object, eventually returning the result from the merging function.
function turfu.merge(merge, ...)
    local futures = {...}
    local results = {}

    local index = 1

    local function poll()
        local available

        available, results[index] = futures[index].poll()

        if available then
            index = index + 1

            if futures[index] == nil then
                return true, merge(results)
            end
        end

        return false
    end

    return turfu.Future(poll)
end

--- Concatenate futures into a single future, eventually returning a list of results.
---
--- The futures will be executed in the exact same order they are provided.
---
--- @vararg table List of futures to concatenate.
--- @return table A Future object, eventually returning a list of the results (indexed in the same way the futures were provided) and returning a result.
function turfu.concat(...)
    local function merge(results)
        return results
    end

    return turfu.merge(merge, ...)
end

--- Map a future result, using a mapping function that will be applied on the result when available.
---
--- @param future table Future to map.
--- @param map function Mapping function, accepting the result of the future and returning a new result.
--- @return table A Future object, eventually returning a mapped result.
function turfu.map(future, map)
    local function poll()
        local available, result = future.poll()

        if available then
            return true, map(result)
        else
            return false
        end
    end

    return turfu.Future(poll)
end

--- Sort a list in place (using QuickSort at a macro level, and "table.sort" at micro level).
---
--- @param list table List to sort.
--- @param comp function Comparison function (same as "table.sort").
--- @param limit number Limit, below which the "table.sort" algorithm will be used instead of QuickSort (or nil for default value).
--- @return table A Future object, eventually returning nil.
function turfu.sort(list, comp, limit)

    limit = limit or 5

    if #list <= limit then
        local function poll()
            local _list = {}

            ctable.insertAll(_list, list)
            table.sort(_list, comp)

            return true, _list
        end

        return turfu.Future(poll)
    end

    local listA = {}
    local listB = {}

    local pivot = list[#list]

    local function divide(index, val)
        if index == #list then
            return
        end

        if (comp(val, pivot)) then
            table.insert(listA, val)
        else
            table.insert(listB, val)
        end
    end

    local function clear(index, val)
        list[index] = nil
    end

    local function merge(_, val)
        table.insert(list, val)
    end

    local function insertPivot()
        table.insert(list, pivot)
        return true
    end

    local function finish(_)
        return nil
    end

    return turfu.merge(
        finish,
        turfu.foreach(ipairs(list), divide),
        turfu.sort(listA, comp, limit),
        turfu.sort(listB, comp, limit),
        turfu.foreach(ipairs(list), clear),
        turfu.foreach(ipairs(listA), merge),
        turfu.Future(insertPivot),
        turfu.foreach(ipairs(listB), merge)
    )
end

return turfu