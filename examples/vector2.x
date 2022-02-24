import std::io;

template Vector2(T) {
    struct Vector2<`T`> {
	    x: `T`;
	    y: `T`;
    }

    fun Vector2<`T`>::make(x: `T`, y: `T`) Vector2<`T`> {
	    return Vector2<`T`>{x: x, y: y};
    }

    @[bind_op: "+"]
    fun add(v: Vector2<`T`>, w: Vector2<`T`>) Vector2<`T`> {
	    return Vector2<`T`>{x: v.x + w.x, y: v.y + w.y}; 
    }

    def std::io::Display for Vector2<`T`> {
	    fun writeTo(let self, out: Output) bool {
		    return
			    out->write('(')
		    and self.x->writeTo(out: out)
		    and out->write(',')
		    and self.y->writeTo(out: out)
		    and out->write(')');
	    }
    }
}

entry {
	let V = Vector2::make(x: 1, y: 1);
	let W = Vector2::make(x: -1, y: -1);
	let X = V + W;
	
	var out = std::io::StdOutput::make() as std::io::Output;
	
	out->writeFmt("_ + _ = _\n", Display[V, W, X]);
}

import std::check;

fun writeFmt(self: std::io::Output, fmt: let byte[], args: std::io::Display) bool {
	let argc = len args;
	std::check::assert(cond: argc <= 9);
	let length = len fmt - 1;
	
	let index = 0;
	let i = 0;
	while i < length {
		var success = false;
		if fmt[i] == '_' and fmt[i+1] != '_' {
			success = args[index]->writeTo(out: self);
		}else{
			success = self->write(fmt[i]);
		}
		
		if not success {
			return false;
		}
		
		i += 1;
	}
	return true;
}
