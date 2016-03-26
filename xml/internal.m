#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

// DTD Methods needed

// Module Functions:
// open should take a true url, not just a file
// NSXMLNode localNameForName, prefixForName
// NSXMLDTD  predefinedEntityDeclarationForName
//
// // Module Methods:
// // NSXMLNode nodesForXPath objectsForXQuery:constants:
//
// should we allow creating an xml doc from scratch?

#define USERDATA_TAG        "hs._asm.xml"
int refTable ;

#define get_objectFromUserdata(objType, L, idx) (objType*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))

#pragma mark - Support Functions and Classes

#pragma mark - Module Functions

/// hs._asm.xml.openDTD(url) -> xmlDTD object
/// Constructor
/// Returns an xmlDTD object created from the contents of the specified URL source.
///
/// Parameters:
///  * url - the url specifying the location of the DTD declarations
///
/// Returns:
///  * an xmlDTD object
static int xml_openDTD(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING | LS_TNUMBER, LS_TBREAK] ;
    luaL_checkstring(L, 1) ;
    NSXMLDTD *xmlDTD;
    NSError  *err=nil;

    NSURL *furl = [NSURL URLWithString:[skin toNSObjectAtIndex:1]];

    if (!furl) {
        return luaL_error(L, "Malformed URL %s.", lua_tostring(L, 1)) ;
    }

    xmlDTD = [[NSXMLDTD alloc] initWithContentsOfURL:furl
                                                  options:(NSXMLNodePreserveWhitespace|NSXMLNodePreserveEntities)
                                                    error:&err];
    if (err) {
        [skin pushNSObject:[err description]] ;
        return lua_error(L) ;
    }

    [skin pushNSObject:xmlDTD] ;
    return 1 ;
}

/// hs._asm.xml.openURL(url) -> xmlDocument object
/// Constructor
/// Returns an xmlDocument object created from the XML or HTML contents of the specified URL source.
///
/// Parameters:
///  * url - the url specifying the location of the XML or HTML source
///
/// Returns:
///  * an xmlDocument object
static int xml_openURL(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING | LS_TNUMBER, LS_TBREAK] ;
    luaL_checkstring(L, 1) ;
    NSXMLDocument *xmlDoc;
    NSError       *err=nil;

    NSURL         *furl = [NSURL URLWithString:[skin toNSObjectAtIndex:1]];

    if (!furl) {
        return luaL_error(L, "Malformed URL %s.", lua_tostring(L, 1)) ;
    }

    xmlDoc = [[NSXMLDocument alloc] initWithContentsOfURL:furl
                                                  options:(NSXMLNodePreserveWhitespace|NSXMLNodePreserveCDATA|NSXMLNodeLoadExternalEntitiesAlways)
                                                    error:&err];
    if (xmlDoc == nil) {
        xmlDoc = [[NSXMLDocument alloc] initWithContentsOfURL:furl
                                                      options:NSXMLDocumentTidyXML|NSXMLNodeLoadExternalEntitiesAlways
                                                        error:&err];
    }

    if (err) {
        [skin pushNSObject:[err description]] ;
        return lua_error(L) ;
    }

    [skin pushNSObject:xmlDoc] ;
    return 1 ;
}

/// hs._asm.xml.open(file) -> xmlDocument object
/// Constructor
/// Returns an xmlDocument object created from the XML or HTML contents of the file specified.
///
/// Parameters:
///  * file - the path to the file containing the XML or HTML source
///
/// Returns:
///  * an xmlDocument object
///
/// Notes:
///  * This is a wrapper for [hs._asm.xml.openURL](#openURL) which converts the specified path into a properly formatted file URL.
static int xml_open(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING | LS_TNUMBER, LS_TBREAK] ;
    luaL_checkstring(L, 1) ;
    NSString *file = [skin toNSObjectAtIndex:1] ;
    NSURL    *furl = [NSURL fileURLWithPath:[file stringByExpandingTildeInPath]];
    if (!furl) {
        return luaL_error(L, "Can't create a file URL for file %s.", [file UTF8String]) ;
    }
    lua_pop(L, 1) ;

    lua_pushcfunction(L, xml_openURL) ;
    lua_pushstring(L, [[furl absoluteString] UTF8String]) ;
    if (lua_pcall(L, 1, 1, 0) != LUA_OK)
        return lua_error(L) ;
    else
        return 1 ;
}

