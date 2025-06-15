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

local util = {}

--- Add a caching mechanism to a function.
--- @param fn function Function to wrap, accepting a single argument, returning a single value (not nil).
--- @return function A wrapper around "fn" accepting the same argument, returning the same value.
function util.cacheFn(fn)
    local cache = {}

    return function(arg)
        if not cache[arg] then
            cache[arg] = fn(arg)
        end

        return cache[arg]
    end
end

return util