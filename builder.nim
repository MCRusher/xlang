import os
import strformat
import sequtils
import strutils
import tables

import reader
import token
import error
import data

#2. process imports

type
    TypeDataType = enum
        BASE,
        STRUCT,
        ENUM,
    TypeData = object
        name: string
        case kind: TypeDataType
        of BASE:
            discard
        of STRUCT:
            fields: seq[ref TypeData]
        of ENUM:
            values: Table[string, uint]
    Builder* = object
        toks*: seq[Token]
        types: seq[ref TypeData]
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

proc peek(self: Builder, n: Natural = 0): Token =
    if self.pos + n >= self.toks.len:
        return makeTok(newData("",""), 0, EOT)
    else:
        return self.toks[self.pos + n]

proc next(self: var Builder, n: Positive = 1) =
    let len = self.pos + n
    if len >= self.toks.len:
        self.pos = self.toks.len
    else:
        self.pos = len

proc processImports*(self: var Builder, reporter: var Reporter) =
    var names: seq[string]
    while true:
        self.pos = self.toks.find(IMPORT)
        if self.pos == -1:
            break
        let data = self.toks[self.pos].data
        let pos = self.toks[self.pos].pos
        const imp_len = TokenNames[IMPORT].len
        var offset = 1
        if self.peekType(offset) != IDENTIFIER:
            reporter.report(data, pos, imp_len,
                "Expected filename after 'import'")
            break
        offset += 1
        if self.peekType(offset) != SEMICOLON:
            reporter.report(data, pos, imp_len,
                "Expected ';' after 'import <filename>'")
            break
        var filename = self.toks[self.pos + offset-1].text
        self.toks.delete(self.pos .. self.pos + offset)
        #already included, nothing more to do
        if filename in names:
            continue
        names.add(filename)
        #convert import statement to the system's file directory path format
        let system_filename = filename.replace("::", $DirSep) & ".x"
        try:
            let src = readFile(system_filename)
            var rd = makeReader(system_filename, src)
            #make this recursive instead, merge-sort-ish style
            var builder = makeBuilder(rd.readTokens(reporter))
            #builder.processTemplateDefs(reporter)
            #recursively handles stuff and things
            builder.processImports(reporter)
            #builder.processTemplateImpls(reporter)#needs to add to self, not builder, or just merge the two
            self.toks.insert(builder.toks, self.pos)
        except IOError:
            reporter.report(data, pos, imp_len,
                &"Failed to open/read file \"{system_filename}\"")
            break
    self.pos = 0

type
    Unit {.inheritable.} = object
        discard
    Statement = object of Unit
        discard
    Expression = object of Unit
        discard
    Program = object
        stmts: seq[ref Statement]
    Identifier = object
        tok: Token
    Declaration = object of Statement
        tok: Token
        name: ref Identifier
        val: ref Expression
    Field = tuple
        name: ref Identifier
        kind: int
    Struct = object of Statement
        tok: Token
        name: ref Identifier
        fields: seq[Field]

proc nextProgram(self: var Builder, reporter: var Reporter): Option[Program] =
    while true:
        let tok = self.peek()
        if tok.kind == EOT:
            break
        var stmt: ref Statement
        case tok.kind
        of LET, VAR, CONST:
            stmt = self.nextDeclaration()
        of RETURN:
            stmt = self.nextReturn()
        of IF:
            stmt = self.nextIf()
        if stmt.isNone():
            reporter.report(tok.data, tok.pos, "Bad Statement (TODO Better Error Message)")
            return
        self.stmts.add(stmt)
            

proc nextDeclaration(self: var Builder): ref Statement =
    if self.peekType() notin [LET, VAR, CONST]:
        return
    var decl = new Declaration
    #type is specified (can be known now)
    var offset = 1
    if self.peekType(offset) == COLON:
        offset += 1
        if not self.peekType(offset) == IDENTIFIER:
            return
        let tok = self.peek(offset)
        offset += 1
        #search for the type
        if not self.types.hasKey(tok.text):
            return
        let data = self.types[tok.text]
        #figure out pointer-level of type
        var plevel = 0
        while self.peekType(offset) == REF:
            offset += 1
            plvelel += 1
        if not self.peekType(offset) == EQUALS:
            return
proc parseAST*(self: var Builder, reporter: var Reporter) =
    discard
    

proc build*(self: var Builder, reporter: var Reporter) =
        #Ignore complicated 3-fold recursion problem for now
        #self.processTemplateDefs(reporter)
        self.processImports(reporter)
        #self.processTemplateImpls(reporter)
