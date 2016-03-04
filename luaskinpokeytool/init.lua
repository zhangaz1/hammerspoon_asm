--- === hs._asm.luaskinpokeytool ===
---
--- Access LuaSkin directly from Hammerspoon to examine things like registered conversion functions, etc.
---
--- This is probably a very bad idea.
---
--- If you're not comfortable poking around in the Hammerspoon and LuaSkin source code, this probably won't be of any use or interest.
---
--- **THIS MODULE IS NOT THREAD SAFE!!!**
--- If you use this module to examine or modify a LuaSkin object outside of it's primary thread (the application thread for Hammerspoon's LuaSkin object or the `hs._asm.luathread` instance for a LuaSkinThread object) and there is any lua activity currently occurring on that thread, that thread's lua state *may* become inconsistent.
---
--- You have been warned!  This is purely for experimental and informational purposes.  And because I'm curious just how far I can push things to see what's actually happening under the hood.  But if you use this and break anything, it's on you, not me.  Best bet is just to not use it.  Unless you're curious.  Or crazy.  It helps to be both.
---
--- I'm hoping it will help with tracking some things down during `hs._asm.luathread` development and *should* work in both environments... we'll see...
---
--- You're welcome to see if you can get any use out of it as well, but remember, we're dealing directly with the very object which maintains the Lua state for all of Hammerspoon.  Earth shattering kabooms are not out of the question...
---
--- "This will all end in tears, I Just know it..." -- Marvin / Alan Rickman

local USERDATA_TAG = "hs._asm.luaskinpokeytool"
local module       = require(USERDATA_TAG..".internal")
local methodTable  = hs.getObjectMetatable(USERDATA_TAG)

-- private variables and methods -----------------------------------------

local _kMetaTable = {}
_kMetaTable._k = setmetatable({}, {__mode = "k"})
_kMetaTable._t = setmetatable({}, {__mode = "k"})
_kMetaTable.__index = function(obj, key)
        if _kMetaTable._k[obj] then
            if _kMetaTable._k[obj][key] then
                return _kMetaTable._k[obj][key]
            else
                for k,v in pairs(_kMetaTable._k[obj]) do
                    if v == key then return k end
                end
            end
        end
        return nil
    end
_kMetaTable.__newindex = function(obj, key, value)
        error("attempt to modify a table of constants",2)
        return nil
    end
_kMetaTable.__pairs = function(obj) return pairs(_kMetaTable._k[obj]) end
_kMetaTable.__len = function(obj) return #_kMetaTable._k[obj] end
_kMetaTable.__tostring = function(obj)
        local result = ""
        if _kMetaTable._k[obj] then
            local width = 0
            for k,v in pairs(_kMetaTable._k[obj]) do width = width < #tostring(k) and #tostring(k) or width end
            for k,v in require("hs.fnutils").sortByKeys(_kMetaTable._k[obj]) do
                if _kMetaTable._t[obj] == "table" then
                    result = result..string.format("%-"..tostring(width).."s %s\n", tostring(k),
                        ((type(v) == "table") and "{ table }" or tostring(v)))
                else
                    result = result..((type(v) == "table") and "{ table }" or tostring(v)).."\n"
                end
            end
        else
            result = "constants table missing"
        end
        return result
    end
_kMetaTable.__metatable = _kMetaTable -- go ahead and look, but don't unset this

local _makeConstantsTable
_makeConstantsTable = function(theTable)
    if type(theTable) ~= "table" then
        local dbg = debug.getinfo(2)
        local msg = dbg.short_src..":"..dbg.currentline..": attempting to make a '"..type(theTable).."' into a constant table"
        if module.log then module.log.ef(msg) else print(msg) end
        return theTable
    end
    for k,v in pairs(theTable) do
        if type(v) == "table" then
            local count = 0
            for a,b in pairs(v) do count = count + 1 end
            local results = _makeConstantsTable(v)
            if #v > 0 and #v == count then
                _kMetaTable._t[results] = "array"
            else
                _kMetaTable._t[results] = "table"
            end
            theTable[k] = results
        end
    end
    local results = setmetatable({}, _kMetaTable)
    _kMetaTable._k[results] = theTable
    local count = 0
    for a,b in pairs(theTable) do count = count + 1 end
    if #theTable > 0 and #theTable == count then
        _kMetaTable._t[results] = "array"
    else
        _kMetaTable._t[results] = "table"
    end
    return results
end

-- Public interface ------------------------------------------------------

module.logLevels          = _makeConstantsTable(module.logLevels)
module.checkArgumentTypes = _makeConstantsTable(module.checkArgumentTypes)
module.conversionOptions  = _makeConstantsTable(module.conversionOptions)
module.luaConstants       = _makeConstantsTable(module.luaConstants)

module.logVerbose    = function(...)
    return module.classLogMessage(module.logLevels.LS_LOG_VERBOSE, ...)
end
module.logDebug      = function(...)
    return module.classLogMessage(module.logLevels.LS_LOG_DEBUG, ...)
end
module.logError      = function(...)
    return module.classLogMessage(module.logLevels.LS_LOG_ERROR, ...)
end
module.logInfo       = function(...)
    return module.classLogMessage(module.logLevels.LS_LOG_INFO, ...)
end
module.logWarn       = function(...)
    return module.classLogMessage(module.logLevels.LS_LOG_WARN, ...)
end
module.logBreadcrumb = function(...)
    return module.classLogMessage(module.logLevels.LS_LOG_BREADCRUMB, ...)
end

methodTable.logVerbose    = function(self, ...)
    return methodTable.logMessage(self, module.logLevels.LS_LOG_VERBOSE, ...)
end
methodTable.logDebug      = function(self, ...)
    return methodTable.logMessage(self, module.logLevels.LS_LOG_DEBUG, ...)
end
methodTable.logError      = function(self, ...)
    return methodTable.logMessage(self, module.logLevels.LS_LOG_ERROR, ...)
end
methodTable.logInfo       = function(self, ...)
    return methodTable.logMessage(self, module.logLevels.LS_LOG_INFO, ...)
end
methodTable.logWarn       = function(self, ...)
    return methodTable.logMessage(self, module.logLevels.LS_LOG_WARN, ...)
end
methodTable.logBreadcrumb = function(self, ...)
    return methodTable.logMessage(self, module.logLevels.LS_LOG_BREADCRUMB, ...)
end

-- Return Module Object --------------------------------------------------

return module