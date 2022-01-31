import Std::Io;

struct Vector2 {
	x: float;
	y: float;
}

fun Vector2::Make(x: float, y: float) Vector2 {
	return Vector2{x: x, y: y};
}

@[bind_op: "+"]
fun Add(v: let Vector2, w: let Vector2) Vector2 {
	return Vector2{x: v.x + w.x, y: v.y + w.y}; 
}

impl Std::Io::Display for Vector2 {
	fun WriteTo(let self, out: Output) bool {
		return
			out->Write('(')
		and self.x->WriteTo(out: out)
		and out->Write(',')
		and self.y->WriteTo(out: out)
		and out->Write(')');
	}
}

entry {
	let V = Vector2::Make(x: 1, y: 1);
	let W = Vector2::Make(x: -1, y: -1);
	let X = V + W;
	
	var out = Std::Io::StdOutput::Make() as Output;
	
	out->WriteFmt("_ + _ = _\n", Display[V, W, X]);
}

import Std::Check;

fun WriteFmt(self: Std::Io::Output, fmt: let byte[], args: Output[]) bool {
	let argc = len args;
	Std::Check::Assert(cond: argc <= 9);
	let length = len fmt - 1;
	
	let index = 0;
	let i = 0;
	while i < length {
		var success = false;
		if fmt[i] == '_' and fmt[i+1] != '_' {
			success = args[index]->WriteTo(out: self);
		}else{
			success = self->Write(fmt[i]);
		}
		
		if not success {
			return false;
		}
		
		i += 1;
	}
	return true;
}
