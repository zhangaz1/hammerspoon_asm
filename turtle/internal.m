@import Cocoa ;
@import LuaSkin ;

@import Darwin.C.tgmath ;

// TODO:

// * add flag to skip yielding, even if in coroutine
// * add turtle to display
//       add *better* turtle to display
//   add other methods (esp color)
//   figure out WTF to do about fills
//       fill uses floodFill algorithm; probably not reasonable unless we can easily build bitmap, but look into
//       filled takes a list of commands as arguments, so can't implement with method style approach...
//           instead, two methods? 1 to mark begining of filled object, 2 to mark end -- create new path
//               with intervening paths as appended subpaths, then fill new object?
// * decide for certain about camelCase vs logo syntax
// * force refresh when window unhidden

//   add way to dump/import commandList?

//   Turtle state is only updated in drawRect. Attempts at capturing an image of the results and just redraw
//       the image if the update is from outside (e.g. move or resize of window) have crashed hard. Still,
//       the current state of affairs means even a "penUp" triggers drawRect: so that turtle state gets
//       updated and predicates can return current data.
//
//   Can we either render off screen (in another view?) and then just swap in the content of the off screen view?
//       Views may have different size, so this will have to be taken into account...
//   Or at least move turtle state updates out of drawRect: and into insertCommand:atIndex:withArguments:error:
//       and removeCommandAtIndex:? Probably mean replicating some code, but at least if view hidden during
//       updates, it should be lightning fast (and it already is pretty fast... the actual drawing *is* the
//       slowest part)

// ***** Need to move state tracking out of drawRect: anyways: *****
//
// ~~~lau
// > myC:pendownp()
// true
//
// > myC:pu():pendownp() -- drawRect: hasn't been invoked before the query occurs...
// true
//
// > myC:pendownp()
// false
// ~~~

// ***** Simplify: change insert to append, remove removeCommandAtIndex *****
//       build in separate function invoked after append; could store interim x0,y0,x1,y1 along the way
//       and (maybe) even prebuild bezier objects... this assumes they take on graphics context state
//       when stroke actually occurs. drawRect: then becomes only a replay of what's already calculated
//       and makes no changes to state at all

static const char * const USERDATA_TAG = "hs.canvas.turtle" ;
static int refTable = LUA_NOREF;
static void *myKVOContext = &myKVOContext ; // See http://nshipster.com/key-value-observing/

static NSArray *wrappedCommands ;
static NSArray *penColors ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface HSCanvasTurtleView : NSView
@property            int                    selfRefCount ;

@property (readonly) NSMutableArray         *commandList ;

@property            NSUInteger             turtleSize ;
@property            NSImageView            *turtleImageView ;

@property            CGFloat                tX ;
@property            CGFloat                tY ;
@property            CGFloat                tHeading ;
@property            BOOL                   tPenDown ;
@property            NSCompositingOperation tPenMode ;

@property            NSUInteger             pColorNumber ;
@property            NSUInteger             bColorNumber ;
@property            NSColor                *pColor ;
@property            NSColor                *bColor ;
@end

@implementation HSCanvasTurtleView {
    // things clean doesn't reset
    CGFloat                _tInitX ;
    CGFloat                _tInitY ;
    CGFloat                _tInitHeading ;
    BOOL                   _tInitPenDown ;
    NSCompositingOperation _tInitPenMode ;

    NSColor                *_pInitColor ;
    NSColor                *_bInitColor ;

    BOOL                   _neverRender ;
    NSWindow               *_parentWindow ;
    NSUInteger             _pathsValidBefore ;
}

#pragma mark - Required for Canvas compatible view -

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect] ;
    if (self) {
        _selfRefCount = 0 ;

        _neverRender  = YES ;
        _parentWindow = nil ;

        self.wantsLayer = YES ;
        [self resetTurtleView] ;
    }
    return self ;
}

// This is the default, but I put it here as a reminder since almost everything else in
// Hammerspoon *does* use a flipped coordinate system
- (BOOL)isFlipped { return NO ; }

