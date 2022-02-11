import token
import reader

var r = makeReader("entry { var a = 4; }")

#[
while not r.atEnd():
    let t = r.readToken()
    discard stdin.readLine()
    echo t
]#

let tokens = r.readTokens()
echo tokens

#echo CompoundOperators
#let x = CompoundOperators[4]
