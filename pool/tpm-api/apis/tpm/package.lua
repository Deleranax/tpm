-- TPM library
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

local package = {}

local deptree = require("/apis/deptree")
local tact = require("/apis/tact")
local turfu = require("/apis/turfu")
local storage = require("/apis/tpm/storage")
local drivers = require("/apis/tpm/drivers")

--- Retrieve all packages (from cache) that matches a certain name.
---
--- @param name string Package name pattern (Lua pattern).
--- @return table Array of package manifests.
function package.find(name)

end