- (void)drawRect:(__unused NSRect)dirtyRect {
    BOOL render = !_neverRender ;

    NSGraphicsContext* gc ;

    gc = [NSGraphicsContext currentContext];
    [gc saveGraphicsState];

    CGFloat xOriginOffset = self.frame.size.width / 2 ;
    CGFloat yOriginOffset = self.frame.size.height / 2 ;

    // use transform so origin shifted to center of view
    NSAffineTransform *shiftOriginToCenter = [[NSAffineTransform alloc] init] ;
    [shiftOriginToCenter translateXBy:xOriginOffset yBy:yOriginOffset] ;
    [shiftOriginToCenter concat] ;

    [_pInitColor setStroke] ;
    gc.compositingOperation = _tInitPenMode ;

    __block CGFloat                x       = _tInitX ;
    __block CGFloat                y       = _tInitY ;
    __block CGFloat                heading = _tInitHeading ;
    __block BOOL                   penDown = _tInitPenDown ;
    __block NSCompositingOperation penMode = _tInitPenMode ;

    [_commandList enumerateObjectsUsingBlock:^(NSArray *cmdDetails, NSUInteger idx, __unused BOOL *stop) {
        NSUInteger cmd        = [(NSNumber *)cmdDetails[0] unsignedIntegerValue] ;
        NSArray    *arguments = cmdDetails[1][@"arguments"] ;

        switch(cmd) {
            case  0:   // forward
            case  1:   // back
            case  4:   // setpos
            case  5:   // setxy
            case  6:   // setx
            case  7:   // sety
            case  9: { // home
                NSBezierPath *strokePath = (idx < _pathsValidBefore) ? cmdDetails[1][@"path"] : nil ;
                CGFloat initX = x ;
                CGFloat initY = y ;

                if (cmd < 2) {
                    CGFloat headingInRadians = heading * M_PI / 180 ;
                    CGFloat distance = [(NSNumber *)arguments[0] doubleValue] ;
                    if (cmd == 1) distance = -distance ;
                    x = x + distance * sin(headingInRadians) ;
                    y = y + distance * cos(headingInRadians) ;
                } else if (cmd == 4) {
                    NSArray *list = (NSArray *)arguments[0] ;
                    x = [(NSNumber *)list[0] doubleValue] ;
                    y = [(NSNumber *)list[1] doubleValue] ;
                } else if (cmd == 5) {
                    x = [(NSNumber *)arguments[0] doubleValue] ;
                    y = [(NSNumber *)arguments[1] doubleValue] ;
                } else if (cmd == 6) {
                    x = [(NSNumber *)arguments[0] doubleValue] ;
                } else if (cmd == 7) {
                    y = [(NSNumber *)arguments[0] doubleValue] ;
                } else if (cmd == 9) {
                    x       = 0.0 ;
                    y       = 0.0 ;
                    heading = 0.0 ;
                }

                if (penDown) {
                    if (!strokePath) {
                        strokePath = [NSBezierPath bezierPath] ;
                        [strokePath moveToPoint:NSMakePoint(initX, initY)] ;
                        [strokePath lineToPoint:NSMakePoint(x, y)] ;
                        cmdDetails[1][@"path"] = strokePath ;
                    }
                    if (render) [strokePath stroke] ;
                }
            } break ;

            case  2:   // left
            case  3:   // right
            case  8: { // setheading
                CGFloat angle = [(NSNumber *)arguments[0] doubleValue] ;
                if (cmd == 2) {
                    angle = heading - angle ;
                } else if (cmd == 3) {
                    angle = heading + angle ;
//              } else if (cmd == 8) {
//                  angle = angle ; // NOP since we already do this as the first line in this block
                }
                heading = fmod(angle, 360) ;
            } break ;

            case 10:   // pendown
            case 11: { // penup
                penDown = (cmd == 10) ;
            } break ;

            case 12:   // penpaint
            case 13:   // penerase
            case 14: { // penreverse
                penMode = (cmd == 14) ? NSCompositingOperationDifference :
                          (cmd == 13) ? NSCompositingOperationDestinationOut :
                                        NSCompositingOperationSourceOver ;
                if (render) gc.compositingOperation = penMode ;
                penDown = YES ;
            } break ;

            default: {
                [LuaSkin logWarn:[NSString stringWithFormat:@"%s: @drawRect - command code %lu at index %lu currently unsupported", USERDATA_TAG, cmd, idx]] ;
            }
        }
    }] ;

    _pathsValidBefore = _commandList.count ;

    _tX       = x ;
    _tY       = y ;
    _tHeading = heading ;
    _tPenDown = penDown ;
    _tPenMode = penMode ;

    if (render) [self updateTurtle] ;

    [gc restoreGraphicsState] ;
}

