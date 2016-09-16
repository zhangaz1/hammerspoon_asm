--- === hs._asm.enclosure.avplayer ===
---
--- Provides an AudioVisual player view element type for `hs._asm.enclosure`.
---
--- This sub-module provides a new type of view which can be assigned to the `view` attribute of and `hs._asm.enclosure` element of type `view`.  This module requires `hs._asm.enclosure` to actual display the content, but all playback selection and control is provided by this module.
---
--- Playback of remote or streaming content has not been thoroughly tested; it's not something I do very often.  However, it has been tested against http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8, which is a sample URL provided in the Apple documentation at https://developer.apple.com/library/prerelease/content/documentation/AudioVideo/Conceptual/AVFoundationPG/Articles/02_Playback.html#//apple_ref/doc/uid/TP40010188-CH3-SW4
---
--- This submodule was intended to provide an example of providing external content for use within `hs._asm.enclosure`, but has grown larger than anticipated. While it still serves as an example, I am working on a more narrowly targeted example which should be added to this repository soon.

local USERDATA_TAG = "hs._asm.enclosure.avplayer"
local module       = require(USERDATA_TAG..".internal")

-- private variables and methods -----------------------------------------

-- local _kMetaTable = {}
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

-- Return Module Object --------------------------------------------------

return module
