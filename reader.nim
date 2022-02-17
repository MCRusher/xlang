import options
import strutils

import token
import data
import error

type
    Reader* = object
        fds: seq[ReaderData]

const EOF = '\0'

proc makeReader*(name: string, src: string): Reader =
    return Reader(fds: @[ReaderData(name: name, src: src, pos: 0)])

proc data(self: Reader): ReaderData =
    return self.fds[self.fds.len-1]

proc name(self: Reader): string =
    return self.fds[self.fds.len-1].name

proc src(self: Reader): string =
    return self.fds[self.fds.len-1].src

proc pos(self: var Reader): var int =
    return self.fds[self.fds.len-1].pos

proc pos(self: Reader): int =
    return self.fds[self.fds.len-1].pos

proc atEnd*(self: Reader): bool = self.pos >= self.src.len

proc peek*(self: Reader, n: Natural = 0): char =
    if self.pos + n >= self.src.len:
        return EOF
    else:
        return self.src[self.pos + n]

proc peekStr*(self: Reader, n: Natural = 0): string =
    var len = self.pos + n
    if len >= self.src.len:
        len = self.src.len-1
    return self.src[self.pos .. len]

proc next*(self: var Reader, n: Positive = 1) =
    if self.pos() + n >= self.src.len:
        self.pos() = self.src.len
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
        elif self.atEnd():
            return none(string)
    let str = self.src[self.pos + 1 .. self.pos + offset - 2]
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
    while self.peek(offset).toLowerAscii() in id_chars:
        offset += 1
    let str = self.peekStr(offset-1)
    self.pos += offset
    return some(str)

proc isValidInitialChar(c: char): bool =
    let c = c.toLowerAscii()
    return c.isDigit() or c in id_initial_chars or c in signs or c == '.'

proc isValidChar(c: char): bool =
    let c = c.toLowerAscii()
    return c.isDigit() or c in id_chars or c in signs or c == '.'

proc nextBad*(self: var Reader): Option[string] =
    var offset = 0
    if self.peek(offset).isValidInitialChar():
        return none(string)
    offset += 1
    while not self.peek(offset).isValidChar():
        offset += 1
    let str = self.peekStr(offset-1)
    self.pos += offset
    return some(str)

proc readToken*(self: var Reader, reporter: var Reporter): Token =
    let name = self.name
    let pos = self.pos
    let c = self.peekStr(1)
    if c.len == 0:
        return makeTok(name, pos, EOT)
    let comp_operator_id = TokenNames.find(c)
    if comp_operator_id != -1:
        self.next(2)
        return makeTok(name, pos, TokenType(comp_operator_id))
    let single_operator_id = TokenNames.find(c[0..0])
    if single_operator_id != -1:
        self.next()
        return makeTok(name, pos, TokenType(single_operator_id))
    case c[0]
    of ' ','\t','\n':
        self.next()
        #ignore it and fetch another token
        return self.readToken(reporter)
    else:
        #store starting position of token for error reporting
        let name = self.name
        let pos = self.pos
        if self.peek().isDigit():
            let fnum = self.nextFloat()
            if fnum.isSome():
                return makeTok(name, pos, fnum.get())
            let inum = self.nextInt()
            if inum.isSome():
                return makeTok(name, pos, inum.get())
            #emit error, should be unreachable
            reporter.report(self.data,
                "Internal Compiler Error: A sequence of digits should always be either an integer or a float")
            quit()
        else:
            let ident = self.nextIdentifier()
            if not ident.isSome():
                let bad = self.nextBad()
                if not bad.isSome():
                    reporter.report(self.data,
                        "Internal Compiler Error: If token is not a valid identifier, it should be an invalid token")
                    quit()
                reporter.report(self.data,
                    "Bad Token", bad.get().len)
                return makeTok(name, pos, BAD, bad.get())
            let keyword_id = TokenNames.find(ident.get())
            if keyword_id != -1:
                return makeTok(name, pos, TokenType(keyword_id))
            else:
                return makeTok(name, pos, IDENTIFIER, ident.get())

proc readTokens*(self: var Reader, reporter: var Reporter): seq[Token] =
    var buf: seq[Token]
    while true:
        let t = self.readToken(reporter)
        if t.kind == EOT:
            break
        buf.add(t)
    return buf