#pragma mark   Only required if we want to know when we are hidden
// unless we add our own methods for this, will require updates to hs.canvas to toggle this
// during skip action

- (void)viewDidHide {
    _neverRender = YES ;
}

- (void)viewDidUnhide {
    _neverRender = !((self.window != nil) && self.window.visible) ;
}


#pragma mark   Only required if we want to know when owner is visible

// All this crap just to be notified when the window changes visibility...
// See also userdata_gc which calls removeObserver

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                                                     change:(NSDictionary *)change
                                                    context:(void *)context {
    if (context == myKVOContext && [keyPath isEqualToString:@"visible"]) {
        _neverRender = !self.window.visible ;
        self.needsDisplay = YES ;
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context] ;
    }
}

- (void)removeObserver {
    if (_parentWindow) {
        [_parentWindow removeObserver:self forKeyPath:@"visible" context:myKVOContext] ;
        _parentWindow = nil ;
    }
}

- (void)viewDidMoveToWindow {
    if (self.window) {
        if (!_parentWindow) {
            _parentWindow = self.window ;
            [_parentWindow addObserver:self forKeyPath:@"visible" options:0 context:myKVOContext] ;
        }
        _neverRender = !self.window.visible ;
    } else {
        [self removeObserver] ;
        _neverRender = YES ;
    }
}

#pragma mark - HSTurtleView Specific Methods -

- (void)resetTurtleView {
    _tX           = 0.0 ;
    _tY           = 0.0 ;
    _tHeading     = 0.0 ;
    _tPenDown     = YES ;
    _tPenMode     = NSCompositingOperationSourceOver ;

    _turtleSize      = 45 ;
    _turtleImageView = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, _turtleSize, _turtleSize)] ;

    _turtleImageView.image          = [NSImage imageNamed:NSImageNameTouchBarColorPickerFont] ;
    _turtleImageView.imageScaling   = NSImageScaleProportionallyUpOrDown ;
    _turtleImageView.imageAlignment =  NSImageAlignCenter ;
    [self addSubview:_turtleImageView] ;
    [self updateTurtle] ;

    _pColorNumber = 0 ;
    _bColorNumber = 7 ;
    _pColor       = penColors[_pColorNumber][1] ;
    _bColor       = penColors[_bColorNumber][1] ;

    [self resetForClean] ;
}

- (void)resetForClean {
    _tInitX       = _tX ;
    _tInitY       = _tY ;
    _tInitHeading = _tHeading ;
    _tInitPenDown = _tPenDown ;
    _tInitPenMode = _tPenMode ;

    _pInitColor   = _pColor ;
    _bInitColor   = _bColor ;

    _commandList      = [NSMutableArray array] ;
    _pathsValidBefore = 0 ;

    self.layer.backgroundColor = _bColor.CGColor ;
    self.needsDisplay = YES ;
}

- (void)updateTurtle {
    CGFloat xOriginOffset = self.frame.size.width / 2 ;
    CGFloat yOriginOffset = self.frame.size.height / 2 ;

    _turtleImageView.frameCenterRotation = 0 ;
    _turtleImageView.frame = NSMakeRect(
        xOriginOffset + _tX - _turtleSize / 2,
        yOriginOffset + _tY - _turtleSize / 2,
        _turtleSize,
        _turtleSize
    ) ;
    _turtleImageView.frameCenterRotation = -_tHeading ;
    _turtleImageView.needsDisplay = YES ;
}

