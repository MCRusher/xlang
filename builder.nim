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

type BasicType = enum
    INT,
    UINT,
    FLOAT,
    BOOL,
    PTR,

#C equivalent of X-lang base types
const BasicNative = [
  INT: "long long",
 UINT: "unsigned long long",
FLOAT: "double",
 BOOL: "_Bool",
  PTR: "void*",
]

type
    TypeDataType = enum
        BASE,
        STRUCT,
        ENUM,
    TypeData = ref object
        name*: string
        case kind: TypeDataType
        of BASE:
            what*: BasicType
        of STRUCT:
            fields*: seq[TypeData]
        of ENUM:
            values*: seq[string]#Table[string, uint]
    Builder* = object
        toks*: seq[Token]
        types*: seq[TypeData]
        pos: int

func makeBase*(name: string, what: BasicType): TypeData = TypeData(kind: BASE, name: name, what: what)
#makes empty struct
func makeStruct*(name: string): TypeData = TypeData(kind: STRUCT, name: name)
#makes empty enum
func makeEnum*(name: string): TypeData = TypeData(kind: ENUM, name: name)

proc makeBuilder*(tokens: sink seq[Token]): Builder =
    let basic = @[
        makeBase("int", INT),
        makeBase("uint", UINT),
        makeBase("float", FLOAT),
        makeBase("bool", BOOL),
        makeBase("ptr", PTR),
    ]
    return Builder(toks: tokens, types: basic, pos: 0)

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
        #replace newData with nil later, but I want a more recognizable problem
        return makeTok(newData("",""), 0, EOT)
    else:
        return self.toks[self.pos + n]

proc next(self: var Builder, n: Positive = 1) =
    let len = self.pos + n
    if len >= self.toks.len:
        self.pos = self.toks.len
    else:
        self.pos = len

func atEnd(self: Builder): bool = self.pos >= self.toks.len

#removes entry blocks from source tokens, should be used on every import
proc removeEntrys*(self: var Builder, reporter: var Reporter) =
    while true:
        self.pos = self.toks.find(ENTRY)
        if self.pos == -1:
            break
        let data = self.toks[self.pos].data
        let pos = self.toks[self.pos].pos
        const ent_len = TokenNames[ENTRY].len
        var offset = 1
        #should in the future make this delete the entry tag and continue parsing
        if self.peekType(offset) != LCURLY:
            reporter.report(data, pos, ent_len,
                "Expected '{' after 'entry'")
            break
        offset += 1
        var depth = 1
        while depth != 0 and not self.atEnd():
            if self.peekType(offset) == LCURLY:
                depth += 1
            elif self.peekType(offset) == RCURLY:
                depth -= 1
            offset += 1
        if depth != 0:
            reporter.report(data, pos, ent_len,
                "Unterminated entry block")
            break
        self.toks.delete(self.pos .. self.pos + offset - 1)
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
            var builder = makeBuilder(rd.readTokens(reporter))
            builder.processImports(reporter)
            if reporter.hadError:
                break
            #doesn't need to loop since it's called recursively
            # (should make multiple entry blocks an error
            builder.removeEntrys(reporter)
            if reporter.hadError:
                break
            self.toks.insert(builder.toks, self.pos)
        except IOError:
            reporter.report(data, pos, imp_len,
                &"Failed to open/read file \"{system_filename}\"")
            break
    self.pos = 0

proc parseEnums(self: var Builder, reporter: var Reporter) =
    while true:
        self.pos = self.toks.find(TokenType.ENUM)
        if self.pos == -1:
            break
        let data = self.toks[self.pos].data
        let pos = self.toks[self.pos].pos
        const enum_len = TokenNames[TokenType.ENUM].len
        var offset = 1
        if self.peekType(offset) != IDENTIFIER:
            reporter.report(data, pos, enum_len,
                "Expected name after 'enum'")
            break
        let name = self.peek(offset).text
        var enum_type = makeEnum(name)
        offset += 1
        if self.peekType(offset) != LCURLY:
            reporter.report(data, pos, enum_len,
                "Expected '{' after 'enum <name>'")
        offset += 1
        while self.peekType(offset) == IDENTIFIER:
            let tok = self.peek(offset)
            offset += 1
            if self.peekType(offset) != COMMA:
                reporter.report(tok.data, tok.pos, tok.text.len,
                    "Expected ',' after enum value")
                break
            enum_type.values.add(tok.text)
            offset += 1
        if self.peekType(offset) != RCURLY:
            reporter.report(data, pos, enum_len,
                "Unterminated enum block")
        offset += 1
        self.types.add(enum_type)
        self.toks.delete(self.pos .. self.pos + offset - 1)
    self.pos = 0

