import os
import strformat
import sequtils
import strutils

import reader
import token
import error

type
    TemplateData* = object
        name: string
        toks: seq[Token]
    Builder* = object
        toks*: seq[Token]
        temps*: seq[TemplateData]
        pos: int

proc makeTemplate*(name: string, tokens: sink seq[Token]): TemplateData = TemplateData(name: name, toks: tokens)
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

proc processImports*(self: var Builder, reporter: var Reporter): bool =
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
    return reporter.hadError

#this is wrong currently since templates actually take arguments
proc processTemplateDefs*(self: var Builder, reporter: var Reporter): bool =
    block outer:
        while true:
            self.pos = self.toks.find(TEMPLATE)
            if self.pos == -1:
                break
            let data = self.toks[self.pos].data
            let pos = self.toks[self.pos].pos
            const temp_len = TokenNames[TEMPLATE].len
            var offset = 1
            if self.peekType(offset) != IDENTIFIER:
                reporter.report(data, pos, temp_len,
                    "Expected template name after 'template'")
                break
            let temp_name = self.toks[self.pos + offset].text
            offset += 1
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
            let temp = makeTemplate(temp_name, body)
            #add it to the templates definitions
            self.temps.add(temp)
    self.pos = 0

proc build*(self: var Builder, reporter: var Reporter) =
    discard
        self.processImports(reporter) and
        self.processTemplateDefs(reporter)