/// hs._asm.xml.localNameFor(qualifiedName) -> string
/// Function
/// Returns the local name of the specified qualified name
///
/// Parameters:
///  * qualifiedName - a namespace-qualifying name for a node
///
/// Returns:
///  * a string containing the local name for the specified namespace-qualifying name
///
/// Notes:
///  * for example, `hs._asm.xml.localNameFor("acme:chapter")` would return `chapter`
static int xml_localNameFor(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING | LS_TNUMBER, LS_TBREAK] ;
    luaL_checkstring(L, 1) ;
    [skin pushNSObject:[NSXMLNode localNameForName:[skin toNSObjectAtIndex:1]]] ;
    return 1 ;
}

/// hs._asm.xml.prefixFor(qualifiedName) -> string
/// Function
/// Returns the prefix of the specified qualified name
///
/// Parameters:
///  * qualifiedName - a namespace-qualifying name for a node
///
/// Returns:
///  * a string containing the prefix for the specified namespace-qualifying name
///
/// Notes:
///  * for example, `hs._asm.xml.prefixFor("acme:chapter")` would return  `acme`
static int xml_prefixFor(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING | LS_TNUMBER, LS_TBREAK] ;
    luaL_checkstring(L, 1) ;
    [skin pushNSObject:[NSXMLNode prefixForName:[skin toNSObjectAtIndex:1]]] ;
    return 1 ;
}

/// hs._asm.xml.predefinedEntityDeclaration(entityName) -> xmlDTDNode object
/// Constructor
/// Returns an xmlDTDNode object for the predefined entity specified
///
/// Parameters:
///  * entityName - the name of the predefined entity
///
/// Returns:
///  * an xmlDTDNode object for the specified predefined entity, or nil if no predefined entity with that name exists.
///
/// Notes:
///  * The five predefined entity references (or character references) are:
///    * < (less-than sign)    - with the entity name "lt"
///    * > (greater-than sign) - with the entity name "gt"
///    * & (ampersand)         - with the entity name "amp"
///    * " (quotation mark)    - with the entity name "quot"
///    * ' (apostrophe)        - with the entity name "apos"
static int xml_predefinedEntityDeclaration(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING | LS_TNUMBER, LS_TBREAK] ;
    luaL_checkstring(L, 1) ;
    NSXMLDTDNode *node = [NSXMLDTD predefinedEntityDeclarationForName:[NSString stringWithUTF8String:luaL_checkstring(L, 1)]] ;
    [skin pushNSObject:node] ;
    return 1 ;
}

#pragma mark - Common Module Methods

/// hs._asm.xml:nodeType() -> string
/// Method
/// Returns the specific NSXML class type of the object as a string.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the XML class type as a string
///
/// Notes:
///  * the possible returned values are as follows:
///    * NSXMLNode     - the base class; generally, you should not see this value, as a more specific label from the following should be returned instead.
///    * NSXMLDocument - the object represents an XML Document internalized into a logical tree structure
///    * NSXMLElement  - the object represents an element node in an XML tree structure
///    * NSXMLDTD      - the object represents a Document Type Definition
///    * NSXMLDTDNode  - the object represents an element, attribute-list, entity, or notation declaration in a Document Type Declaration
static int xml_nodeType(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    if ([obj isKindOfClass:NSClassFromString(@"NSXMLDTD")])           lua_pushstring(L, "NSXMLDTD") ;
    else if ([obj isKindOfClass:NSClassFromString(@"NSXMLDTDNode")])  lua_pushstring(L, "NSXMLDTDNode") ;
    else if ([obj isKindOfClass:NSClassFromString(@"NSXMLDocument")]) lua_pushstring(L, "NSXMLDocument") ;
    else if ([obj isKindOfClass:NSClassFromString(@"NSXMLElement")])  lua_pushstring(L, "NSXMLElement") ;
    else if ([obj isKindOfClass:NSClassFromString(@"NSXMLNode")])     lua_pushstring(L, "NSXMLNode") ;
    else                                                              lua_pushstring(L, "unknown") ;

    return 1 ;
}


