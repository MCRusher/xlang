import strformat

type
    TokenType* = enum  
#BEGIN COMPOUND OPERATORS
        EQUALS_EQUALS,#must be first
        LESS_EQUALS,
        GREATER_EQUALS,
        DEREF,
        ARROW,
        NAMESPACE,
        NOT_EQUALS,#must be last
#BEGIN SINGLE OPERATORS
        LCURLY,#must be first
        RCURLY,
        LBRACK,
        RBRACK,
        LPAREN,
        RPAREN,
        EQUALS,
        LESS,
        GREATER,
        ADD,
        SUB,
        MUL,
        DIV,
        MOD,
        REF,
        DOT,
        COLON,
        COMMA,
        SEMICOLON,#must be last
#BEGIN KEYWORDS
        LET,#must be first
        VAR,
        ENTRY,
        NOT,
        FUN,
        USE,
        IMPL,
        FOR,
        TEMPLATE,
        RETURN,
        STRUCT,
        PUBLIC,
        TRAIT,
        IMPORT,
        NULL,#must be last
#BEGIN NAMED
        IDENTIFIER,#must be first
        BAD,#must be last
#BEGIN LITERAL
        LITINT,#must be first
        LITFLOAT,
        LITSTRING,#must be first
#END_LITERAL
        EOT,#end of tokens
const #for clarity
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
        case kind*: TokenType
        of TokenKeywordType.low .. TokenKeywordType.high,
           TokenCompoundOperatorType.low .. TokenCompoundOperatorType.high,
           TokenSingleOperatorType.low .. TokenSingleOperatorType.high, EOT:
            discard
        of TokenNamedType.low .. TokenNamedType.high, LITSTRING:
            text: string
        of LITINT:
            inum: int
        of LITFLOAT:
            fnum: float

const TokenNames* = [
    EQUALS_EQUALS: "==",
    LESS_EQUALS: "<=",
    GREATER_EQUALS: ">=",
    DEREF: ".*",
    ARROW: "->",
    NAMESPACE: "::",
    NOT_EQUALS: "!=",
    
    LCURLY: "{",
    RCURLY: "}",
    LBRACK: "[",
    RBRACK: "]",
    LPAREN: "(",
    RPAREN: ")",
    EQUALS: "=",
    LESS: "<",
    GREATER: ">",
    ADD: "+",
    SUB: "-",
    MUL: "*",
    DIV: "/",
    MOD: "%",
    REF: "^",
    DOT: ".",
    COLON: ":",
    COMMA: ",",
    SEMICOLON: ";",
    
    LET: "let",
    VAR: "var",
    ENTRY: "entry",
    NOT: "not",
    FUN: "fun",
    USE: "use",
    IMPL: "impl",
    FOR: "for",
    TEMPLATE: "template",
    RETURN: "return",
    STRUCT: "struct",
    PUBLIC: "public",
    TRAIT: "trait",
    IMPORT: "import",
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
    of EOT:
        return "(EOT)"