- (BOOL)validateCommand:(NSUInteger)cmd withArguments:(nullable NSArray *)arguments
                                                error:(NSError * __autoreleasing *)error {
    NSUInteger cmdCount = wrappedCommands.count ;
    NSString *errMsg = nil ;

    if (cmd < cmdCount) {
        NSArray    *cmdDetails      = wrappedCommands[cmd] ;
        NSString   *cmdName         = cmdDetails[0] ;
        NSUInteger expectedArgCount = [(NSNumber *)cmdDetails[3] unsignedIntegerValue] ;
        NSUInteger actualArgCount   = (arguments) ? arguments.count : 0 ;

        if (expectedArgCount == actualArgCount) {
            if (expectedArgCount > 0) {
                for (NSUInteger i = 0 ; i < expectedArgCount ; i++) {
                    NSString *expectedArgType = cmdDetails[4 + i] ;
                    if ([expectedArgType isKindOfClass:[NSString class]]) {
                        if ([expectedArgType isEqualToString:@"number"]) {
                            if (![(NSObject *)arguments[i] isKindOfClass:[NSNumber class]]) {
                                errMsg = [NSString stringWithFormat:@"expected %@ for argument %lu of %@", expectedArgType, (i + 1), cmdName] ;
                                break ;
                            }
                        } else if ([expectedArgType isEqualToString:@"string"]) {
                            if (![(NSObject *)arguments[i] isKindOfClass:[NSString class]]) {
                                errMsg = [NSString stringWithFormat:@"expected %@ for argument %lu of %@", expectedArgType, (i + 1), cmdName] ;
                                break ;
                            }
                        } else {
                            errMsg = [NSString stringWithFormat:@"invalid definition for %@: argument type %@ not supported", cmdName, expectedArgType] ;
                            break ;
                        }
                    } else if ([expectedArgType isKindOfClass:[NSArray class]]) {
                        NSArray *list = arguments[i] ;
                        if (![list isKindOfClass:[NSArray class]]) {
                            errMsg = [NSString stringWithFormat:@"expected table for argument %lu of %@", (i + 1), cmdName] ;
                            break ;
                        }

                        NSArray *expectedTableArgTypes = (NSArray *)expectedArgType ;
                        for (NSUInteger j = 0 ; i < expectedTableArgTypes.count ; j++) {
                            expectedArgType = expectedTableArgTypes[j] ;
                            if ([expectedArgType isKindOfClass:[NSString class]]) {
                                if ([expectedArgType isEqualToString:@"number"]) {
                                    if (![(NSObject *)list[j] isKindOfClass:[NSNumber class]]) {
                                        errMsg = [NSString stringWithFormat:@"expected %@ for argument %lu, index %lu of %@", expectedArgType, (i + 1), (j + 1), cmdName] ;
                                        break ;
                                    }
                                } else if ([expectedArgType isEqualToString:@"string"]) {
                                    if (![(NSObject *)list[j] isKindOfClass:[NSString class]]) {
                                        errMsg = [NSString stringWithFormat:@"expected %@ for argument %lu, index %lu of %@", expectedArgType, (i + 1), (j + 1), cmdName] ;
                                        break ;
                                    }
                                } else {
                                    errMsg = [NSString stringWithFormat:@"invalid definition for %@: argument type %@ in table not supported", cmdName, expectedArgType] ;
                                    break ;
                                }
                            } else {
                                errMsg = [NSString stringWithFormat:@"invalid definition for %@: argument type %@ in table not supported", cmdName, [expectedArgType className]] ;
                                break ;
                            }
                        }
                        if (errMsg) break ;
                    } else {
                        errMsg = [NSString stringWithFormat:@"invalid definition for %@: argument type %@ not supported", cmdName, [expectedArgType className]] ;
                        break ;
                    }
                }
            }
        } else {
            errMsg = [NSString stringWithFormat:@"%@ requires %lu arguments but %lu were found", cmdName, expectedArgCount, actualArgCount] ;
        }
    } else {
        errMsg = @"undefined command number specified" ;
    }

    if (errMsg) {
        if (error) {
            *error = [NSError errorWithDomain:(NSString * _Nonnull)[NSString stringWithUTF8String:USERDATA_TAG]
                                         code:-1
                                     userInfo:@{ NSLocalizedDescriptionKey : errMsg }] ;
        }
        return NO ;
    }
    return YES ;
}

