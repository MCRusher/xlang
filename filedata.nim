type
    FileData* = object
        name*: string
        data*: string

proc makeFileData*(name: string, data: string): FileData = FileData(name: name, data: data)

proc newFileData*(name: string, data: string): ref FileData =
    var fd = new(FileData)
    fd[] = makeFileData(name, data)
    return fd
