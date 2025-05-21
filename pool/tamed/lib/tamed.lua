-- Tamed WildCards library
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

local tamed = {}

local MAGIC_CHARS = { "%", "(", ")", ".", "+", "-", "?", "[", "^", "$" }

--- Construct a wildcard processor object, used to test a text against a wildcard pattern.
---
--- @param pattern string Wildcard pattern (string with "*").
--- @param separators string String of characters that limit wildcards expansion (e.g. for path, it is "/") or nil.
function tamed.Wildcard(pattern, separators)
    local Wildcard = {}

    pattern = pattern or ""

    -- Escape all magic characters
    for _, c in ipairs(MAGIC_CHARS) do
        pattern = string.gsub(pattern, "%"..c, function() return "%"..c end)
    end

    -- Transform the wildcard
    if separators == nil then
        pattern = string.gsub(pattern, "%*", ".+")
    else
       pattern = string.gsub(pattern, "%*", "[^"..separators.."]+")
    end

    --- Check if a string matches the wildcard pattern.
    ---
    --- @param s string String to match against.
    --- @return boolean Matching status (true if it matches, false otherwise).
    function Wildcard.matches(s)
        return string.find(s, pattern) ~= nil
    end

    return Wildcard
end

return tamed