// NOTE: Uses Objective-C indexing, but negative numbers are from end (e.g. -1 is last object)
- (BOOL)insertCommand:(NSUInteger)cmd atIndex:(NSInteger)idx
                                withArguments:(nullable NSArray *)arguments
                                        error:(NSError * __autoreleasing *)error {
    NSUInteger count = _commandList.count ;
    if (idx < 0) idx = (NSInteger)count + idx ;
    BOOL isGood = (idx >= 0 && idx <= (NSInteger)count) ;

    if (!isGood) {
        if (error) {
            *error = [NSError errorWithDomain:(NSString * _Nonnull)[NSString stringWithUTF8String:USERDATA_TAG]
                                         code:-1
                                     userInfo:@{ NSLocalizedDescriptionKey : @"index out of range" }] ;
        }
    } else {
        isGood = [self validateCommand:cmd withArguments:arguments error:error] ;
    }

    if (isGood) {
        NSArray *newCommand = @[ @(cmd), [NSMutableDictionary dictionary] ] ;
        if (arguments) newCommand[1][@"arguments"] = arguments ;
        [_commandList insertObject:newCommand atIndex:(NSUInteger)idx] ;
        _pathsValidBefore = (NSUInteger)idx ;
// as long as drawRect: is where turtle state gets updated, we always need to rerun it...
//         self.needsDisplay = (idx < (NSInteger)count) || [(NSNumber *)(wrappedCommands[cmd][2]) boolValue] ;
        self.needsDisplay = YES ;
    }

    return isGood ;
}

// NOTE: Uses Objective-C indexing, but negative numbers are from end (e.g. -1 is last object)
- (void)removeCommandAtIndex:(NSInteger)idx {
    NSUInteger count = _commandList.count ;
    if (idx < 0) idx = (NSInteger)count + idx ;
    if (idx >= 0 && idx < (NSInteger)count) {
// as long as drawRect: is where turtle state gets updated, we always need to rerun it...
//         if (idx == (NSInteger)(count - 1)) {
//             NSUInteger lastCommand = [(NSNumber *)(_commandList.lastObject[0]) unsignedIntegerValue] ;
//             self.needsDisplay = [(NSNumber *)(wrappedCommands[lastCommand][2]) boolValue] ;
//         } else {
//             self.needsDisplay = YES ;
//         }
        self.needsDisplay = YES ;

        [_commandList removeObjectAtIndex:(NSUInteger)idx] ;
        _pathsValidBefore = (NSUInteger)idx ;
    }
}

@end

#pragma mark - Module Functions

static int turtle_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    NSRect frameRect = (lua_gettop(L) == 1) ? [skin tableToRectAtIndex:1] : NSMakeRect(0, 0, 200, 200) ;
    HSCanvasTurtleView *newView = [[HSCanvasTurtleView alloc] initWithFrame:frameRect] ;

    if (newView) {
        [skin pushNSObject:newView] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods

static int turtle_parentView(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:turtleCanvas.superview withOptions:LS_NSDescribeUnknownTypes] ;
    return 1 ;
}

