import os
import strformat
import sequtils
import strutils
import tables

import reader
import token
import error


#TODO: decouple Builder from toks to allow performing
# parsing stages independently of internal state

#1. process template definitions
#2. process imports
 #1. process template definitions for each import
 #2. process imports for each import
 #3. 1 & 2 are performed recursively
#3. combine all the processed imports recursively
#4. proccess trait definitions and implementations

type
    TemplateData* = object
        args: seq[string]
        toks: seq[Token]
    TypeDataType = enum
        BASE,
        STRUCT,
        ENUM,
    TypeData = object
        case kind: TypeDataType
        of BASE:
            name: string
        of struct:
            name: string
            fields: seq[]
            
    Builder* = object
        toks*: seq[Token]
        temps*: Table[string, TemplateData]
        pos: int

proc makeTemplate*(args: sink seq[string], tokens: sink seq[Token]): TemplateData =
    return TemplateData(args: args, toks: tokens)
proc makeBuilder*(tokens: sink seq[Token]): Builder =
    return Builder(toks: tokens, temps: initTable[string, TemplateData](), pos: 0)

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
        return makeTok(newData("",""), 0, EOF)
    else:
        return self.toks[self.pos + n]

proc next(self: var Builder, n: Positive = 1) =
    let len = self.pos + n
    if len >= self.toks.len:
        self.pos = self.toks.len
    else:
        self.pos = len

proc processTemplateDefs*(self: var Builder, reporter: var Reporter) =
    block outer:
        while true:
            self.pos = self.toks.find(TEMPLATE)
            if self.pos == -1:
                break
            let data = self.toks[self.pos].data
            let pos = self.toks[self.pos].pos
            const temp_len = TokenNames[TEMPLATE].len
            var offset = 1
            #chekc for name
            if self.peekType(offset) != IDENTIFIER:
                reporter.report(data, pos, temp_len,
                    "Expected template name after 'template'")
                break
            let temp_name = self.toks[self.pos + offset].text
            offset += 1
            #check for arguments
            if self.peekType(offset) != LPAREN:
                reporter.report(data, pos, temp_len,
                    "Expected '(' after 'template <name>'")
                break
            offset += 1
            var args: seq[string]
            #taking no arguments is allowed
            while self.peekType(offset) != RPAREN:
                let data = self.toks[self.pos + offset].data
                let pos = self.toks[self.pos + offset].pos
                if self.peekType(offset) != IDENTIFIER:
                    reporter.report(data, pos,
                        "Expected ')' or an argument in template argument list")
                    break outer
                #wrap argument in backticks for more efficient substitution later
                args.add(&"`{self.toks[self.pos + offset].text}`")
                offset += 1
                #a leading comma is allowed
                if self.peekType(offset) == COMMA:
                    offset += 1
            offset += 1
            #check for body
            if self.peekType(offset) != LCURLY:
                reporter.report(data, pos, temp_len,
                    "Expected '{' after 'template <name>'")
                break
            offset += 1
            #mark the start of the template definition body
            let start = offset
            #checks whether a '}' terminates the template definition
            var depth = 1
            while depth != 0:
                if self.peekType(offset) == EOT:
                    reporter.report(data, pos, temp_len,
                        "Unterminated template definition")
                    break outer
                elif self.peekType(offset) == LCURLY:
                    depth += 1
                elif self.peekType(offset) == RCURLY:
                    depth -= 1
                offset += 1
            #mark the end of the template definition body
            let stop = offset - 2
            #take a subset from the tokens
            let body: seq[Token] = self.toks[self.pos + start .. self.pos + stop]
            #delete entire template body from tokens
            self.toks.delete(self.pos .. self.pos + offset - 1)
            #construct a new template with the parsed data
            let temp = makeTemplate(args, body)
            #add it to the templates definitions
            self.temps[temp_name] = temp
    self.pos = 0

proc processTemplateImpls(self: var Builder, reporter: var Reporter) =
    block outer:
        while true:
            self.pos = self.toks.find(IMPL)
            if self.pos == -1:
                break
            var data = self.toks[self.pos].data
            var pos = self.toks[self.pos].pos
            const impl_len = TokenNames[IMPL].len
            var offset = 1
            if self.peekType(offset) != IDENTIFIER:
                reporter.report(data, pos, impl_len,
                    "Expected template name after 'impl'")
                break
            
            data = self.toks[self.pos + offset].data
            pos = self.toks[self.pos + offset].pos
            let temp_name = self.toks[self.pos + offset].text
            if not self.temps.hasKey(temp_name):
                reporter.report(data, pos, temp_name.len,
                    "template name \"{temp_name}\" is invalid.")
                break outer
            #would throw an exception if temps does not contain the key
            let temp = self.temps[temp_name]
            
            offset += 1
            #[while self.peekType(offset) != RPAREN:
                let data = self.toks[self.pos + offset].data
                let pos = self.toks[self.pos + offset].pos
                if self.peekType(offset) != IDENTIFIER:
                    reporter.report(data, pos,
                        "Expected ')' or an argument in template argument list")
                    break outer
                #wrap argument in backticks for more efficient substitution later
                args.add(&"`{self.toks[self.pos + offset].text}`")
                offset += 1
                #a leading comma is allowed
                if self.peekType(offset) == COMMA:
                    offset += 1]#
            offset += 1
    self.pos = 0

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
            builder.processTemplateDefs(reporter)
            #recursively handles stuff and things
            builder.processImports(reporter)
            builder.processTemplateImpls(reporter)#needs to add to self, not builder, or just merge the two
            self.toks.insert(builder.toks, self.pos)
        except IOError:
            reporter.report(data, pos, imp_len,
                &"Failed to open/read file \"{system_filename}\"")
            break
    self.pos = 0

type
    VarOrLitType = enum
        VAR,
        LINT,
        LFLOAT,
        LSTRING,
        LBOOL,
        VOID,
    VarOrLit = object
        case kind: VarOrLitType
        of VAR:
            name: string
            vtype: int #type tracking to be implemented
        of LINT:
            inum: int
        of LFLOAT:
            fnum: float
        of LSTRING:
            text: string
        of LBOOL:
            bval: bool
        of VOID:
            discard
    UnitType = enum
        Expression,
        Assign,
        Binary,
        Declaration,
        
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
        fields: 

proc nextProgram(self: var Builder): Program =
    while true:
        let tok = self.peek()
        if tok.kind == EOT:
            break
        case tok.kind
        of LET:
            let stmt = self.nextStatement()
            if not stmt.isSome():
                quit("Bad Statement - TODO Error Handling")
            

proc nextDeclaration(self: var Builder): ref Statement =
    if self.peekType() notin [LET, VAR, CONST]:
        return nil
    var decl = new Declaration
    if self.peekType(1) 

proc parseAST*(self: var Builder, reporter: var Reporter) =
    discard
    

proc build*(self: var Builder, reporter: var Reporter) =
        #Ignore complicated 3-fold recursion problem for now
        #self.processTemplateDefs(reporter)
        self.processImports(reporter)
        #self.processTemplateImpls(reporter)
