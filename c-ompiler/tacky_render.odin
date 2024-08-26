package main
import "core:fmt"
import "core:io"
import "core:strings"

tacky_render :: proc(w: io.Stream, tacky: Tacky) {
	tacky_render_root(w, tacky.root)
}

tacky_render_root :: proc(w: io.Stream, root: Tacky_Root) {
	tacky_render_fn(w, root.function)
}

tacky_render_fn :: proc(w: io.Stream, fn: Tacky_Fn) {
	fmt.wprintfln(w, "%s:", fn.name)
	for inst in fn.insts {
		tacky_render_inst(w, inst, fn.vals)
	}
}

tacky_render_inst :: proc(w: io.Stream, inst: Tacky_Inst, vals: []Tacky_Val) {
	switch (inst.tag) {
	case .ret:
		fmt.wprintf(w, "    ret ")
		tacky_render_val(w, vals[inst.src1])
	case .neg:
		fmt.wprintf(w, "    ")
		tacky_render_val(w, vals[inst.dst])
		fmt.wprintf(w, " = -")
		tacky_render_val(w, vals[inst.src1])
	case .comp:
		fmt.wprintf(w, "    ")
		tacky_render_val(w, vals[inst.dst])
		fmt.wprintf(w, " = ~")
		tacky_render_val(w, vals[inst.src1])
	}
	fmt.wprintf(w, "\n")
}

tacky_render_val :: proc(w: io.Stream, val: Tacky_Val) {
	switch (val.tag) {
	case .const:
		fmt.wprintf(w, "%d", val.val)
	case .var:
		fmt.wprintf(w, "tmp.%d", val.val)
	}
}
