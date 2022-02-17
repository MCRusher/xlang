import strutils
import strformat
import terminal

import filedata

type
    Reporter* = object
        hadError*: bool
        fd: ref FileData

proc makeReporter*(fd: ref FileData): Reporter = Reporter(fd: fd)

#internal utility that converts an absolute position in fd.data into useful error info
proc getContext(self: Reporter, pos: int): tuple[line: string, lnum: int, lpos: int] =
    #find which line of fd.data error is on
    var line_num = 1
    for i in countup(0, pos-1):
        if self.fd.data[i] == '\n':
            line_num += 1
    #find the start of the line that error is on
    var start = pos
    while start > 0 and self.fd.data[start-1] != '\n':
        start -= 1
    #find the end of the line that error is on
    var stop = pos
    while stop < self.fd.data.len-1 and self.fd.data[stop+1] != '\n':
        stop += 1
    return (self.fd.data[start .. stop], line_num, pos - start)

proc report*(self: var Reporter, msg: string, pos: int, len: Positive = 1) =
    let (line, line_num, line_pos) = self.getContext(pos)
    stdout.styledWrite fgRed, &"Error: {msg}\nat line {line_num}, pos {line_pos}:\n"
    echo line
    styledEcho fgRed, &"{' '.repeat(line_pos)}{'^'.repeat(len)}"
    #styledEcho fgRed, &"Error: {msg}\nat line {line_num}, pos {line_pos}:\n{line}\n{'~'.repeat(line_pos)}^\n"
    self.hadError = true
