@import Cocoa ;
@import LuaSkin ;

// NOTE: Should only contain methods which can be applied to all NSControll based elements
//
//       These will be made available to any element which sets _inheritController in its luaopen_* function,
//       so enything which should be kept to a subset of such elements should be coded in the relevant element
//       files and not here.
//
//       If an element file already defines a method that is named here, the existing method will be used for
//       that element -- it will not be replaced by the common method.

/// === hs._asm.guitk.element._controller ===
///
/// Common methods inherited by elements which act as controls. Generally these are elements which are manipulated directly by the user to supply information or trigger a desired action.
///
/// Elements which inherit these methods are:
///  * hs._asm.guitk.element.button
///  * hs._asm.guitk.element.colorwell
///  * hs._asm.guitk.element.datepicker
///  * hs._asm.guitk.element.image
///  * hs._asm.guitk.element.textfield
///
/// macOS Developer Note: Understanding this is not required for use of the methods provided by this submodule, but for those interested, some of the elements provided under `hs._asm.guitk.element` are subclasses of the macOS NSControl class; macOS methods which belong to NSControl and are not overridden or superseded by more specific or appropriate element specific methods are defined here so that they can be used by all elements which share this common ancestor.
static const char * const USERDATA_TAG = "hs._asm.guitk.element._controller" ;

static NSDictionary *CONTROL_SIZE ;
static NSDictionary *CONTROL_TINT ;
static NSDictionary *TEXT_ALIGNMENT ;

#pragma mark - Common NSController Methods

static void defineInternalDictionaryies() {
    CONTROL_SIZE = @{
        @"regular" : @(NSControlSizeRegular),
        @"small"   : @(NSControlSizeSmall),
        @"mini"    : @(NSControlSizeMini),
    } ;

    CONTROL_TINT = @{
        @"default"  : @(NSDefaultControlTint),
        @"blue"     : @(NSBlueControlTint),
        @"graphite" : @(NSGraphiteControlTint),
        @"clear"    : @(NSClearControlTint),
    } ;

    TEXT_ALIGNMENT = @{
        @"left"      : @(NSTextAlignmentLeft),
        @"center"    : @(NSTextAlignmentCenter),
        @"right"     : @(NSTextAlignmentRight),
        @"justified" : @(NSTextAlignmentJustified),
        @"natural"   : @(NSTextAlignmentNatural),
    } ;
}

/// hs._asm.guitk.element._controller:textAlignment([alignment]) -> elementObject | current value
/// Method
/// Get or set the alignment of text which is displayed by the element, often as a label or description.
///
/// Parameters:
///  * `alignment` - an optional string specifying the alignment of the text being displayed by the element. Valid strings are as follows:
///    * "left"      - Align text along the left edge
///    * "center"    - Align text equally along both sides of the center line
///    * "right"     - Align text along the right edge
///    * "justified" - Fully justify the text so that the last line in a paragraph is natural aligned
///    * "natural"   - Use the default alignment associated with the current locale. The default alignment for left-to-right scripts is "left", and the default alignment for right-to-left scripts is "right".
///
/// Returns:
///  * if an argument is provided, returns the elementObject userdata; otherwise returns the current value
static int control_textAlignment(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared]  ;
    [skin checkArgs:LS_TANY, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_type(L, 1) != LUA_TUSERDATA) {
        return luaL_error(L, "ERROR: incorrect type '%s' for argument 1 (expected userdata)", lua_typename(L, lua_type(L, 1))) ;
    }
    NSControl *control = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *alignment = TEXT_ALIGNMENT[key] ;
        if (alignment) {
            control.alignment = [alignment unsignedIntegerValue] ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[TEXT_ALIGNMENT allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        NSNumber *alignment = @(control.alignment) ;
        NSArray *temp = [TEXT_ALIGNMENT allKeysForObject:alignment];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized control tint %@ -- notify developers", USERDATA_TAG, alignment]] ;
            lua_pushnil(L) ;
        }
    }
    return 1;
}

/// hs._asm.guitk.element._controller:controlTint([tint]) -> elementObject | current value
/// Method
/// Get or set the tint for the element
///
/// Parameters:
///  * `tint` - an optional string specifying the tint of the element's visual components.  Valid strings are as follows:
///    * "default"
///    * "blue"
///    * "graphite"
///    * "clear"
///
/// Returns:
///  * if an argument is provided, returns the elementObject userdata; otherwise returns the current value
///
/// Notes:
///  * This method of providing differentiation between elements was more prominent in earlier versions of macOS and may have little or no effect on most visual elements in the current os.
static int control_controlTint(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared]  ;
    [skin checkArgs:LS_TANY, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_type(L, 1) != LUA_TUSERDATA) {
        return luaL_error(L, "ERROR: incorrect type '%s' for argument 1 (expected userdata)", lua_typename(L, lua_type(L, 1))) ;
    }
    NSControl *control = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *controlTint = CONTROL_TINT[key] ;
        if (controlTint) {
            control.cell.controlTint = [controlTint unsignedIntegerValue] ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[CONTROL_TINT allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        NSNumber *controlTint = @(control.cell.controlTint) ;
        NSArray *temp = [CONTROL_TINT allKeysForObject:controlTint];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized control tint %@ -- notify developers", USERDATA_TAG, controlTint]] ;
            lua_pushnil(L) ;
        }
    }
    return 1;
}