/// hs._asm.xml:rootDocument() -> xmlDocument obejct
/// Method
/// Returns the NSXMLDocument object containing the root element and representing the XML document as a whole.
///
/// Parameters:
///  * None
///
/// Returns:
///  * an xmlDocument object
static int xml_rootDocument(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[obj rootDocument]] ;
    return 1 ;
}

/// hs._asm.xml:parent() -> xmlNode obejct
/// Method
/// Returns the parent node of the object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * an xmlNode object, or nil if no parent exists for this object
static int xml_parent(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[obj parent]] ;
    return 1 ;
}

/// hs._asm.xml:childAtIndex(index) -> xmlNode obejct
/// Method
/// Returns the child node at the specified index.
///
/// Parameters:
///  * index - an integer index specifying the child object to return
///
/// Returns:
///  * an xmlNode object, or nil if no child exists at that index
///
/// Notes:
///  * The returned node object can represent an element, comment, text, or processing instruction.
static int xml_childAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    lua_Integer idx = luaL_checkinteger(L, 2) ;

    if (idx < 0 || idx > (lua_Integer)[obj childCount])
        return luaL_argerror(L, 2, [[NSString stringWithFormat:@"index must be between 0 and %d", [obj childCount]] UTF8String]) ;

    @try {
        [skin pushNSObject:[obj childAtIndex:(NSUInteger)idx]] ;
    } @catch (NSException *theException) {
        [skin logError:[NSString stringWithFormat:@"%@:%@", [theException name], [theException reason]]] ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.xml:childCount() -> integer
/// Method
/// Returns the number of child nodes for the object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the number of child nodes for the object
static int xml_childCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    lua_pushinteger(L, (lua_Integer)[obj childCount]) ;
    return 1 ;
}

/// hs._asm.xml:children() -> table
/// Method
/// Returns the children of the object in a table as an array.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the children of the object in a table as an array.
static int xml_children(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[obj children]] ;
    return 1 ;
}

static int xml_nextNode(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[obj nextNode]] ;
    return 1 ;
}

static int xml_nextSibling(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[obj nextSibling]] ;
    return 1 ;
}

static int xml_previousNode(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[obj previousNode]] ;
    return 1 ;
}

static int xml_previousSibling(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[obj previousSibling]] ;
    return 1 ;
}

static int xml_xmlString(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    NSXMLNode   *obj = [skin toNSObjectAtIndex:1] ;
    lua_Integer options = NSXMLNodeOptionsNone ;

    if (lua_type(L, 2) != LUA_TNONE) options = luaL_checkinteger(L, 2) ;

    [skin pushNSObject:[obj XMLStringWithOptions:(NSUInteger)options]] ;
    return 1 ;
}

static int xml_canonicalXMLString(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSXMLNode   *obj = [skin toNSObjectAtIndex:1] ;
    BOOL        preserveComments = YES ;

    if (lua_type(L, 2) != LUA_TNONE) preserveComments = (BOOL)lua_toboolean(L, 2) ;

    [skin pushNSObject:[obj canonicalXMLStringPreservingComments:preserveComments]] ;
    return 1 ;
}

static int xml_index(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    lua_pushinteger(L, (lua_Integer)[obj index]) ;
    return 1 ;
}

static int xml_kind(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    switch ([obj kind]) {
        case NSXMLInvalidKind:               lua_pushstring(L, "invalid") ; break ;
        case NSXMLDocumentKind:              lua_pushstring(L, "document") ; break ;
        case NSXMLElementKind:               lua_pushstring(L, "element") ; break ;
        case NSXMLAttributeKind:             lua_pushstring(L, "attribute") ; break ;
        case NSXMLNamespaceKind:             lua_pushstring(L, "namespace") ; break ;
        case NSXMLProcessingInstructionKind: lua_pushstring(L, "processingInstruction") ; break ;
        case NSXMLCommentKind:               lua_pushstring(L, "comment") ; break ;
        case NSXMLTextKind:                  lua_pushstring(L, "text") ; break ;
        case NSXMLDTDKind:                   lua_pushstring(L, "DTD") ; break ;
        case NSXMLEntityDeclarationKind:     lua_pushstring(L, "entityDeclaration") ; break ;
        case NSXMLAttributeDeclarationKind:  lua_pushstring(L, "attributeDeclaration") ; break ;
        case NSXMLElementDeclarationKind:    lua_pushstring(L, "ElementDeclaration") ; break ;
        case NSXMLNotationDeclarationKind:   lua_pushstring(L, "NotationDeclaration") ; break ;
        default:                             lua_pushstring(L, "unknown") ; break ;
    }
    return 1 ;
}

