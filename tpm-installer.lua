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
    ["/apis/tpm/repository"] = "https://raw.githubusercontent.com/Deleranax/tpm/main/pool/tpm-api/apis/tpm/repository.lua",
    ["/apis/tpm/package"] = "https://raw.githubusercontent.com/Deleranax/tpm/main/pool/tpm-api/apis/tpm/package.lua",
    ["/apis/tpm/storage"] = "https://raw.githubusercontent.com/Deleranax/tpm/main/pool/tpm-api/apis/tpm/storage.lua",
    ["/apis/tpm/drivers"] = "https://raw.githubusercontent.com/Deleranax/tpm/main/pool/tpm-api/apis/tpm/drivers.lua",
    ["/apis/tpm/drivers/github"] = "https://raw.githubusercontent.com/Deleranax/tpm/main/pool/tpm-driver-github/apis/tpm/drivers/github.lua",
    ["/apis/sha256"] = "https://raw.githubusercontent.com/Deleranax/tpm/main/pool/crypt/apis/sha256.lua",
    ["/apis/deptree"] = "https://raw.githubusercontent.com/Deleranax/tpm/main/pool/deptree/apis/deptree.lua",
    ["/apis/tact"] = "https://raw.githubusercontent.com/Deleranax/tpm/main/pool/tact/apis/tact.lua",
    ["/apis/turfu"] = "https://raw.githubusercontent.com/Deleranax/tpm/main/pool/turfu/apis/turfu.lua"
}

local function onlineRequire(path)
    local url = PATH_TABLE[path]

    if url == nil then
        return nil, "no remote "..path
    end
    write("Downloading "..path.."... ")

    local response, message = http.get(url, { ["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36"})

    if response == nil then
        error("Cannot download library: "..message)
    end

    print("Done.")

    return load(response.readAll(), path, "t", _ENV)
end

table.insert(package.loaders, 2, onlineRequire)

print()

local tpm = require("/apis/tpm")

local future = tpm.addRepositories("Deleranax/tpm")

print()
write("Resolving dependencies")

repeat
    future.poll()
    write(".")
until future.isAvailable()

print(" Done.")

local result = future.result()

if next(result.errors) then
    for _, err in ipairs(result.errors) do
        print(err)
    end

    return
end

print()
print("You are about to install the following repositories:")

local trsact = result.transaction

for _, data in ipairs(trsact.actions()) do
    print("- "..data.identifier)
end

print()
print("Press any key to continue...")

read()

local function before(rollback, _, repo)
    print(textutils.serialize(repo))
    if rollback then
        write("Removing "..repo.identifier.."...")
    end
    write("Installing "..repo.identifier.."...")
end

local function after(_, _, _)
    print(" Done.")
end

trsact.setHandlers({ before = before, after = after })

local ok, errors = trsact.apply()

print()

if not ok then
    print("Errors:")
    for _, err in ipairs(errors) do
        print(err)
    end

    return
end

print("Done.")