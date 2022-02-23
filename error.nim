import strutils
import strformat
import terminal

import data

type
    Reporter* = object
        hadError*: bool

proc makeReporter*(): Reporter = Reporter()

#internal utility that converts an absolute position in data into useful error info
#it's a bit broken right now
proc getContext(data: ref Data, pos: Natural): tuple[line: string, lnum: int, lpos: int] =
    #find which line of fd.data error is on
    var line_num = 1
    for i in countup(0, pos-1):
        if data.src[i] == '\n':
            line_num += 1
    #find the start of the line that error is on
    var start = pos
    while start > 0 and data.src[start-1] != '\n':
        start -= 1
    #find the end of the line that error is on
    var stop = pos
    while stop < data.src.len-1 and data.src[stop+1] != '\n':
        stop += 1
    return (data.src[start .. stop], line_num, pos - start)

proc report*(self: var Reporter, data: ref Data, pos: Natural, len: Positive, msg: string) =
    let (line, line_num, line_pos) = getContext(data, pos)
    stdout.styledWrite fgRed, &"Error: {msg}\nin file \"{data.name}\" at line {line_num}, pos {line_pos}:\n"
    echo line
    styledEcho fgRed, &"{' '.repeat(line_pos)}{'^'.repeat(len)}"
    #styledEcho fgRed, &"Error: {msg}\nat line {line_num}, pos {line_pos}:\n{line}\n{'~'.repeat(line_pos)}^\n"
    self.hadError = true

proc report*(self: var Reporter, data: ref Data, pos: Natural, msg: string) = self.report(data, pos, 1, msg)
