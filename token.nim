import strformat

type
    TokenType* = enum  
#BEGIN COMPOUND OPERATORS
        EQUALS_EQUALS#must be first
        NOT_EQUALS,#must be last
#BEGIN SINGLE OPERATORS
        LCURLY,#must be first
        RCURLY,
        EQUALS,
        SEMICOLON,#must be last
#BEGIN KEYWORDS
        LET,
        VAR,
        ENTRY,
        NULL,
#BEGIN NAMED
        IDENTIFIER,
        NAMESPACE,
        BAD,
#BEGIN LITERAL
        LITINT,
        LITFLOAT,
        LITSTRING,
const
    BEGIN_COMPOUND = EQUALS_EQUALS
    END_COMPOUND = NOT_EQUALS
    BEGIN_SINGLE = LCURLY
    END_SINGLE = SEMICOLON
    BEGIN_KEYWORD = LET
    END_KEYWORD = NULL
    BEGIN_NAMED = IDENTIFIER
    END_NAMED = BAD
    BEGIN_LITERAL = LITINT
    END_LITERAL = LITSTRING

#causes discarding error (?)
#template rangeOf(T: type): untyped = T.low .. T.high

type
    TokenKeywordType* = range[BEGIN_KEYWORD .. END_KEYWORD]
    TokenCompoundOperatorType* = range[BEGIN_COMPOUND .. END_COMPOUND]
    TokenSingleOperatorType* = range[BEGIN_SINGLE .. END_SINGLE]
    TokenNamedType* = range[BEGIN_NAMED .. END_NAMED]
    TokenLiteralType* = range[BEGIN_LITERAL .. END_LITERAL]
    Token* = object
        pos: int
        case kind: TokenType
        of TokenKeywordType.low .. TokenKeywordType.high,
           TokenCompoundOperatorType.low .. TokenCompoundOperatorType.high,
           TokenSingleOperatorType.low .. TokenSingleOperatorType.high:
            discard
        of TokenNamedType.low .. TokenNamedType.high, LITSTRING:
            text: string
        of LITINT:
            inum: int
        of LITFLOAT:
            fnum: float

const TokenNames* = [
    EQUALS_EQUALS: "==",
    NOT_EQUALS: "!=",
    
    LCURLY: "{",
    RCURLY: "}",
    EQUALS: "=",
    SEMICOLON: ";",
    
    LET: "let",
    VAR: "var",
    ENTRY: "entry",
    NULL: "null",
]

proc makeTok*(pos: int, t: TokenType): Token = Token(pos: pos, kind: t)
proc makeTok*(pos: int, t: TokenNamedType, val: string): Token = Token(pos: pos, kind: t, text: val)
proc makeTok*(pos: int, val: string): Token = Token(pos: pos, kind: LITSTRING, text: val)
proc makeTok*(pos: int, val: int): Token = Token(pos: pos, kind: LITINT, inum: val)
proc makeTok*(pos: int, val: float): Token = Token(pos: pos, kind: LITFLOAT, fnum: val)

proc `$`*(t: Token): string =
    case t.kind
    of TokenKeywordType.low .. TokenKeywordType.high,
       TokenCompoundOperatorType.low .. TokenCompoundOperatorType.high,
       TokenSingleOperatorType.low .. TokenSingleOperatorType.high:
        return fmt"({t.pos}|{t.kind}: {TokenNames[t.kind]})"
    of TokenNamedType.low .. TokenNamedType.high:
        return fmt"({t.pos}|{t.kind}: {t.text})"
    of LITINT:
        return fmt"({t.pos}|Int: {t.inum})"
    of LITFLOAT:
        return fmt"({t.pos}|Float: {t.fnum})"
    of LITSTRING:
        return fmt"({t.pos}|String: {t.text})"
