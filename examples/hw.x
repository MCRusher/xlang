import Std::Io;

entry {
	var out = Std::Io::StdOutput::Make();
	out->Write("Hello, World!\n");
}
