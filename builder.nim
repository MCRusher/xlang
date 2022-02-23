import os
import strformat
import sequtils
import strutils

import reader
import token
import data
import error

type
    Builder* = object
        toks*: seq[Token]
        pos: int
proc makeBuilder*(tokens: sink seq[Token]): Builder =
    return Builder(toks: tokens, pos: 0)

proc find(self: seq[Token], kind: TokenType): int =
    for i in countup(0, self.len-1):
        if self[i].kind == kind:
            return i
    return -1

proc peekType(self: Builder, n: Natural = 0): TokenType =
    if self.pos + n >= self.toks.len:
        return EOT
    else:
        return self.toks[self.pos + n].kind

#Do not call with an empty list of tokens
proc peekTok(self: Builder, n: Natural = 0): Token =
    if self.pos + n >= self.toks.len:
        return makeTok(self.toks[self.toks.len-1].data, self.toks[self.toks.len-1].data.src.len-1, EOT)
    else:
        return self.toks[self.pos + n]

proc reportTok(self: var Reporter, tok: Token, len: Positive, msg: string) = self.report(tok.data, tok.pos, len, msg)
proc reportTok(self: var Reporter, tok: Token, msg: string) = self.report(tok.data, tok.pos, 1, msg)

proc processImports*(self: var Builder, reporter: var Reporter): bool =
    var names: seq[string]
    while true:
        self.pos = self.toks.find(IMPORT)
        if self.pos == -1:
            break
        var offset = 1
        if self.peekType(offset) != IDENTIFIER:
            reporter.reportTok(self.peekTok(offset), TokenNames[IMPORT].len,
                "Expected filename after 'import'")
        offset += 1
        while self.peekType(offset) in [IDENTIFIER, NAMESPACE]:
            offset += 1
        if self.peekType(offset) != SEMICOLON:
            reporter.reportTok(self.peekTok(offset), "Expected ';' after 'import <filename>'")
        var filename: string
        for i in countup(self.pos, self.pos + offset-1):
            filename.add(self.toks[i].stringVal())
        self.toks.delete(self.pos .. self.pos + offset)
        #already included, nothing more to do
        if filename in names:
            continue
        let system_filename = filename.replace("::", $DirSep) & ".x"
        try:
            let src = readFile(system_filename)
            var rd = makeReader(filename, src)
            self.toks.insert(rd.readTokens(reporter), self.pos)
        except IOError:
            reporter.reportTok(self.peekTok(1), filename.len, &"Failed to open file \"{system_filename}\"")
    self.pos = 0
    return reporter.hadError

proc build*(self: var Builder, reporter: var Reporter) =
    discard
        self.processImports(reporter) and
        true
