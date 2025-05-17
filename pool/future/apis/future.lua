-- Future library
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

local future = {}

--- Construct a future object that need to be repeatedly polled until available.
---
--- Future object represent a value that is not yet available, but will eventually become available (with a certainty of
--- 100%, as this is not an Optional).
---
--- @param poll function Polling function, accepting nothing and returning the true and the result when available (false and nil otherwise).
function future.Future(poll)
    local Future = {}
    local available = false
    local result

    --- @return boolean State (true if pending, false otherwise)
    function Future.isPending()
        return not available
    end

    --- @return boolean State (true if available, false otherwise).
    function Future.isAvailable()
        return available
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
    function Future.poll()
        available, result = poll()
    end

    return Future
end

return future