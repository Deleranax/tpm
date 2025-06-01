-- Spinny library
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

local spinny = {}

local ctable = require("lib.commons.table")

local function loop(list, index)
    if index then
        if list[index] then
            return index + 1, list[index]
        end
    end

    return 2, list[1]
end

--- Construct a spinner object.
---
--- @param frames table List of frames.
--- @param term table Terminal to use.
--- @param x number X position of the spinner (or nil to use current pos).
--- @param y number y position of the spinner (or nil to use current pos).
--- @return table Spinner object.
function spinny.Spinner(frames, term, x, y)
    local Spinner = {}

    do
        local _x, _y = term.getCursorPos()

        x = x or _x
        y = y or _y
    end

    local index

    --- Progress the spinner.
    function Spinner.progress()
        local chr
        index, chr = loop(frames, index)

        term.setCursorPos(x, y)
        term.write(chr)
    end

    --- Set terminal to the position of the spinner.
    function Spinner.go()
        term.setCursorPos(x, y)
    end

    return Spinner
end

--- Create a spinner from bytes list.
---
--- @param term table Terminal to use.
--- @param x number X position of the spinner (or nil to use current pos).
--- @param y number y position of the spinner (or nil to use current pos).
--- @return table Spinner object.
function spinny.fromBytes(bytes, term, x, y)
    return spinny.Spinner(ctable.map(bytes, string.char), term, x, y)
end

--- Create a dot spinner.
---
--- @param term table Terminal to use.
--- @param x number X position of the spinner (or nil to use current pos).
--- @param y number y position of the spinner (or nil to use current pos).
--- @return table Spinner object.
function spinny.dot0(term, x, y)
    return spinny.fromBytes({
        129, 131, 130, 138, 136, 140, 132, 133
    }, term, x, y)
end

--- Create a dot spinner.
---
--- @param term table Terminal to use.
--- @param x number X position of the spinner (or nil to use current pos).
--- @param y number y position of the spinner (or nil to use current pos).
--- @return table Spinner object.
function spinny.dot1(term, x, y)
    return spinny.fromBytes({
        131, 138, 140, 133
    }, term, x, y)
end

--- Create a dot spinner.
---
--- @param term table Terminal to use.
--- @param x number X position of the spinner (or nil to use current pos).
--- @param y number y position of the spinner (or nil to use current pos).
--- @return table Spinner object.
function spinny.dot2(term, x, y)
    return spinny.fromBytes({
        142, 141, 135, 139
    }, term, x, y)
end

--- Create a dot spinner.
---
--- @param term table Terminal to use.
--- @param x number X position of the spinner (or nil to use current pos).
--- @param y number y position of the spinner (or nil to use current pos).
--- @return table Spinner object.
function spinny.dot3(term, x, y)
    return spinny.fromBytes({
        142, 141, 135, 139
    }, term, x, y)
end

--- Create a dot spinner.
---
--- @param term table Terminal to use.
--- @param x number X position of the spinner (or nil to use current pos).
--- @param y number y position of the spinner (or nil to use current pos).
--- @return table Spinner object.
function spinny.dot3(term, x, y)
    return spinny.fromBytes({
        144, 152, 153,
    }, term, x, y)
end

--- Create a triangle spinner.
---
--- @param term table Terminal to use.
--- @param x number X position of the spinner (or nil to use current pos).
--- @param y number y position of the spinner (or nil to use current pos).
--- @return table Spinner object.
function spinny.tri0(term, x, y)
    return spinny.fromBytes({
        16, 31, 17, 30
    }, term, x, y)
end

return spinny