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

local PATH_TABLE = {
    ["/apis/tpm"] = "https://raw.githubusercontent.com/Deleranax/tpm/main/pool/tpm-api/apis/tpm.lua",
    ["/apis/tpm/drivers/github"] = "https://raw.githubusercontent.com/Deleranax/tpm/main/pool/tpm-driver-github/apis/tpm/drivers/github.lua",
    ["/apis/sha256"] = "https://raw.githubusercontent.com/Deleranax/tpm/main/pool/crypt/apis/sha256.lua",
    ["/apis/deptree"] = "https://raw.githubusercontent.com/Deleranax/tpm/main/pool/deptree/apis/deptree.lua",
    ["/apis/tact"] = "https://raw.githubusercontent.com/Deleranax/tpm/main/pool/tact/apis/tact.lua",
    ["/apis/future"] = "https://raw.githubusercontent.com/Deleranax/tpm/main/pool/future/apis/future.lua"
}

local cache = {}

local localRequire = _G.require

local function onlineRequire(path)
    local url = PATH_TABLE[path]

    if url == nil then
        return localRequire(path)
    end

    if cache[path] == nil then
        write("Downloading "..fs.getName(path).."... ")

        local response, message = http.get(url)

        if response == nil then
            error("Cannot download library"..message)
        end

        cache[path] = loadstring(response.readAll())

        print("Done.")
    else
        print("Using cached library "..fs.getName(path)..".")
    end

    return cache[path]()
end

-- Change require with our method
_G.require = onlineRequire

local tpm = onlineRequire("/apis/tpm")

tpm.addRepositories("Deleranax/tpm")

-- Change back require with original require
_G.require = localRequire