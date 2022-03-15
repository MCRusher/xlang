import os
import strformat
import strutils
import terminal

import token as token_file
import reader as reader_file
import data as data_file
import builder as builder_file
import error

let args = commandLineParams()

if args.len != 1 or args[0] == "help":
    echo &"""
    Usage: xc <mode> <filename>
    modes:
     exe = build executable ('entry' is used as main program body)
     lib = build static library ('entry' is discarded)
     dll = build shared library ('entry' is discared)
    """
    #Not an error
    quit(QuitSuccess)

var filename = args[0]
#if filename ends in the '.x' extension, it will be considered
# to already be a system filename
#otherwise, the filename will be considered to be in import format and
# be converted to a system filename
if filename[^2 .. ^1] != ".x":
    filename = filename.replace("::", $DirSep) & ".x"

var data: ref Data

#create new data reference from file's name & contents
try:
    data = newData(filename, readFile(filename))
except IOError:
    styledEcho fgRed, &"Failed to open/read file \"{filename}\""
    quit()

#print source code read into data, for debugging purposes
echo "-----------[Data]------------"
echo data.src
echo "-----------------------------"

#create new reader with a reference to file's data
var reader = makeReader(data)
#create new error reporter
var reporter = makeReporter()
#lex file data into a sequence of tokens
let tokens = reader.readTokens(reporter)

#print tokens lexed, for debugging purposes
echo "-----------[Lex]-------------"
echo tokens
echo "-----------------------------"

#create new builder and give it the tokens lexed from the data
var builder = makeBuilder(tokens)
#parse tokens into build data
let program = builder.build(reporter)

#print tokens after parsing, for debugging purposes
echo "-----------[Parse]-----------"
echo builder.toks
echo "-----------------------------"

#don't try to generate code for a malformed program, just exit
#critical errors (like ICEs) will already have called quit before this point
if reporter.hadError:
    quit()

echo "-----------[Output]-----------"
echo program
echo "-----------------------------"

writeFile(filename&".c", program)
