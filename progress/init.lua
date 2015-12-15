--- === hs._asm.progress ===
---
--- A Hammerspoon module which allows the creation and manipulation of progress indicators.

local module = require("hs._asm.progress.internal")
local log    = require("hs.logger").new("progress","warning")
module.log   = log
module._registerLogForC(log)
module._registerLogForC = nil

require("hs.drawing.color")

-- private variables and methods -----------------------------------------

local _kMetaTable = {}
_kMetaTable._k = {}
_kMetaTable._t = {}
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
_kMetaTable.__tostring = function(obj)
        local result = ""
        if _kMetaTable._k[obj] then
            if _kMetaTable._t[obj] == "table" then
                local width = 0
                for k,v in pairs(_kMetaTable._k[obj]) do width = width < #k and #k or width end
                for k,v in require("hs.fnutils").sortByKeys(_kMetaTable._k[obj]) do
                    result = result..string.format("%-"..tostring(width).."s %s\n", k, tostring(v))
                end
            else
                for k,v in ipairs(_kMetaTable._k[obj]) do
                    result = result..v.."\n"
                end
            end
        else
            result = "constants table missing"
        end
        return result
    end
_kMetaTable.__metatable = _kMetaTable -- go ahead and look, but don't unset this

local _makeConstantsTable = function(theTable)
    local results = setmetatable({}, _kMetaTable)
    _kMetaTable._k[results] = theTable
    _kMetaTable._t[results] = "table"
    return results
end

local _makeConstantsArray = function(theTable)
    local results = setmetatable({}, _kMetaTable)
    _kMetaTable._k[results] = theTable
    _kMetaTable._t[results] = "array"
    return results
end

-- Public interface ------------------------------------------------------

module.size = _makeConstantsTable(module.size)
module.tint = _makeConstantsTable(module.tint)

-- Return Module Object --------------------------------------------------

return module
