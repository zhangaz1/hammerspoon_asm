--- === hs._asm.lua ===
---
--- Spawn new lua instances from within Hammerspoon

local USERDATA_TAG = "hs._asm.luathread"
local module       = require(USERDATA_TAG..".internal")
local internal     = hs.getObjectMetatable(USERDATA_TAG)

-- private variables and methods -----------------------------------------

local threadInitFile = package.searchpath(USERDATA_TAG.."._init", package.path)
module._assignments({
    initfile  = threadInitFile,
    configdir = hs.configdir,
    path      = package.path,
    cpath     = package.cpath,
})
module._assignments = nil -- should only be called once, then never again

-- local _kMetaTable = {}
-- -- planning to experiment with using this with responses to functional queries... and I
-- -- don't want to keep loose generated data hanging around
-- _kMetaTable._k = setmetatable({}, {__mode = "k"})
-- _kMetaTable._t = setmetatable({}, {__mode = "k"})
-- _kMetaTable.__index = function(obj, key)
--         if _kMetaTable._k[obj] then
--             if _kMetaTable._k[obj][key] then
--                 return _kMetaTable._k[obj][key]
--             else
--                 for k,v in pairs(_kMetaTable._k[obj]) do
--                     if v == key then return k end
--                 end
--             end
--         end
--         return nil
--     end
-- _kMetaTable.__newindex = function(obj, key, value)
--         error("attempt to modify a table of constants",2)
--         return nil
--     end
-- _kMetaTable.__pairs = function(obj) return pairs(_kMetaTable._k[obj]) end
-- _kMetaTable.__len = function(obj) return #_kMetaTable._k[obj] end
-- _kMetaTable.__tostring = function(obj)
--         local result = ""
--         if _kMetaTable._k[obj] then
--             local width = 0
--             for k,v in pairs(_kMetaTable._k[obj]) do width = width < #tostring(k) and #tostring(k) or width end
--             for k,v in require("hs.fnutils").sortByKeys(_kMetaTable._k[obj]) do
--                 if _kMetaTable._t[obj] == "table" then
--                     result = result..string.format("%-"..tostring(width).."s %s\n", tostring(k),
--                         ((type(v) == "table") and "{ table }" or tostring(v)))
--                 else
--                     result = result..((type(v) == "table") and "{ table }" or tostring(v)).."\n"
--                 end
--             end
--         else
--             result = "constants table missing"
--         end
--         return result
--     end
-- _kMetaTable.__metatable = _kMetaTable -- go ahead and look, but don't unset this
--
-- local _makeConstantsTable
-- _makeConstantsTable = function(theTable)
--     if type(theTable) ~= "table" then
--         local dbg = debug.getinfo(2)
--         local msg = dbg.short_src..":"..dbg.currentline..": attempting to make a '"..type(theTable).."' into a constant table"
--         if module.log then module.log.ef(msg) else print(msg) end
--         return theTable
--     end
--     for k,v in pairs(theTable) do
--         if type(v) == "table" then
--             local count = 0
--             for a,b in pairs(v) do count = count + 1 end
--             local results = _makeConstantsTable(v)
--             if #v > 0 and #v == count then
--                 _kMetaTable._t[results] = "array"
--             else
--                 _kMetaTable._t[results] = "table"
--             end
--             theTable[k] = results
--         end
--     end
--     local results = setmetatable({}, _kMetaTable)
--     _kMetaTable._k[results] = theTable
--     local count = 0
--     for a,b in pairs(theTable) do count = count + 1 end
--     if #theTable > 0 and #theTable == count then
--         _kMetaTable._t[results] = "array"
--     else
--         _kMetaTable._t[results] = "table"
--     end
--     return results
-- end

-- Public interface ------------------------------------------------------

internal.sharedTable = function(self)
    local _sharedTable = {}
    return setmetatable(_sharedTable, {
        __index    = function(t, k) return self:get(k) end,
        __newindex = function(t, k, v) self:set(k, v) end,
        __pairs    = function(t)
            local keys, values = self:keys(), {}
            for k, v in ipairs(keys) do values[v] = self:get(v) end
            return function(t, i)
                i = table.remove(keys, 1)
                if i then
                    return i, values[i]
                else
                    return nil
                end
            end, _sharedTable, nil
        end,
        __len      = function(t)
            local len, pos = 0, 1
            while self:get(pos) do
                len = pos
                pos = pos + 1
            end
            return len
        end,
        __metatable = "shared data:"..self:name()
    })
end

-- Return Module Object --------------------------------------------------

return module