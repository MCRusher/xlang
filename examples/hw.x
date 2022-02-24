import std::io;

entry {
	var out = std::io::StdOutput::make();
	out->write("Hello, World!\n");
}
