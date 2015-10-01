--- === hs._asm.objc ===
---
--- Playing with a simplistic lua-objc bridge.
---
--- Very experimental.  Don't use or trust.  Probably forget you ever saw this.
---
--- In fact, burn any computer it has come in contact with.  When (not if) you crash Hammerspoon, it's on your own head.

local module       = require("hs._asm.objc.internal")
local log          = require("hs.logger").new("objc","warning")
module.setLogLevel = log.setLogLevel

-- private variables and methods -----------------------------------------

local _kMetaTable = {}
_kMetaTable._k = {}
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
            local width = 0
            for k,v in pairs(_kMetaTable._k[obj]) do width = width < #k and #k or width end
            for k,v in require("hs.fnutils").sortByKeys(_kMetaTable._k[obj]) do
                result = result..string.format("%-"..tostring(width).."s %s\n", k, tostring(v))
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
    return results
end

-- shortcuts for class and object message sending
local class         = hs.getObjectMetatable("hs._asm.objc.class")
local object        = hs.getObjectMetatable("hs._asm.objc.id")
class.msgSend       = module.objc_msgSend
class.msgSendSuper  = module.objc_msgSendSuper
object.msgSend      = module.objc_msgSend
object.msgSendSuper = module.objc_msgSendSuper

local protocol      = hs.getObjectMetatable("hs._asm.objc.protocol")

-- Public interface ------------------------------------------------------

class.selector = function(self, sel, alreadychecked)
    alreadychecked = alreadychecked or {}
    if alreadychecked[self] then
        log.vf("class selector search already checked: %s", self:name())
        return nil
    end
    alreadychecked[self] = true

    -- check the class itself
    log.vf("class selector search in class: %s", self:name())
    local result = self:methodList()[sel]
    if result then result = result:selector() end

    -- check its adopted protocols
    if not result then
        for k,v in pairs(self:adoptedProtocols()) do
            log.vf("class selector search in adopted protocol: %s", k)
            result = protocol.selector(v, sel, alreadychecked)
            if result then break end
        end
    end

    -- if we're not the classes metaClass, check the metaClass
    if not result and self:metaClass() then
        log.vf("class selector search in metaClass for: %s", self:name())
        result = class.selector(self:metaClass(), sel, alreadychecked)
    end

    -- check our superclass
    if not result and self:superclass() then
        log.vf("class selector search in superclass for: %s", self:name())
        result = class.selector(self:superclass(), sel, alreadychecked)
    end

    -- either we have it or we don't by now...
    return result
end

object.selector = function(self, sel)
    return class.selector(self:class(), sel)
end

protocol.selector = function(self, sel, alreadychecked)
    alreadychecked = alreadychecked or {}
    if alreadychecked[self] then
        log.vf("protocol selector search already checked: %s", self:name())
        return nil
    end
    alreadychecked[self] = true

    -- check the protocol itself
    log.vf("protocol selector search in protocol: %s", self:name())
    local entry = self:methodDescriptionList(true,true)[sel]  or -- check required and instance methods
                  self:methodDescriptionList(false,true)[sel] or -- check not-required and instance methods
                  self:methodDescriptionList(true,false)[sel] or -- check required and class methods
                  self:methodDescriptionList(false,false)[sel]   -- check not-required and class methods

    -- check its adopted protocols
    if not entry then
        for k,v in pairs(self:adoptedProtocols()) do
            log.vf("protocol selector search in adopted protocol: %s", k)
            local result = protocol.selector(v, sel, alreadychecked)
            if result then return result end
        end
    end

    -- either we have it or we don't by now...
    if entry then
        return entry.selector
    else
        return nil
    end
end

module.class = setmetatable(module.class, {
                  __call = function(_, ...) return module.class.fromString(...) end
})

module.protocol = setmetatable(module.protocol, {
                  __call = function(_, ...) return module.protocol.fromString(...) end
})

-- Return Module Object --------------------------------------------------

return module