static int xml_level(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    lua_pushinteger(L, (lua_Integer)[obj level]) ;
    return 1 ;
}

static int xml_name(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[obj name]] ;
    return 1 ;
}

static int xml_objectValue(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[obj objectValue]] ;
    return 1 ;
}

static int xml_stringValue(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[obj stringValue]] ;
    return 1 ;
}

static int xml_URI(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[obj URI]] ;
    return 1 ;
}

static int xml_localName(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[obj localName]] ;
    return 1 ;
}

static int xml_prefix(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[obj prefix]] ;
    return 1 ;
}

static int xml_XPath(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:[obj XPath]] ;
    return 1 ;
}

static int xml_XPathQuery(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TSTRING | LS_TNUMBER | LS_TOPTIONAL,
                    LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    NSError   *error ;
    NSString  *query = @"." ;

    if (lua_type(L, 2) != LUA_TNONE) {
        luaL_checkstring(L, 2) ;
        query = [skin toNSObjectAtIndex:2] ;
    }

    [skin pushNSObject:[obj nodesForXPath:query error:&error]] ;
    if (error) {
        lua_pop(L, 1) ;
        [skin pushNSObject:[error description]] ;
        return lua_error(L) ;
    }
    return 1 ;
}

static int xml_XQuery(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TTABLE | LS_TSTRING | LS_TNUMBER | LS_TOPTIONAL,
                    LS_TTABLE | LS_TOPTIONAL,
                    LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    NSError   *error ;
    NSString  *query = @"." ;
    NSDictionary *constants ;
    int          constIdx = 3 ;

    if ((lua_type(L, 2) != LUA_TNONE) && (lua_type(L, 2) != LUA_TTABLE)) {
        luaL_checkstring(L, 2) ;
        query = [skin toNSObjectAtIndex:2] ;
    } else {
        constIdx = 2 ;
    }

    if (lua_type(L, constIdx) != LUA_TNONE) {
        luaL_checktype(L, constIdx, LUA_TTABLE) ;
        constants = [skin toNSObjectAtIndex:constIdx] ;
    }

    [skin pushNSObject:[obj objectsForXQuery:query constants:constants error:&error]] ;
    if (error) {
        lua_pop(L, 1) ;
        [skin pushNSObject:[error description]] ;
        return lua_error(L) ;
    }
    return 1 ;
}

#pragma mark - DTD & DTDNode Module Methods

static int xml_publicID(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    if ([obj isKindOfClass:NSClassFromString(@"NSXMLDTD")])
        [skin pushNSObject:[(NSXMLDTD *)obj publicID]] ;
    else if ([obj isKindOfClass:NSClassFromString(@"NSXMLDTDNode")])
        [skin pushNSObject:[(NSXMLDTDNode *)obj publicID]] ;
    else
        return luaL_argerror(L, 1, "expected NSXMLDTD or NSXMLDTDNode") ;
    return 1 ;
}

static int xml_systemID(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    if ([obj isKindOfClass:NSClassFromString(@"NSXMLDTD")])
        [skin pushNSObject:[(NSXMLDTD *)obj systemID]] ;
    else if ([obj isKindOfClass:NSClassFromString(@"NSXMLDTDNode")])
        [skin pushNSObject:[(NSXMLDTDNode *)obj systemID]] ;
    else
        return luaL_argerror(L, 1, "expected NSXMLDTD or NSXMLDTDNode") ;
    return 1 ;
}

#pragma mark - DTD Module Methods

static int xml_elementDeclaration(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TSTRING | LS_TNUMBER,
                    LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    if ([obj isKindOfClass:NSClassFromString(@"NSXMLDTD")]) {
        luaL_checkstring(L, 2) ;
        NSXMLDTDNode *node = [(NSXMLDTD *)obj elementDeclarationForName:[NSString stringWithUTF8String:luaL_checkstring(L, 2)]] ;
        [skin pushNSObject:node] ;
    } else
        return luaL_argerror(L, 1, "expected NSXMLDTD") ;
    return 1 ;
}