static int turtle_turtleImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA | LS_TOPTIONAL, "hs.image", LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:turtleCanvas.turtleImageView.image] ;
    } else {
        NSImage *newTurtle = [skin toNSObjectAtIndex:2] ;
        turtleCanvas.turtleImageView.image = newTurtle ;
        [turtleCanvas updateTurtle] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int turtle_turtleSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, (lua_Integer)turtleCanvas.turtleSize) ;
    } else {
        lua_Integer newSize = lua_tointeger(L, 2) ;
        if (newSize < 1) newSize = 1 ;
        turtleCanvas.turtleSize = (NSUInteger)newSize ;
        [turtleCanvas updateTurtle] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int turtle_commandCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    lua_pushinteger(L, (lua_Integer)turtleCanvas.commandList.count) ;
    return 1 ;
}

static int turtle_removeCommandAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;
    lua_Integer        idx           = lua_tointeger(L, 2) ;

    NSUInteger count = turtleCanvas.commandList.count ;

    if (idx < 0) idx = (NSInteger)count + 1 + idx ;
    if (idx > 0 && idx <= (NSInteger)count) {
        [turtleCanvas removeCommandAtIndex:(idx - 1)] ;
    } else {
        // error generation is being done by lua wrapper
        lua_pushstring(L, "index out of bounds") ;
    }
    return 1 ;
}

static int turtle_insertCommandAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER,
                    LS_TNUMBER | LS_TINTEGER | LS_TNIL,
                    LS_TBREAK | LS_TVARARG] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;
    lua_Integer        command       = lua_tointeger(L, 2) ;
    lua_Integer        idx           = (lua_type(L, 3) == LUA_TNUMBER) ? lua_tointeger(L, 3) : 0 ;

    int argCount = lua_gettop(L) - 3 ;

    NSUInteger count = turtleCanvas.commandList.count ;

    if (idx == 0) idx = (NSInteger)count + 1 ;       // zero appends to end
    if (idx < 0)  idx = (NSInteger)count + 1 + idx ; // negative is counted from end

    if (idx > 0 && idx <= (NSInteger)(count + 1)) {
        NSArray *arguments = nil ;

        if (argCount > 0) {
            NSMutableArray *argAccumulator = [NSMutableArray arrayWithCapacity:(NSUInteger)argCount] ;
            for (int i = 0 ; i < argCount ; i++) [argAccumulator addObject:[skin toNSObjectAtIndex:(4 + i)]] ;
            arguments = [argAccumulator copy] ;
        }

        NSError *errMsg  = nil ;
        BOOL    wasAdded = [turtleCanvas insertCommand:(NSUInteger)command
                                               atIndex:(idx - 1)
                                         withArguments:arguments
                                                 error:&errMsg] ;

        if (errMsg) {
            [skin pushNSObject:errMsg.localizedDescription] ;
            // this shouldn't be possible, but we don't want to keep anything that generated an error
            if (wasAdded) [turtleCanvas removeCommandAtIndex:-1] ;
        } else {
//             turtleCanvas.needsDisplay = YES ;
            lua_pushvalue(L, 1) ;
        }
    } else {
        // error generation is being done by lua wrapper
        lua_pushstring(L, "index out of bounds") ;
    }
    return 1 ;
}

static int turtle_pos(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    lua_newtable(L) ;
    lua_pushnumber(L, turtleCanvas.tX) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    lua_pushnumber(L, turtleCanvas.tY) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    return 1 ;
}

static int turtle_xcor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    lua_pushnumber(L, turtleCanvas.tX) ;
    return 1 ;
}

static int turtle_ycor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    lua_pushnumber(L, turtleCanvas.tY) ;
    return 1 ;
}

static int turtle_heading(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    lua_pushnumber(L, turtleCanvas.tHeading) ;
    return 1 ;
}

static int turtle_clean(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    [turtleCanvas resetForClean] ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int turtle_clearscreen(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    turtleCanvas.tX       = 0.0 ;
    turtleCanvas.tY       = 0.0 ;
    turtleCanvas.tHeading = 0.0 ;
    return turtle_clean(L) ;
}

static int turtle_shownp(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, !turtleCanvas.turtleImageView.hidden) ;
    return 1 ;
}

