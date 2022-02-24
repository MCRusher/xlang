import os
import strformat
import sequtils
import strutils
import tables

import reader
import token
import error

type
    TemplateData* = object
        args: seq[string]
        toks: seq[Token]
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
        while self.peekType(offset) in [IDENTIFIER, NAMESPACE]:
            offset += 1
        if self.peekType(offset) != SEMICOLON:
            reporter.report(data, pos, imp_len,
                "Expected ';' after 'import <filename>'")
            break
        var filename: string
        for i in countup(self.pos+1, self.pos + offset-1):
            filename.add(self.toks[i].stringVal())
        self.toks.delete(self.pos .. self.pos + offset)
        #already included, nothing more to do
        if filename in names:
            continue
        let system_filename = filename.replace("::", $DirSep) & ".x"
        try:
            let src = readFile(system_filename)
            var rd = makeReader(system_filename, src)
            self.toks.insert(rd.readTokens(reporter), self.pos)
        except IOError:
            reporter.report(data, pos, imp_len,
                &"Failed to open/read file \"{system_filename}\"")
    self.pos = 0

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
            let data = self.toks[self.pos].data
            let pos = self.toks[self.pos].pos
            const impl_len = TokenNames[IMPL].len
            var offset = 1
            if self.peekType(offset) != IDENTIFIER:
                reporter.report(data, pos, impl_len,
                    "Expected template name after 'impl'")
                break
            let name_pos = self.temps.find(self.toks[self.pos + offset].text)
            if name_pos == -1:
                reporter.report(data, pos, impl_len,
                    "Name is invalid (improve this error message)")
    self.pos = 0

proc build*(self: var Builder, reporter: var Reporter) =
        self.processImports(reporter)
        self.processTemplateDefs(reporter)
        self.processTemplateImpls(reporter)