static int xml_attributeElementDeclaration(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TSTRING | LS_TNUMBER,
                    LS_TSTRING | LS_TNUMBER,
                    LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    if ([obj isKindOfClass:NSClassFromString(@"NSXMLDTD")]) {
        luaL_checkstring(L, 2) ;
        luaL_checkstring(L, 3) ;
        NSXMLDTDNode *node = [(NSXMLDTD *)obj attributeDeclarationForName:[NSString stringWithUTF8String:luaL_checkstring(L, 2)]
                                                              elementName:[NSString stringWithUTF8String:luaL_checkstring(L, 3)]] ;
        [skin pushNSObject:node] ;
    } else
        return luaL_argerror(L, 1, "expected NSXMLDTD") ;
    return 1 ;
}

static int xml_entityDeclaration(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TSTRING | LS_TNUMBER,
                    LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    if ([obj isKindOfClass:NSClassFromString(@"NSXMLDTD")]) {
        NSXMLDTDNode *node = [(NSXMLDTD *)obj entityDeclarationForName:[NSString stringWithUTF8String:luaL_checkstring(L, 2)]] ;
        [skin pushNSObject:node] ;
    } else
        return luaL_argerror(L, 1, "expected NSXMLDTD") ;
    return 1 ;
}

static int xml_notationDeclaration(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TSTRING | LS_TNUMBER,
                    LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    if ([obj isKindOfClass:NSClassFromString(@"NSXMLDTD")]) {
        NSXMLDTDNode *node = [(NSXMLDTD *)obj notationDeclarationForName:[NSString stringWithUTF8String:luaL_checkstring(L, 2)]] ;
        [skin pushNSObject:node] ;
    } else
        return luaL_argerror(L, 1, "expected NSXMLDTD") ;
    return 1 ;
}

#pragma mark - DTDNode Module Methods

static int xml_isExternal(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    if ([obj isKindOfClass:NSClassFromString(@"NSXMLDTDNode")])
        lua_pushboolean(L, [(NSXMLDTDNode *)obj isExternal]) ;
    else
        return luaL_argerror(L, 1, "expected NSXMLDTDNode") ;
    return 1 ;
}

static int xml_notationName(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    if ([obj isKindOfClass:NSClassFromString(@"NSXMLDTDNode")])
        [skin pushNSObject:[(NSXMLDTDNode *)obj notationName]] ;
    else
        return luaL_argerror(L, 1, "expected NSXMLDTDNode") ;
    return 1 ;
}

static int xml_DTDKind(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    if ([obj isKindOfClass:NSClassFromString(@"NSXMLDTDNode")]) {
        switch ([(NSXMLDTDNode *)obj DTDKind]) {
          case NSXMLEntityGeneralKind:               lua_pushstring(L, "entityGeneral") ; break ;
          case NSXMLEntityParsedKind:                lua_pushstring(L, "entityParsed") ; break ;
          case NSXMLEntityUnparsedKind:              lua_pushstring(L, "entityUnparsed") ; break ;
          case NSXMLEntityParameterKind:             lua_pushstring(L, "entityParameter") ; break ;
          case NSXMLEntityPredefined:                lua_pushstring(L, "entityPredefined") ; break ;
          case NSXMLAttributeCDATAKind:              lua_pushstring(L, "attributeCDATA") ; break ;
          case NSXMLAttributeIDKind:                 lua_pushstring(L, "attributeID") ; break ;
          case NSXMLAttributeIDRefKind:              lua_pushstring(L, "attributeIDRef") ; break ;
          case NSXMLAttributeIDRefsKind:             lua_pushstring(L, "attributeIDRefs") ; break ;
          case NSXMLAttributeEntityKind:             lua_pushstring(L, "attributeEntity") ; break ;
          case NSXMLAttributeEntitiesKind:           lua_pushstring(L, "attributeEntities") ; break ;
          case NSXMLAttributeNMTokenKind:            lua_pushstring(L, "attributeNMToken") ; break ;
          case NSXMLAttributeNMTokensKind:           lua_pushstring(L, "attributeNMTokens") ; break ;
          case NSXMLAttributeEnumerationKind:        lua_pushstring(L, "attributeEnumeration") ; break ;
          case NSXMLAttributeNotationKind:           lua_pushstring(L, "attributeNotation") ; break ;
          case NSXMLElementDeclarationUndefinedKind: lua_pushstring(L, "elementDeclarationUndefined") ; break ;
          case NSXMLElementDeclarationEmptyKind:     lua_pushstring(L, "elementDeclarationEmpty") ; break ;
          case NSXMLElementDeclarationAnyKind:       lua_pushstring(L, "elementDeclarationAny") ; break ;
          case NSXMLElementDeclarationMixedKind:     lua_pushstring(L, "elementDeclarationMixed") ; break ;
          case NSXMLElementDeclarationElementKind:   lua_pushstring(L, "elementDeclarationElement") ; break ;
          default:                                   lua_pushstring(L, "unknown") ; break ;
      }
    } else
        return luaL_argerror(L, 1, "expected NSXMLDTDNode") ;
    return 1 ;
}