static int turtle_pendownp(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, turtleCanvas.tPenDown) ;
    return 1 ;
}

static int turtle_penmode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

// this is a stupid warning to have to supress since I included a default... it makes sense
// if I don't, but... CLANG is muy muy loco when all warnings are turned on...
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wswitch-enum"
    switch(turtleCanvas.tPenMode) {
        case NSCompositingOperationSourceOver:     lua_pushstring(L, "paint") ; break ;
        case NSCompositingOperationDestinationOut: lua_pushstring(L, "erase") ; break ;
        case NSCompositingOperationDifference:     lua_pushstring(L, "reverse") ; break ;
        default:
            [skin pushNSObject:[NSString stringWithFormat:@"** unknown compositing mode: %lu", turtleCanvas.tPenMode]] ;
    }
#pragma clang diagnostic pop

    return 1 ;
}

static int turtle_showturtle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    turtleCanvas.turtleImageView.hidden = NO ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int turtle_hideturtle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasTurtleView *turtleCanvas = [skin toNSObjectAtIndex:1] ;

    turtleCanvas.turtleImageView.hidden = YES ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

// Probably to be wrapped, if implemented
    // 6.1 Turtle Motion
        //   arc

    // 6.3 Turtle and Window Control
        //   wrap
        //   window
        //   fence
        //   fill
        //   filled
        //   label
        //   setlabelheight
        //   textscreen
        //   fullscreen
        //   splitscreen
        //   setscrunch
        //   refresh
        //   norefresh

    // 6.5 Pen and Background Control
        //   penpaint
        //   penerase
        //   penreverse
        //   setpencolor
        //   setpalette
        //   setpensize
        //   setpenpattern
        //   setpen
        //   setbackground

// Probably defined in here, if implemented
    // 6.2 Turtle Motion Queries
        //   scrunch

    // 6.4 Turtle and Window Queries
        //   screenmode
        //   turtlemode
        //   labelsize

    // 6.6 Pen Queries
        //   penmode
        //   pencolor
        //   palette
        //   pensize
        //   pen
        //   background

// Not Sure Yet
    // 6.7 Saving and Loading Pictures
        //   savepict
        //   loadpict
        //   epspict
    // 6.8 Mouse Queries
        //   mousepos
        //   clickpos
        //   buttonp
        //   button

#pragma mark - Module Constants

static int turtle_CommandsToBeWrapped(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin pushNSObject:wrappedCommands] ;
//     lua_newtable(L) ;
//
//     [wrappedCommands enumerateObjectsUsingBlock:^(NSArray *entry, NSUInteger idx, __unused BOOL *stop) {
//         NSString *commandName = entry[0] ;
//         lua_pushinteger(L, (lua_Integer)idx) ; lua_setfield(L, -2, commandName.UTF8String) ;
//     }] ;
    return 1 ;
}

