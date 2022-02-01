import strformat

type
    TokenType* = enum
        LET,
        VAR,
        CONST,
        EQUALS,
        ADD,
        SUB,
        MUL,
        POW,
        DIV,
        MOD,
        NOT,
        LESS,
        GREATER,
        EQUALS_EQUALS,
        NOT_EQUALS,
        LESS_EQUALS,
        GREATER_EQUALS,
        LPAREN,
        RPAREN,
        LSBRACE,
        RSBRACE,
        LCURLY,
        RCURLY,
        TRAIT,
        IMPL,
        FOR,
        WHILE,
        IF,
        ELIF,
        ELSE,
        RETURN,
        COLON,
        NAMESPACE,
        DOT,
        ARROW,
        DEREF,
        REF,
        PUBLIC,
        IMPORT,
        USE,
        COMMA,
        STRUCT,
        ENUM,
        AT,
        TRUE,
        FALSE,
        NULL,
        SEMICOLON,
        IDENTIFIER,
        BAD,
        LITINT,
        LITFLOAT,
        LITSTRING

    Token* = object
        pos: int
        case kind: TokenType
        of LET..SEMICOLON:
            discard
        of IDENTIFIER..BAD, LITSTRING:
            text: string
        of LITINT:
            inum: int
        of LITFLOAT:
            fnum: float

const TokenNames = [
    LET: "let",
    VAR: "var",
    CONST: "const",
    EQUALS: "=",
    ADD: "+",
    SUB: "-",
    MUL: "*",
    POW: "**",
    DIV: "/",
    MOD: "%",
    NOT: "not",
    LESS: "<",
    GREATER: ">",
    EQUALS_EQUALS: "==",
    NOT_EQUALS: "!=",
    LESS_EQUALS: "<=",
    GREATER_EQUALS: ">=",
    LPAREN: "(",
    RPAREN: ")",
    LSBRACE: "[",
    RSBRACE: "]",
    LCURLY: "{",
    RCURLY: "}",
    TRAIT: "trait",
    IMPL: "impl",
    FOR: "for",
    WHILE: "while",
    IF: "if",
    ELIF: "elif",
    ELSE: "else",
    RETURN: "return",
    COLON: ":",
    NAMESPACE: "::",
    DOT: ".",
    ARROW: "->",
    DEREF: ".*",
    REF: "^",
    PUBLIC: "public",
    IMPORT: "import",
    USE: "use",
    COMMA: ",",
    STRUCT: "struct",
    ENUM: "enum",
    AT: "@",
    TRUE: "true",
    FALSE: "false",
    NULL: "null",
    SEMICOLON: ";"
]

proc makeSyn*(pos: int, t: TokenType): Token = Token(pos: pos, kind: t)
proc makeID*(pos: int, text: string): Token = Token(pos: pos, kind: IDENTIFIER, text: text)
proc makeLit*(pos: int, num: int): Token = Token(pos: pos, kind: LITINT, inum: num)
proc makeLit*(pos: int, num: float): Token = Token(pos: pos, kind: LITFLOAT, fnum: num)
proc makeLit*(pos: int, str: string): Token = Token(pos: pos, kind: LITSTRING, text: str)
proc makeBad*(pos: int, text: string): Token = Token(pos: pos, kind: BAD, text: text)

proc `$`*(t: Token): string =
    case t.kind
    of LET..SEMICOLON:
        return fmt"({t.pos}|{t.kind}: {TokenNames[t.kind]})"
    of IDENTIFIER..BAD:
        return fmt"({t.pos}|{t.kind}: {t.text})"
    of LITINT:
        return fmt"({t.pos}|Int: {t.inum})"
    of LITFLOAT:
        return fmt"({t.pos}|Float: {t.fnum})"
    of LITSTRING:
        return fmt"({t.pos}|String: {t.text})"