#pragma mark - Document Module Methods

static int xml_rootElement(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;

    if (![obj isKindOfClass:NSClassFromString(@"NSXMLDocument")])
        return luaL_argerror(L, 1, "expected NSXMLDocument") ;

    [skin pushNSObject:[(NSXMLDocument *)obj rootElement]] ;
    return 1 ;
}

static int xml_characterEncoding(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    if ([obj isKindOfClass:NSClassFromString(@"NSXMLDocument")])
        [skin pushNSObject:[(NSXMLDocument *)obj characterEncoding]] ;
    else
        return luaL_argerror(L, 1, "expected NSXMLDocument") ;
    return 1 ;
}

static int xml_DTD(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    if ([obj isKindOfClass:NSClassFromString(@"NSXMLDocument")])
        [skin pushNSObject:[(NSXMLDocument *)obj DTD]] ;
    else
        return luaL_argerror(L, 1, "expected NSXMLDocument") ;
    return 1 ;
}

static int xml_MIMEType(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    if ([obj isKindOfClass:NSClassFromString(@"NSXMLDocument")])
        [skin pushNSObject:[(NSXMLDocument *)obj MIMEType]] ;
    else
        return luaL_argerror(L, 1, "expected NSXMLDocument") ;
    return 1 ;
}

static int xml_version(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    if ([obj isKindOfClass:NSClassFromString(@"NSXMLDocument")])
        [skin pushNSObject:[(NSXMLDocument *)obj version]] ;
    else
        return luaL_argerror(L, 1, "expected NSXMLDocument") ;
    return 1 ;
}

static int xml_isStandalone(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    if ([obj isKindOfClass:NSClassFromString(@"NSXMLDocument")])
        lua_pushboolean(L, [(NSXMLDocument *)obj isStandalone]) ;
    else
        return luaL_argerror(L, 1, "expected NSXMLDocument") ;
    return 1 ;
}


static int xml_documentContentKind(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;
    if ([obj isKindOfClass:NSClassFromString(@"NSXMLDocument")]) {
        switch([(NSXMLDocument *)obj documentContentKind]) {
           case NSXMLDocumentXMLKind:   lua_pushstring(L, "XML") ; break ;
           case NSXMLDocumentXHTMLKind: lua_pushstring(L, "XHTML") ; break ;
           case NSXMLDocumentHTMLKind:  lua_pushstring(L, "HTML") ; break ;
           case NSXMLDocumentTextKind:  lua_pushstring(L, "text") ; break ;
           default:                     lua_pushstring(L, "unknown") ; break ;
        }
    } else
        return luaL_argerror(L, 1, "expected NSXMLDocument") ;
    return 1 ;
}

#pragma mark - Element Module Methods

static int xml_attributes(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;

    if (![obj isKindOfClass:NSClassFromString(@"NSXMLElement")])
        return luaL_argerror(L, 1, "expected NSXMLElement") ;

    [skin pushNSObject:[(NSXMLElement *)obj attributes]] ;
    return 1 ;
}

static int xml_namespaces(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSXMLNode *obj = [skin toNSObjectAtIndex:1] ;

    if (![obj isKindOfClass:NSClassFromString(@"NSXMLElement")])
        return luaL_argerror(L, 1, "expected NSXMLElement") ;

    [skin pushNSObject:[(NSXMLElement *)obj namespaces]] ;
    return 1 ;
}

#pragma mark - Module Constants

