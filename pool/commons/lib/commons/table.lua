-- Commons library
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

local ctable = {}

--- Insert all elements of a list into another list.
---
--- @param list table List to update.
--- @param values table List of elements to insert.
--- @return number Number of insertions.
function ctable.insertAll(list, values)
    local rtn = 0

    for _, elem in ipairs(values) do
        table.insert(list, elem)
        rtn = rtn + 1
    end

    return rtn
end

--- Remove all elements of a list from another list.
---
--- @param list table List to update.
--- @param values table List of elements to insert.
--- @return number Number of deletions.
function ctable.removeAll(list, values)
    local rtn = 0

    for _, elem in ipairs(values) do
        rtn = rtn + ctable.removeValue(list, elem)
    end

    return rtn
end

--- Insert a new value into a list if it's not already present.
---
--- @param list table List to update.
--- @param value any Value to insert.
--- @param pos number Index where to insert the value (or nil for the end).
--- @return boolean Inserted (true if it was inserted, false otherwise).
function ctable.insertUnique(list, value, pos)
    for _, elem in ipairs(list) do
        if elem == value then
            return false
        end
    end

    if pos == nil then
        table.insert(list, value)
    else
       table.insert(list, pos, value)
    end

    return true
end

--- Insert all elements of a list (if not present) into another list.
---
--- @param list table List to update.
--- @param values table List of elements to insert.
--- @return number Number of insertions.
function ctable.insertUniqueAll(list, values)
    local rtn = 0

    for _, elem in ipairs(values) do
        ctable.insertUnique(list, elem)
        rtn = rtn + 1
    end

    return rtn
end

--- Remove all occurrences of a value from a list.
---
--- @param list table List to update.
--- @param value any Value to remove.
--- @return number Number of occurrences.
function ctable.removeValue(list, value)
    local rtn = 0

    for i, elem in ipairs(list) do
        if elem == value then
            table.remove(list, i)
            rtn = rtn + ctable.removeValue(list, value)
            break
        end
    end

    return rtn
end

--- Find the index of the first occurrence of a value.
---
--- @param list table List to search in.
--- @param value any Value to search.
--- @return number Index of the value (or nil).
function ctable.find(list, value)
    for i, elem in ipairs(list) do
        if elem == value then
            return i
        end
    end

    return nil
end

--- List all keys in a table.
---
--- @param t table Table to search in.
--- @return table List of all the keys in the table.
function ctable.keys(t)
    local rtn = {}

    for key, _ in pairs(t) do
        table.insert(rtn, key)
    end

    return rtn
end

--- Copy (recursively) all entries from a table into another.
---
--- @param t table Table to update.
--- @param values table Table of values to copy.
--- @return number Number of values.
function ctable.copy(t, values)
    local rtn = 0

    for key, value in pairs(values) do
        if type(value) == "table" then
            t[key] = {}
            ctable.copy(t[key], value)
        else
            t[key] = value
        end
        rtn = rtn + 1
    end

    return rtn
end

return ctable