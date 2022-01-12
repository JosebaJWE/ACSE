-----------------------------------------------------------------------
--/  @file   Database.ACSE.lua
--/  @author My Self
--/
--/  @brief  Creates a prototypes database for modules to hook into the
--           game environment or alter the current ones. It also registers
--           the basic shell commands missing in the release version.
--/  @see    https://github.com/OpenNaja/ACSE
-----------------------------------------------------------------------
local global = _G
local api = global.api
local pairs = pairs
local type = type
local ipairs = ipairs
local next = global.next
local string = global.string
local table = require("Common.tableplus")
local StringUtils = require("Common.stringUtils")
local Main = require("Database.Main")
local GameDatabase = require("Database.GameDatabase")
local ACSE = module(...)

-- List of protos/managers to populate from other mods
ACSE.tParkEnvironmentProtos = {}
ACSE.tStartEnvironmentProtos = {}

-- List of lua Prefabs to populate from other mods
ACSE.tLuaPrefabs = {}

-- List of lua Components to populate from other mods
ACSE.tLuaComponents = {}

-- Definition of our own database methods
ACSE.tDatabaseMethods = {
    --/ Park environment hook
    GetParkEnvironmentProtos = function()
        return ACSE.tParkEnvironmentProtos
    end,
    --/ Starting screen environment hook
    GetStartEnvironmentProtos = function()
        return ACSE.tStartEnvironmentProtos
    end,
    --/ Starting screen environment managers
    GetStartEnvironmentManagers = function()
        return ACSE.tStartEnvironmentProtos["Managers"]
    end,
    --/ park environment managers
    GetParkEnvironmentManagers = function()
        return ACSE.tParkEnvironmentProtos["Managers"]
    end,
    --/ Lua prefabs
    GetLuaPrefabs = function()
        return ACSE.tLuaPrefabs
    end,
    --/ Lua Components
    GetLuaComponents = function()
        return ACSE.tLuaComponents
    end,
    --/ Lua prefabs
    BuildLuaPrefabs = function()
        for _sName, _tParams in pairs(ACSE.tLuaPrefabs) do
            local cPrefab = global.api.entity.CompilePrefab(_tParams, _sName)
            global.api.debug.Assert(cPrefab ~= nil, "ACSE error compiling prefab: " .. _sName)
        end
    end,
    --/ version info
    GetACSEVersionString = function()
        return api.acse.GetACSEVersionString()
    end,
    --/ have access to the tweakables
    GetAllTweakables = function()
        return api.acsedebug.GetTweakables()
    end
}

api.debug.Trace("ACSE " .. api.acse.GetACSEVersionString() .. " Running on " .. global._VERSION)

-- @brief returns true if a string is any form of number, used in EPS command
function IsNumeric(data)
    if global.type(data) == "number" then
        return true
    elseif global.type(data) ~= "string" then
        return false
    end
    local x, y = global.string.find(data, "[%d+][%.?][%d*]")
    if x and x == 1 and y == global.string.len(data) then
        return true
    end
    return false
end

