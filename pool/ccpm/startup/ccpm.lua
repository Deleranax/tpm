-- ComputerCraft Package Manager
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

local function complete(shell, index, arg, args)
    local rtn = {}

    if index == 1 then

    end

    local frtn = {}
    for i, v in ipairs(rtn) do
        if arg == v:sub(1, arg:len()) then
            local text = v:gsub(arg, "", 1)
            table.insert(frtn, text)
        end
    end

    return frtn
end