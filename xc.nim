import token as token_file
import reader as reader_file
import data as data_file
import builder as builder_file
import error
#[
const src = """
    import std::idk;
    
    template std::add(T) {
        fun std::add<`T`>(x: `T`, y: `T`) `T` {
            return x + y;
        }
    }
    
    impl std::add(int);
    
    entry {
        var a = std::add(1,2);
        let b = std::add(1,2);
    }
"""

let data = newData("<test data>", src)

var reader = makeReader(data)

var reporter = makeReporter()

let tokens = reader.readTokens(reporter)
if reporter.hadError:
    echo "OH NO AN ERROR HAPPEN!!!!"

echo tokens
]#

const src = """
import test;
"""

let data = newData("<test data>", src)

var reader = makeReader(data)
var reporter = makeReporter()

if reporter.hadError:
    echo "Error ocurred!"
    quit()
echo reader.data.src

let tokens = reader.readTokens(reporter)

if reporter.hadError:
    echo "Error ocurred!"
echo tokens

var builder = makeBuilder(tokens)

builder.build(reporter)

echo builder.toks
