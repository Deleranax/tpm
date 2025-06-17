-- CCPM library
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

local drivers = {}

-- Load the drivers
for _, elem in ipairs(fs.find("/ccpm/drivers/*")) do
    local name = string.sub(1, -4, fs.name(elem))
    drivers[name] = require("ccpm.drivers.".. name)
end

-- Added to make it compatible with onlineRequire
if next(drivers) == nil then
    drivers.github = require("ccpm.drivers.github")
end

return drivers