-- @brief Database init
ACSE.Init = function()
    ACSE._initLuaOverrides()

    global.api.debug.Trace("ACSE:Init()")

    ACSE.tParkEnvironmentProtos = {SearchPaths = {}, Managers = {}}
    ACSE.tStartEnvironmentProtos = {SearchPaths = {}, Managers = {}}
    ACSE.tLuaPrefabs = {}

    --/ Request Starting Screen Managers from other mods
    Main.CallOnContent(
        "AddStartScreenManagers",
        function(_sName, _tParams)
            if type(_sName) == "string" and type(_tParams) == "table" then
                ACSE.tStartEnvironmentProtos["Managers"][_sName] = _tParams
            end
        end
    )

    --/ Request Park Managers from other mods
    Main.CallOnContent(
        "AddParkManagers",
        function(_sName, _tParams)
            if type(_sName) == "string" and type(_tParams) == "table" then
                ACSE.tParkEnvironmentProtos["Managers"][_sName] = _tParams
            end
        end
    )

    --/ Request Lua Prefabs from other mods
    Main.CallOnContent(
        "AddLuaPrefabs",
        function(_sName, _tParams)
            if type(_sName) == "string" and type(_tParams) == "table" then
                global.api.debug.Trace("adding prefab " .. _sName)
                global.api.debug.Assert(ACSE.tLuaPrefabs[_sName] == nil, "Duplicated Lua Prefab " .. _sName)
                ACSE.tLuaPrefabs[_sName] = _tParams
            end
        end
    )

    --/ Request Lua Components from other mods
    Main.CallOnContent(
        "AddLuaComponents",
        function(_sName, _tParams)
            if type(_sName) == "string" and type(_tParams) == "string" then
                global.api.debug.Trace("adding component: " .. _sName)
                global.api.debug.Assert(ACSE.tLuaComponents[_sName] == nil, "Duplicated Lua Component " .. _sName)
                ACSE.tLuaComponents[_sName] = _tParams
            end
        end
    )

    -- Register our own custom shell commands
    ACSE.tShellCommands = {
        api.debug.RegisterShellCommand(
            function(tEnv, tArgs)
                if #tArgs ~= 2 then
                    return false, "SetTweakable requires two arguments"
                end

                tweakable = api.acsedebug.GetDebugTweakable(tArgs[1])
                if tweakable ~= nil then
                    if tweakable.type == 22 then -- boolean
                        local stringtoboolean = {["true"] = true, ["false"] = false}
                        tArgs[2] = stringtoboolean[global.string.lower(tArgs[2])]
                    else -- numbers
                        tArgs[2] = global.tonumber(tArgs[2])
                    end
                    tweakable:SetValue(tArgs[2])
                end
            end,
            "&Set&Tweakable {string} {value}",
            "Changes the value of a tweakable.\n"
        ),
        api.debug.RegisterShellCommand(
            function(tEnv, tArgs)
                api.debug.Trace("List of Tweakables:")
                for k, v in global.pairs(api.acsedebug.tTweakables) do
                    if (tArgs[1] == nil or global.string.match(v.id, tArgs[1])) then
                        api.debug.Trace(global.tostring(v.id) .. " = " .. global.tostring(v.value))
                    end
                end
            end,
            "&List&Tweakables [{string}]",
            "Prints a list of the current tweakables and its values. Specify a filter string to limit the list.\n"
        ),
        api.debug.RegisterShellCommand(
            function(tEnv, tArgs)
                api.debug.Trace("List of Commands:")
                for k, v in global.pairs(api.acsedebug.tShellCommands) do
                    if (tArgs[1] == nil or global.string.match(k, tArgs[1])) then
                        api.debug.Trace(global.tostring(v._sCmd))
                    end
                end
            end,
            "&List&Commands [{string}]",
            "Prints a list of the current commands and its arguments. Specify a filter string to limit the list.\n"
        ),
        api.debug.RegisterShellCommand(
            function(tEnv, tArgs)
                if global.type(tArgs) == "table" and #tArgs > 0 and global.type(tArgs[1]) == "string" then
                    cmdname = global.string.lower(tArgs[1])
                    oCmd = api.acsedebug.tShellCommands[cmdname]
                    if global.type(oCmd) == "table" then
                        global.api.debug.Trace(global.tostring(oCmd._sCmd) .. "\n" .. global.tostring(oCmd._sDesc))
                    else
                        return false, "Command " .. global.tostring(tArgs[1]) .. " not found."
                    end
                else
                    return false, "Help requires a command name as argument"
                end
            end,
            "&Help {string}",
            "Displays information about a command.\n"
        ),
        api.debug.RegisterShellCommand(
            function(tEnv, tArgs)
                if #tArgs ~= 1 then
                    return false, "Loadfile requires one argument, the name of the lua file.\n"
                end

                if
                    global.pcall(
                        function()
                            global.api.debug.Trace("Loading file: " .. global.tostring(tArgs[1]))
                            local pf = global.loadfile(tArgs[1])
                            if pf ~= nil then
                                local result = pf()
                            else
                                return false, "Lua file not loaded (file not found or wrong syntax).\n"
                            end
                        end
                    )
                 then
                    -- file loaded and ran fine
                else
                    return false, "There was a problem running the Lua file."
                end
            end,
            "&Load&File {string}",
            "Loads and execute a Lua file from the game root folder, do not add path.\n"
        ),
        api.debug.RegisterShellCommand(
            function(tEnv, tArgs)
                if #tArgs ~= 1 then
                    return false, "Loadstring requires one argument. If your Lua code includes spaces, use quotes to convert to a single string.\n"
                end

                if
                    global.pcall(
                        function()
                            local luastr = "local global = _G local api = global.api " .. tArgs[1]
                            local pf = global.loadstring(luastr)
                            if pf ~= nil then
                                local result = pf()
                            else
                                return false, "Lua file not loaded (possibly wrong syntax)."
                            end
                        end
                    )
                 then
                    -- file loaded and ran fine
                else
                    return false, "There was a problem running the Lua sequence."
                end
            end,
            "Loadstring {string}",
            "Loads and execute a Lua string (no spaces).\n"
        ),
        api.debug.RegisterShellCommand(
            function(tEnv, tArgs)
                if #tArgs < 2 then
                    return false, "BindPreparedStatement requires at least two arguments: Database and prepared Statement Collection name."
                end

                -- Get access to the game database interface
                local database = global.api.database
                local dbname = tArgs[1]
                local pscol = tArgs[2]
                local readon = tArgs[3] or true

                database.SetReadOnly(dbname, readon)

                -- We need to bind our new Prepared Statement collection to the Buildings database before
                -- we can use any of its statements.
                local bSuccess = database.BindPreparedStatementCollection(dbname, pscol)
                global.api.debug.Assert(bSuccess == true, "Problem binding " .. pscol .. " to " .. dbname)
            end,
            "&Bind&P&S&Collection {string} {string} [{bool}]",
            "Binds a prepared statement collection to a database, optionally enable write mode on the database.\n"
        ),
        api.debug.RegisterShellCommand(
            function(tEnv, tArgs)
                if #tArgs < 2 then
                    return false, "ExecutePreparedSstatement requires at least two arguments: Database and prepared Statement name."
                end

                -- Get access to the game database interface
                local database = global.api.database
                local dbname = tArgs[1]
                local psname = tArgs[2]

                -- Connect the PS to the database
                local cPSInstance = database.GetPreparedStatementInstance(dbname, psname)
                if cPSInstance ~= nil then
                    for i = 3, #tArgs, 1 do
                        global.api.debug.Trace("Binding: " .. global.tostring(tArgs[i]))
                        local value = tArgs[i]
                        if IsNumeric(tArgs[i]) then
                            value = global.tonumber(value)
                        end
                        database.BindParameter(cPSInstance, global.tonumber(i - 2), value)
                    end
                    database.BindComplete(cPSInstance)
                    database.Step(cPSInstance)

                    -- @TODO: Convert this into a table we can print
                    -- @TODO: Convert result to a global value accessible later
                    local tRows = database.GetAllResults(cPSInstance, false)
                    local result = tRows or {}
                else
                    return false, "Unable to bind PreparedStatement, did you Bind the Prepared Statement collection first?"
                end
            end,
            "&Execute&Prepared&Statement {string} {string} [{value}] [{value}] [{value}] [{value}]",
            "Runs a Prepared Statement query against a database. You will need database name, PS name, and its arguments.\n"
        ),
        api.debug.RegisterShellCommand(
            function(tEnv, tArgs)
                global.api.game.Quit(tArgs[1] or false)
            end,
            "&Quit [{bool}]",
            "Quits the game. To force Quitting without prompting use true as argument.\n"
        ),
        api.debug.RegisterShellCommand(
            function(tEnv, tArgs)
                global.api.game.Quit(true)
            end,
            "QQ",
            "Force quits the game.\n"
        ),
        api.debug.RegisterShellCommand(
            function(tEnv, tArgs)
                if tArgs == nil or #tArgs ~= 1 or global.type(tArgs[1]) ~= "string" then
                    return false, "Expected exactly one string argument, the module name (or a search string).\n"
                end

                local sModuleNamePattern = (string.lower)(tArgs[1])

                -- get module list from package.loaded that contain the pattern in the name
                local tLoadedModuleNames = global.api.debug.GetListOfLoadedModuleNames()

                local tFilteredLoadedModuleNames = {}
                _pattern = string.gsub(sModuleNamePattern, "%%", "")
                for k, v in global.pairs(tLoadedModuleNames) do
                    if StringUtils.StrMatchI(v, _pattern) then
                        tFilteredLoadedModuleNames[#tFilteredLoadedModuleNames + 1] = v
                    end
                end

                local nFoundModulesCount = #tFilteredLoadedModuleNames
                if nFoundModulesCount < 1 then
                    return false, 'Couldn\'t find a loaded module matching the pattern "' .. sModuleNamePattern .. '".'
                end

                -- Locating named modules
                for i, sModuleName in ipairs(tFilteredLoadedModuleNames) do
                    if sModuleNamePattern == (string.lower)(sModuleName) then
                        tFilteredLoadedModuleNames = {sModuleName}
                    end
                end
                nFoundModulesCount = #tFilteredLoadedModuleNames

                if nFoundModulesCount > 1 then
                    local allModulesList = (table.concat)(tFilteredLoadedModuleNames, "\n")
                    return false, "Found " .. global.tostring(nFoundModulesCount) ..
                          ' loaded modules matching the pattern "' .. sModuleNamePattern ..
                          '". You need to be more specific. \nPossible modules:\n' .. allModulesList
                end

                -- load the new file and replace the Lua package system
                local newfile = global.loadfile(tFilteredLoadedModuleNames[1] .. ".lua")
                if newfile then
                    global.package.preload[ tFilteredLoadedModuleNames[1] ] = newfile
                    local a = global.require(tFilteredLoadedModuleNames[1])
                    global.package.loaded[tFilteredLoadedModuleNames[1] ] = a
                    global.package.preload[tFilteredLoadedModuleNames[1] ] = nil
                else
                    return false, "File " .. tFilteredLoadedModuleNames[1] .. ".lua not found"
                end

                -- try now reloading it
                local bOk, sErrorMessage = api.debug.ReloadModule(tFilteredLoadedModuleNames[1])
                if bOk then
                    global.api.debug.Trace("Module '" .. tFilteredLoadedModuleNames[1] .. "' reloaded successfully.\n")
                    return true
                end
                return false, sErrorMessage .. "\n"

            end,
            "&Reload&Module {string}",
            "Reloads the Lua module specified from the file system.\n"
        ),
        api.debug.RegisterShellCommand(
            function(tEnv, tArgs)
                if tArgs == nil or #tArgs ~= 1 or type(tArgs[1]) ~= "string" then
                    return false, "Expected exactly one string argument, the module name, without .lua extesion.\n"
                end

                local sModuleName = string.lower(tArgs[1])

                local newfile = global.loadfile(sModuleName .. ".lua")
                if newfile ~= nil then
                    global.package.preload[sModuleName] = newfile
                    local a = global.require(sModuleName)
                    global.package.preload[sModuleName] = nil
                else
                    return false, "Module import failed: " .. sModuleName .. ".lua not found\n"
                end
                global.api.debug.Trace("Module '" .. sModuleName .. "' imported successfully.\n")
            end,
            "&Import&File {string}",
            "Imports a lua file to the lua sandbox (do not specify .lua extension).\n"
        )
    }

end

-- @brief Environment Shutdown
ACSE.Shutdown = function()
    global.api.debug.Trace("ACSE:Shutdown()")

    -- Remove custom commands
    for i, oCommand in ipairs(ACSE.tShellCommands) do
        api.debug.UnregisterShellCommand(oCommand)
    end
    ACSE.tShellCommands = nil

    -- Restore Lua environment
    ACSE._shutdownLuaOverrides()
end

-- @brief Called when a Reinit is about to happen
ACSE.ShutdownForReInit = function()
end

-- @brief adds our custom database methods to the main game database
ACSE.AddDatabaseFunctions = function(_tDatabaseFunctions)
    for sName, fnFunction in pairs(ACSE.tDatabaseMethods) do
        _tDatabaseFunctions[sName] = fnFunction
    end
end

-- List of custom managers to force injection on the starting screen
ACSE.tStartScreenManagers = {
    ["Managers.ACSEStartScreenManager"] = {}
}

-- @brief Add our custom Manager to the starting screen
ACSE.AddStartScreenManagers = function(_fnAdd)
    local tData = ACSE.tStartScreenManagers
    for sManagerName, tParams in pairs(tData) do
        _fnAdd(sManagerName, tParams)
    end
end

-- List of custom managers to force injection on a park
ACSE.tParkManagers = {
    ["Managers.ACSEParkManager"] = {}
}

-- @brief Add our custom Manager to the starting screen
ACSE.AddParkManagers = function(_fnAdd)
    local tData = ACSE.tParkManagers
    for sManagerName, tParams in pairs(tData) do
        _fnAdd(sManagerName, tParams)
    end
end

-- @Brief Perform any custom Lua:global/api updates
ACSE._initLuaOverrides = function()
    global.api.debug.Trace("Initializing lua overrides")

    -- Perform Lua override
    local rdebug = global.api.debug
    local entity = global.api.entity
    global.api.debug = global.setmetatable(global.api.acsedebug, {__index = rdebug})
    global.api.entity = global.setmetatable(global.api.acseentity, {__index = entity})
end

-- @Brief Undo all Lua changes so the game exists gracefully
ACSE._shutdownLuaOverrides = function()
    --  Perform API/Lua clean up
    api.debug = global.getmetatable(api.debug).__index
    api.entity = global.getmetatable(api.entity).__index
end

