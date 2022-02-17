import token as token_file
import reader as reader_file
import error

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

var reader = makeReader("<test data>", src)

var reporter = makeReporter()

let tokens = reader.readTokens(reporter)
if reporter.hadError:
    echo "OH NO AN ERROR HAPPEN!!!!"

echo tokens