static int xml_nodeIOConstants(lua_State *L) {
    lua_newtable(L) ;
      lua_pushinteger(L, NSXMLNodeOptionsNone) ;                        lua_setfield(L, -2, "optionsNone") ;
      lua_pushinteger(L, NSXMLNodeIsCDATA) ;                            lua_setfield(L, -2, "isCDATA") ;
      lua_pushinteger(L, NSXMLNodeExpandEmptyElement) ;                 lua_setfield(L, -2, "expandEmptyElement") ;
      lua_pushinteger(L, NSXMLNodeCompactEmptyElement) ;                lua_setfield(L, -2, "compactEmptyElement") ;
      lua_pushinteger(L, NSXMLNodeUseSingleQuotes) ;                    lua_setfield(L, -2, "useSingleQuotes") ;
      lua_pushinteger(L, NSXMLNodeUseDoubleQuotes) ;                    lua_setfield(L, -2, "useDoubleQuotes") ;
      lua_pushinteger(L, NSXMLNodeLoadExternalEntitiesAlways) ;         lua_setfield(L, -2, "loadExternalEntitiesAlways") ;
      lua_pushinteger(L, NSXMLNodeLoadExternalEntitiesSameOriginOnly) ; lua_setfield(L, -2, "loadExternalEntitiesSameOriginOnly") ;
      lua_pushinteger(L, NSXMLNodeLoadExternalEntitiesNever) ;          lua_setfield(L, -2, "loadExternalEntitiesNever") ;
      lua_pushinteger(L, NSXMLNodePrettyPrint) ;                        lua_setfield(L, -2, "prettyPrint") ;
      lua_pushinteger(L, NSXMLNodePreserveNamespaceOrder) ;             lua_setfield(L, -2, "preserveNamespaceOrder") ;
      lua_pushinteger(L, NSXMLNodePreserveAttributeOrder) ;             lua_setfield(L, -2, "preserveAttributeOrder") ;
      lua_pushinteger(L, NSXMLNodePreserveEntities) ;                   lua_setfield(L, -2, "preserveEntities") ;
      lua_pushinteger(L, NSXMLNodePreservePrefixes) ;                   lua_setfield(L, -2, "preservePrefixes") ;
      lua_pushinteger(L, NSXMLNodePreserveCDATA) ;                      lua_setfield(L, -2, "preserveCDATA") ;
      lua_pushinteger(L, NSXMLNodePreserveWhitespace) ;                 lua_setfield(L, -2, "preserveWhitespace") ;
      lua_pushinteger(L, NSXMLNodePreserveDTD) ;                        lua_setfield(L, -2, "preserveDTD") ;
      lua_pushinteger(L, NSXMLNodePreserveCharacterReferences) ;        lua_setfield(L, -2, "preserveCharacterReferences") ;
      lua_pushinteger(L, NSXMLNodePreserveEmptyElements) ;              lua_setfield(L, -2, "preserveEmptyElements") ;
      lua_pushinteger(L, NSXMLNodePreserveQuotes) ;                     lua_setfield(L, -2, "preserveQuotes") ;
      lua_pushinteger(L, NSXMLNodePreserveAll) ;                        lua_setfield(L, -2, "preserveAll") ;
    return 1 ;
}