static int turtle_assignPenColorsFromLua(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE, LS_TBREAK] ;
    penColors = [skin toNSObjectAtIndex:1] ;
    return 0 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSCanvasTurtleView(lua_State *L, id obj) {
    HSCanvasTurtleView *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSCanvasTurtleView *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

id toHSCanvasTurtleViewFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSCanvasTurtleView *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSCanvasTurtleView, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSCanvasTurtleView *obj = [skin luaObjectAtIndex:1 toClass:"HSCanvasTurtleView"] ;

    NSSize viewSize = obj.frame.size ;
    CGFloat maxAbsX = viewSize.width / 2 ;
    CGFloat maxAbsY = viewSize.height / 2 ;
    NSString *title = [NSString stringWithFormat:@"X ∈ [%.2f, %.2f], Y ∈ [%.2f, %.2f]",
        -maxAbsX, maxAbsX, -maxAbsY, maxAbsY] ;

    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSCanvasTurtleView *obj1 = [skin luaObjectAtIndex:1 toClass:"HSCanvasTurtleView"] ;
        HSCanvasTurtleView *obj2 = [skin luaObjectAtIndex:2 toClass:"HSCanvasTurtleView"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSCanvasTurtleView *obj = get_objectFromUserdata(__bridge_transfer HSCanvasTurtleView, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
//             LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            [obj removeObserver] ;
            [obj removeFromSuperview] ;
            obj = nil ;
        }
    }
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {

    {"pos",             turtle_pos},
    {"xcor",            turtle_xcor},
    {"ycor",            turtle_ycor},
    {"heading",         turtle_heading},
    {"clean",           turtle_clean},
    {"clearscreen",     turtle_clearscreen},
    {"showturtle",      turtle_showturtle},
    {"hideturtle",      turtle_hideturtle},
    {"shownp",          turtle_shownp},
    {"pendownp",        turtle_pendownp},
    {"penmode",         turtle_penmode},

    {"_cmdCount",       turtle_commandCount},
    {"_insertCmdAtIdx", turtle_insertCommandAtIndex},
    {"_removeCmdAtIdx", turtle_removeCommandAtIndex},
    {"_turtleImage",    turtle_turtleImage},
    {"_turtleSize",     turtle_turtleSize},
    {"_canvas",         turtle_parentView},

    {"__tostring",      userdata_tostring},
    {"__eq",            userdata_eq},
    {"__gc",            userdata_gc},
    {NULL,              NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",          turtle_new},

    {"_shareColors", turtle_assignPenColorsFromLua},

    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs_canvas_turtle_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;

    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSCanvasTurtleView         forClass:"HSCanvasTurtleView"];
    [skin registerLuaObjectHelper:toHSCanvasTurtleViewFromLua forClass:"HSCanvasTurtleView"
                                                   withUserdataMapping:USERDATA_TAG];

    wrappedCommands = @[
        // name            synonyms                              visual  #args type(s)
        @[ @"forward",     @[ @"fd" ],                           @(YES), @(1), @"number" ],
        @[ @"back",        @[ @"bk" ],                           @(YES), @(1), @"number" ],
        @[ @"left",        @[ @"lt" ],                           @(NO),  @(1), @"number" ],
        @[ @"right",       @[ @"rt" ],                           @(NO),  @(1), @"number" ],
        @[ @"setpos",      @[ @"setPos" ],                       @(YES), @(1), @[ @(2), @"number", @"number"]],
        @[ @"setxy",       @[ @"setXY" ],                        @(YES), @(2), @"number", @"number"],
        @[ @"setx",        @[ @"setX" ],                         @(YES), @(1), @"number"],
        @[ @"sety",        @[ @"setY" ],                         @(YES), @(1), @"number"],
        @[ @"setheading",  @[ @"seth", @"setH", @"setHeading" ], @(NO),  @(1), @"number"],
        @[ @"home",        @[],                                  @(YES), @(0) ],
        @[ @"pendown",     @[ @"pd", @"penDown" ],               @(NO),  @(0) ],
        @[ @"penup",       @[ @"pu", @"penUp" ],                 @(NO),  @(0) ],
        @[ @"penpaint",    @[ @"ppt", @"penPaint" ],             @(NO),  @(0) ],
        @[ @"penerase",    @[ @"pe", @"penErase" ],              @(NO),  @(0) ],
        @[ @"penreverse",  @[ @"px", @"penReverse" ],            @(NO),  @(0) ],
    //     @"arc",
    //     @"wrap",
    //     @"window",
    //     @"fence",
    //     @"fill",
    //     @"filled",
    //     @"label",
    //     @"setlabelheight",
    //     @"textscreen",
    //     @"fullscreen",
    //     @"splitscreen",
    //     @"setscrunch",
    //     @"refresh",
    //     @"norefresh",
    //     @"setpencolor",
    //     @"setpalette",
    //     @"setpensize",
    //     @"setpenpattern",
    //     @"setpen",
    //     @"setbackground",
    ] ;

    turtle_CommandsToBeWrapped(L) ; lua_setfield(L, -2, "_wrappedCommands") ;

    return 1;
}