/// hs._asm.guitk.element._controller:controlSize([size]) -> elementObject | current value
/// Method
/// Get or set the level of details in terms of the expected size of the element
///
/// Parameters:
///  * `size` - an optional string specifying the size, in a general way, necessary to properly display the element.  Valid strings are as follows:
///    * "regular" - present the element in its normal default size
///    * "small"   - present the element in a more compact form; for example when a windows toolbar offers the "Use small size" option.
///    * "mini"    - present the element in an even smaller form
///
/// Returns:
///  * if an argument is provided, returns the elementObject userdata; otherwise returns the current value
///
/// Notes:
///  * The exact effect this has on each element is type specific and may change the look of the element in other ways as well, such as reducing or removing borders for buttons -- the intent is provide a differing level of detail appropriate to the chosen element size; it is still incumbent upon you to select an appropriate sized font or frame size to take advantage of the level of detail provided.
static int control_controlSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared]  ;
    [skin checkArgs:LS_TANY, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_type(L, 1) != LUA_TUSERDATA) {
        return luaL_error(L, "ERROR: incorrect type '%s' for argument 1 (expected userdata)", lua_typename(L, lua_type(L, 1))) ;
    }
    NSControl *control = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *controlSize = CONTROL_SIZE[key] ;
        if (controlSize) {
            control.controlSize = [controlSize unsignedIntegerValue] ;
//             [control sizeToFit] ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[CONTROL_SIZE allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        NSNumber *controlSize = @(control.controlSize) ;
        NSArray *temp = [CONTROL_SIZE allKeysForObject:controlSize];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized control size %@ -- notify developers", USERDATA_TAG, controlSize]] ;
            lua_pushnil(L) ;
        }
    }
    return 1;
}

static int control_highlighted(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_type(L, 1) != LUA_TUSERDATA) {
        return luaL_error(L, "ERROR: incorrect type '%s' for argument 1 (expected userdata)", lua_typename(L, lua_type(L, 1))) ;
    }
    NSControl *control = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, control.highlighted) ;
    } else {
        control.highlighted = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int control_enabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_type(L, 1) != LUA_TUSERDATA) {
        return luaL_error(L, "ERROR: incorrect type '%s' for argument 1 (expected userdata)", lua_typename(L, lua_type(L, 1))) ;
    }
    NSControl *control = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, control.enabled) ;
    } else {
        control.enabled = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int control_font(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared]  ;
    [skin checkArgs:LS_TANY, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_type(L, 1) != LUA_TUSERDATA) {
        return luaL_error(L, "ERROR: incorrect type '%s' for argument 1 (expected userdata)", lua_typename(L, lua_type(L, 1))) ;
    }
    NSControl *control = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:control.font] ;
    } else {
        control.font = [skin luaObjectAtIndex:2 toClass:"NSFont"] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int control_continuous(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_type(L, 1) != LUA_TUSERDATA) {
        return luaL_error(L, "ERROR: incorrect type '%s' for argument 1 (expected userdata)", lua_typename(L, lua_type(L, 1))) ;
    }
    NSControl *control = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, control.continuous) ;
    } else {
        control.continuous = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}


#pragma mark - Hammerspoon/Lua Infrastructure

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"font",          control_font},
    {"highlight",     control_highlighted},
    {"enabled",       control_enabled},
    {"controlSize",   control_controlSize},
    {"controlTint",   control_controlTint},
    {"textAlignment", control_textAlignment},
    {"continuous",    control_continuous},
    {NULL,            NULL}
};

int luaopen_hs__asm_guitk_element__controller(lua_State* L) {
    defineInternalDictionaryies() ;

    LuaSkin *skin = [LuaSkin shared] ;
    [skin registerLibrary:moduleLib metaFunctions:nil] ; // or module_metaLib

    [skin pushNSObject:@[
        @"font",
        @"highlight",
        @"enabled",
        @"controlTint",
        @"controlSize",
        @"textAlignment",
        @"continuous",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;

    return 1;
}
