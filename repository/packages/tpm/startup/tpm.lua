local tpm = require("/apis/tpm-api")
shell.setPath(shell.path()..":/programs/:/programs/http/")

tpm.reloadDatabase()

local function completion(shell, index, arg, args)
    local rtn = {}

    if index == 1 then
        rtn = {"help ", "update ", "upgrade ", "list ", "show ", "install ", "reinstall ", "remove ", "clean "}
    elseif index >= 2 then
        if (args[2] == "install" and args[3] == nil) or (args[2] == "show" and args[3] == "remote" and args[4] == nil) then
            for i, v in ipairs(tpm.getPackageList()) do
                table.insert(rtn, v.." ")
            end
        elseif ((args[2] == "remove" or args[2] == "reinstall") and args[3] == nil) or (args[2] == "show" and args[3] == "local" and args[4] == nil) then
            for i, v in ipairs(tpm.getInstalledList()) do
                table.insert(rtn, v.." ")
            end
        elseif (args[2] == "list" or args[2] == "show") and args[3] == nil then
            rtn = {"local ", "remote "}
        end
    end

    if arg == "" then
        return rtn
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

shell.setCompletionFunction("programs/tpm.lua", completion)