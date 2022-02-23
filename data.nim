type
    Data* = object
        #name of current file
        name*: string
        #blob of source code to work on
        src*: string

proc newData*(name: string, src: string): ref Data =
    var data = new(Data)
    data[] = Data(name: name, src: src)
    return data
