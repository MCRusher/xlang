import options
import strutils
import strformat

import token
import data
import error

type
    Reader* = object
        data*: ref Data
        pos: int

const EOF = '\0'

proc makeReader*(name: string, src: string): Reader = Reader(data: newData(name, src), pos: 0)

proc makeReader*(data: ref Data): Reader = Reader(data: data, pos: 0)
    
proc getData*(self: Reader): ref Data = self.data

proc setData*(self: var Reader, data: ref Data) =
    self.data = data

proc atEnd*(self: Reader): bool = self.pos >= self.data.src.len

proc peek*(self: Reader, n: Natural = 0): char =
    if self.pos + n >= self.data.src.len:
        return EOF
    else:
        return self.data.src[self.pos + n]

proc peekStr*(self: Reader, n: Natural = 0): string =
    var len = self.pos + n
    if len >= self.data.src.len:
        len = self.data.src.len-1
    return self.data.src[self.pos .. len]

proc next*(self: var Reader, n: Positive = 1) =
    if self.pos + n >= self.data.src.len:
        self.pos = self.data.src.len
    else:
        self.pos += n

const signs = "+-"

proc nextInt*(self: var Reader): Option[int] =
    var offset = 0
    if self.peek() in signs:
        offset += 1
    if not self.peek(offset).isDigit():
        return none(int)
    while self.peek(offset).isDigit():
        offset += 1
    let num = self.peekStr(offset-1).parseInt()
    self.pos += offset
    return some(num)

proc nextFloat*(self: var Reader):  Option[float] =
    var offset = 0
    if self.peek() in signs:
        offset += 1
    if not self.peek(offset).isDigit():
        return none(float)
    while self.peek(offset).isDigit():
        offset += 1
    #must have a decimal to be considered a float literal
    if self.peek(offset) != '.':
        return none(float)
    offset += 1
    #must have at least one digit after decimal
    if not self.peek(offset).isDigit():
        return none(float)
    while self.peek(offset).isDigit():
        offset += 1
    let num = self.peekStr(offset-1).parseFloat()
    self.pos += offset
    return some(num)

proc nextString*(self: var Reader): Option[string] =
    var offset = 0
    if self.peek() != '"':
        return none(string)
    offset += 1
    while true:
        if self.peek(offset) == '\\':
            offset += 2
        elif self.peek(offset) == '"':
            offset += 1
            break
        elif self.peek(offset) == EOF:
            return none(string)
        else:
            offset += 1
    let str = self.data.src[self.pos + 1 .. self.pos + offset - 2]
    self.pos += offset
    return some(str)


#it's fine to have digits in initial chars since numeric literals are matched against before identifiers
const id_initial_chars = "abcdefghinjklmnopqrstuvwxyz0123456789_`"
const id_chars = id_initial_chars & "<>" # ` and <...> are special template related characters, but are treated as normal characters otherwise

proc nextIdentifier*(self: var Reader): Option[string] =
    var offset = 0
    if self.peek().toLowerAscii() notin id_initial_chars:
        return none(string)
    offset += 1
    while true:
        let c = self.peek(offset).toLowerAscii()
        if c == '<':
            offset += 1
            var depth = 1
            while depth != 0:
                let c = self.peek(offset)
                if c == '<':
                    depth += 1
                elif c == '>':
                    depth -= 1
                offset += 1
        elif c == ':' and self.peek(offset+1) == ':':
            offset += 2
        elif c in id_chars:
            offset += 1
        else:
            break
    let str = self.peekStr(offset-1)
    self.pos += offset
    return some(str)


proc isValidChar(c: char): bool =
    let c = c.toLowerAscii()
    return
        c.isDigit() or
        c.isSpaceAscii() or
        c in id_chars or
        c in signs or
        c == '.' or
        c == '@'

proc nextBad*(self: var Reader): Option[string] =
    var offset = 0
    if self.peek().isValidChar():
        return none(string)
    offset += 1
    while not self.peek(offset).isValidChar():
        offset += 1
    let str = self.peekStr(offset-1)
    self.pos += offset
    return some(str)

#Scan for all the possible tokens, errors are reported via reporter
proc readToken*(self: var Reader, reporter: var Reporter): Token =
    let pos = self.pos
    let c = self.peekStr(1)
    if c.len == 0:
        return makeTok(self.data, self.data.src.len-1, EOT)
    let comp_operator_id = TokenNames.find(c)
    if comp_operator_id != -1:
        self.next(2)
        return makeTok(self.data, pos, TokenType(comp_operator_id))
    let single_operator_id = TokenNames.find(c[0..0])
    if single_operator_id != -1:
        self.next()
        return makeTok(self.data, pos, TokenType(single_operator_id))
    case c[0]
    of ' ','\t','\n':
        self.next()
        #ignore it and fetch another token
        return self.readToken(reporter)
    of '"':
        let str = self.nextString()
        if not str.isSome():
            reporter.report(self.data, pos, "Unterminated String Literal")
        return makeTok(self.data, pos, str.get())
    else:
        #store starting position of token for error reporting
        if self.peek().isDigit():
            let fnum = self.nextFloat()
            if fnum.isSome():
                return makeTok(self.data, pos, fnum.get())
            let inum = self.nextInt()
            if inum.isSome():
                return makeTok(self.data, pos, inum.get())
            #emit error, should be unreachable
            reporter.report(self.data, pos,
                "Internal Compiler Error: A sequence of digits should always be either an integer or a float")
            quit()
        else:
            let ident = self.nextIdentifier()
            if not ident.isSome():
                let bad = self.nextBad()
                if not bad.isSome():
                    reporter.report(self.data, pos,
                        "Internal Compiler Error: If token is not a valid identifier, it should be an invalid token")
                    quit()
                reporter.report(self.data, pos, bad.get().len,
                    &"Bad Token \"{bad.get()}\"")
                return makeTok(self.data, pos, BAD, bad.get())
            let keyword_id = TokenNames.find(ident.get())
            if keyword_id != -1:
                return makeTok(self.data, pos, TokenType(keyword_id))
            else:
                if TokenType(keyword_id) in [TRUE, FALSE]:
                    return makeTok(self.data, pos, ident.get() == "true")
                return makeTok(self.data, pos, IDENTIFIER, ident.get())

#Read all tokens until readToken signals EOT (End Of Tokens), discard EOT
proc readTokens*(self: var Reader, reporter: var Reporter): seq[Token] =
    var buf: seq[Token]
    while true:
        let t = self.readToken(reporter)
        if t.kind == EOT:
            break
        buf.add(t)
    return buf
