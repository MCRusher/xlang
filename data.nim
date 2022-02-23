type
    ReaderData* = object
        #name of current file
        name*: string
        #blob of source code to work on
        src*: string
        #current absolute position in the source code blob
        pos*: int
        #position of last filename change
        file_pos*: int
