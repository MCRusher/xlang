# xlang

A Programming Language Project

Progress:
- Tokens design
 - [X] Streamlined adding new kinds of tokens
 - [X] String representation of tokens
 - [X] String representation of token values
 - [X] store a Data reference instead of a copy (no deep copy of strings)
 - [X] store position in source file the token was lexed from
- Reader (lexer) design
 - [X] Store a Data reference instead of owning the file state
 
- [ ] Builder (parser) design
 - [X] Import parsing with previously imported tracking
Compiler Compilation Steps:
1.  Lex initial main file into tokens
2.  process imports, lexing each into tokens and merging them into the
    main tokens until no import statements are present
3.  process template definitions, until no template definition bodies are present
4.  process template instantiations, until no template implementations are present
5.  repeat steps 2-4 until no template instantiations are left
6.  process const definitions
7.  process function definitions
8.  process function bodies
    1. redo #6
    2. parse let statements
    3. parse var statements
    4. parse other statements
9.  process entry block
10. generate C source code
11. compile with available C compiler in format specified by user:
	program, static lib, or shared lib  
END
