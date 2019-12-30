--- === hs.text ===
---
--- Stuff about the module

local USERDATA_TAG = "hs.text"
local module       = require(USERDATA_TAG..".internal")
module.utf16       = require(USERDATA_TAG..".utf16")

local textMT  = hs.getObjectMetatable(USERDATA_TAG)
local utf16MT = hs.getObjectMetatable(USERDATA_TAG..".utf16")

-- local log = require("hs.logger").new(USERDATA_TAG, require"hs.settings".get(USERDATA_TAG .. ".logLevel") or "warning")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

textMT.tostring = function(self, ...)
    return self:asEncoding(module.encodingTypes.UTF8, ...):rawData()
end

textMT.toUTF16 = function(self, ...)
    return module.utf16.new(self, ...)
end

-- string.byte (s [, i [, j]])
--
-- Returns the internal numeric codes of the characters s[i], s[i+1], ..., s[j]. The default value for i is 1; the default value for j is i. These indices are corrected following the same rules of function string.sub.
-- Numeric codes are not necessarily portable across platforms.
textMT.byte = function(self, ...)
    return self:rawData():byte(...)
end

-- utf8.codes (s)
--
-- Returns values so that the construction
--
--      for p, c in utf8.codes(s) do body end
-- will iterate over all characters in string s, with p being the position (in bytes) and c the code point of each character. It raises an error if it meets any invalid byte sequence.
utf16MT.codes = function(self)
    return function(state, index)
        if index > 0 and self:codepoint(index) > 0xFFFF then
            index = index + 2
        else
            index = index + 1
        end
        if index > #state then
            return nil
        else
            return index, self:codepoint(index)
        end
    end, self, 0
end

module.encodingTypes           = ls.makeConstantsTable(module.encodingTypes)
module.utf16.builtinTransforms = ls.makeConstantsTable(module.utf16.builtinTransforms)

-- Return Module Object --------------------------------------------------

return module
