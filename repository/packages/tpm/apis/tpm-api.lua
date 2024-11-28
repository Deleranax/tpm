local BASE_URL = "https://raw.githubusercontent.com/Deleranax/ComputerCraft-Projects/master/"

if not _G.tpmTemp then
    _G.tpmTemp = {
        repositories = {},
        pool = {},
        installed = {}
    }
end

return {}