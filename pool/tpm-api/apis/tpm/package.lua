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

--- Retrieve all packages (from cache or store) that matches a certain name.
---
--- @param pattern string Package name pattern (Lua pattern).
--- @param store boolean Search in store (true if it should, false or nil otherwise).
--- @return table Array of package manifests.
function package.find(pattern, store)
    local result = {}

    local pool = storage.cache

    if store then
        pool = storage.store
    end

    for repo_name, repo in pairs(storage.cache) do
        for pack_name, pack in pairs(repo.packages) do
            if string.find(pattern, pack_name) then
                local manifest = {}

                -- Copy table
                for key, val in pairs(repo) do
                    manifest[key] = val
                end

                table.insert(result, manifest)
            end
        end
    end

    return result
end