// static int xml_documentIOConstants(lua_State *L) {
//     lua_newtable(L) ;
//       lua_pushinteger(L, NSXMLDocumentTidyHTML) ;                      lua_setfield(L, -2, "tidyHTML") ;
//       lua_pushinteger(L, NSXMLDocumentTidyXML) ;                       lua_setfield(L, -2, "tidyXML") ;
//       lua_pushinteger(L, NSXMLDocumentValidate) ;                      lua_setfield(L, -2, "validate") ;
//       lua_pushinteger(L, NSXMLDocumentXInclude) ;                      lua_setfield(L, -2, "XInclude") ;
//       lua_pushinteger(L, NSXMLDocumentIncludeContentTypeDeclaration) ; lua_setfield(L, -2, "includeContentTypeDeclaration") ;
//     return 1 ;
// }

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int NSXMLNode_toLua(lua_State *L, id obj) {
    void** xmlPtr = lua_newuserdata(L, sizeof(obj)) ;
    *xmlPtr = (__bridge_retained void *)obj ;
    luaL_getmetatable(L, USERDATA_TAG) ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

static id toNSXMLNodeTypeFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSXMLNode *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge NSXMLNode, L, idx) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
//     NSXMLNode *obj = [skin luaObjectAtIndex:1 toClass:"NSXMLNode"] ;

    lua_pushcfunction(L, xml_nodeType) ;
    lua_pushvalue(L, 1) ;
    lua_pcall(L, 1, 1, 0) ;
    NSString *title = [skin toNSObjectAtIndex:-1] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        NSXMLNode *obj1 = [skin luaObjectAtIndex:1 toClass:"NSXMLNode"] ;
        NSXMLNode *obj2 = [skin luaObjectAtIndex:2 toClass:"NSXMLNode"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    NSXMLNode *obj = get_objectFromUserdata(__bridge_transfer NSXMLNode, L, 1) ;
    if (obj) obj = nil ;
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

// static int meta_gc(lua_State* L) {
//     [hsimageReferences removeAllIndexes];
//     hsimageReferences = nil;
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
// NSXMLNode Methods
    {"nodeType",                    xml_nodeType},
    {"rootDocument",                xml_rootDocument},
    {"parent",                      xml_parent},
    {"childAtIndex",                xml_childAtIndex},
    {"childCount",                  xml_childCount},
    {"children",                    xml_children},
    {"nextNode",                    xml_nextNode},
    {"nextSibling",                 xml_nextSibling},
    {"previousNode",                xml_previousNode},
    {"previousSibling",             xml_previousSibling},
    {"xmlString",                   xml_xmlString},
    {"canonicalXMLString",          xml_canonicalXMLString},
    {"index",                       xml_index},
    {"kind",                        xml_kind},
    {"level",                       xml_level},
    {"name",                        xml_name},
    {"objectValue",                 xml_objectValue},
    {"stringValue",                 xml_stringValue},
    {"URI",                         xml_URI},
    {"localName",                   xml_localName},
    {"prefix",                      xml_prefix},
    {"XPath",                       xml_XPath},
    {"XPathQuery",                  xml_XPathQuery},
    {"XQuery",                      xml_XQuery},

// NSXMLDTD and NSXMLDTDNode Methods
    {"publicID",                    xml_publicID},
    {"systemID",                    xml_systemID},

// NSXMLDTD Methods
    {"elementDeclaration",          xml_elementDeclaration},
    {"attributeElementDeclaration", xml_attributeElementDeclaration},
    {"entityDeclaration",           xml_entityDeclaration},
    {"notationDeclaration",         xml_notationDeclaration},

// NSXMLDTDNode Methods
    {"isExternal",                  xml_isExternal},
    {"notationName",                xml_notationName},
    {"DTDKind",                     xml_DTDKind},

// NSXMLDocument Methods
    {"rootElement",                 xml_rootElement},
    {"characterEncoding",           xml_characterEncoding},
    {"DTD",                         xml_DTD},
    {"MIMEType",                    xml_MIMEType},
    {"version",                     xml_version},
    {"isStandalone",                xml_isStandalone},
    {"documentContentKind",         xml_documentContentKind},

// NSXMLElement Methods
    {"rawAttributes",               xml_attributes},
    {"namespaces",                  xml_namespaces},

    {"__tostring",                  userdata_tostring},
    {"__eq",                        userdata_eq},
    {"__gc",                        userdata_gc},
    {NULL,                          NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"open",                        xml_open},
    {"openURL",                     xml_openURL},
    {"openDTD",                     xml_openDTD},
    {"localNameFor",                xml_localNameFor},
    {"prefixFor",                   xml_prefixFor},
    {"predefinedEntityDeclaration", xml_predefinedEntityDeclaration},
    {NULL,                          NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_xml_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    xml_nodeIOConstants(L) ; lua_setfield(L, -2, "nodeOptions") ;
//     xml_documentIOConstants(L) ; lua_setfield(L, -2, "documentOptions") ;

    [skin registerPushNSHelper:NSXMLNode_toLua           forClass:"NSXMLNode"] ;
    [skin registerLuaObjectHelper:toNSXMLNodeTypeFromLua forClass:"NSXMLNode"
                                              withUserdataMapping:USERDATA_TAG] ;

    return 1;
}