proc processTypes(self: Builder): string =
    for t in self.types:
        case t.kind:
        of BASE:
            discard
        of STRUCT:
            discard#todo
        of ENUM:
            result.add("enum ")
            result.add(t.name)
            result.add(" {\n")
            for i in countup(0, t.values.len-1):
                result.add(&"\t{t.values[i]}")
                if i != t.values.len-1:
                    result.add(',')
                result.add('\n')
            result.add("};\n")

proc processEntry(self: var Builder, reporter: var Reporter): string =
    self.pos = self.toks.find(ENTRY)
    if self.pos == -1:        
        reporter.reportBroad("<main module>", "Expected entry block in main module")
        return
    let data = self.toks[self.pos].data
    let pos = self.toks[self.pos].pos
    var offset = 1
    if self.peekType(offset) != LCURLY:
        reporter.report(data, pos, TokenNames[ENTRY].len, "Expected '{' after 'entry'")
        return
    offset += 1
    #begin processing body
    var depth = 1 
    while depth != 0 and not self.atEnd():
        for i in countup(0, depth-1):
            result.add('\t')
        if self.peekType(offset) == LCURLY:
            depth += 1
        elif self.peekType(offset) == RCURLY:
            depth -= 1
        elif self.peekType(offset) == VAR:
            let data = self.toks[self.pos].data
            let pos = self.toks[self.pos].pos
            offset += 1
            if self.peekType(offset) != IDENTIFIER:
                reporter.report(data, pos, TokenNames[VAR].len, "Expected variable name after 'var'")
                return
            let name = self.peek(offset).text
            offset += 1
            if self.peekType(offset) != COLON:
                reporter.report(data, pos, TokenNames[VAR].len, "Expected ':' after 'var <name>'")
                return
            offset += 1
            if self.peekType(offset) != IDENTIFIER:
                reporter.report(data, pos, TokenNames[VAR].len, "Expected type after 'var <name>:'")
                return
            let kind = self.peek(offset).text
            var td: TypeData
            for t in self.types:
                if t.name == kind:
                    td = t
                    break
            if td == nil:
                reporter.report(data, pos, TokenNames[VAR].len, "Invalid type '{kind}'")
                return
            offset += 1
            #write resolved type to output
            case td.kind
            of BASE:
                result.add(BasicNative[td.what])
            of STRUCT:
                result.add(&"struct {td.name}")
            of ENUM:
                result.add(&"enum {td.name}")
            result.add(' ')
            result.add(name)
            result.add(' ')
            if self.peekType(offset) == SEMICOLON:
                result.add("= {0}")
            else:
                while self.peekType(offset) != SEMICOLON and not self.atEnd():
                    result.add(self.peek(offset).stringVal())
                    if self.peekType(offset+1) != SEMICOLON:
                        result.add(' ')                    
                    offset += 1
                if self.atEnd():
                    reporter.report(data, pos, TokenNames[VAR].len, "Unterminated variable declaration-assignment")
                    return
            result.add(";\n")
            offset += 1
        else:
            result.add(self.peek(offset).stringVal())
            offset += 1

proc build*(self: var Builder, reporter: var Reporter): string =
    self.processImports(reporter)
    if reporter.hadError:
        return
    self.parseEnums(reporter)
    if reporter.hadError:
        return
    let types = self.processTypes()
    let entry = self.processEntry(reporter)
    if reporter.hadError:
        return
    
    let program = &"""
#include <stdlib.h>

{types}

void entry(void) {{
{entry}
}}

int main(int argc, char** argv) {{
    entry();
    exit(EXIT_SUCCESS);
}}
"""
    
    
    return program
