package main
import "core:bytes"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:testing"

// Owns asm_nodes, extra and errors must free those
Assembly :: struct {
	root: Asm_Root,
}

Asm_Root :: struct {
	function: Asm_Fn,
}

Asm_Fn :: struct {
	// Instructions refer to opers by index
	name:  string,
	insts: []Asm_Inst,
	opers: []Asm_Opr,
}

asm_deinit :: proc(assm: ^Assembly) {
    delete(assm.root.function.opers)
	delete(assm.root.function.insts)
}

Asm_Ret :: struct {}

Asm_Unary_Tag :: enum {
	neg,
	not,
}

Asm_Unary :: struct {
	op:  Asm_Unary_Tag,
	opr: Asm_Opr,
}
Asm_Mov :: struct {
	src: Asm_Opr,
	dst: Asm_Opr,
}
Asm_Alloc_Stack :: struct {
	val: int,
}

Asm_Inst :: union {
	Asm_Ret,
	Asm_Unary,
	Asm_Mov,
	Asm_Alloc_Stack,
}

Asm_Reg :: enum u8 {
	ax,
	r10,
}

Asm_Imm :: struct {
	val: int,
}

Asm_Pseudo :: struct {
	tmp: int,
}

Asm_Stack :: struct {
	val: int,
}

Asm_Opr :: union {
	Asm_Reg,
	Asm_Imm,
	Asm_Pseudo,
	Asm_Stack,
}

assembly :: proc(src: string) -> (assem: Assembly, ok: bool) {
	ta := tacky(src) or_return
	defer tacky_deinit(&ta)
	return asm_generate(ta), true
}

asm_generate :: proc(tacky: Tacky) -> Assembly {
	asm_fn := asm_gen_fn(tacky.root.function)
	return Assembly{root = {function = asm_fn}}
}

// Do not own its data
Asm_Generator :: struct {
	tfn:        Tacky_Fn,
	stack_size: int,
	opers:      [dynamic]Asm_Opr,
	insts:      [dynamic]Asm_Inst,
}

asm_gen_fn :: proc(tfn: Tacky_Fn) -> Asm_Fn {
	ag := Asm_Generator {
		tfn = tfn,
	}

	asm_append_inst(&ag, Asm_Alloc_Stack{val = 101010})
	for tinst in tfn.insts {
		asm_gen_inst(&ag, tinst)
	}
	// Fixup the alloc size
	ag.insts[0] = Asm_Alloc_Stack{ag.stack_size}

	return Asm_Fn{name = tfn.name, opers = ag.opers[:], insts = ag.insts[:]}
}

asm_gen_inst :: proc(ag: ^Asm_Generator, ti: Tacky_Inst) {
	switch (ti.tag) {
	case .ret:
		tacky_src := ag.tfn.vals[ti.src1]
		src := tacky_val_to_asm_oper(ag, tacky_src)
		dst := Asm_Reg{}
		asm_append_inst(ag, Asm_Mov{src = src, dst = dst})
		asm_append_inst(ag, Asm_Ret{})
	case .neg, .comp:
		tacky_src := ag.tfn.vals[ti.src1]
		tacky_dst := ag.tfn.vals[ti.dst]
		src := tacky_val_to_asm_oper(ag, tacky_src)
		dst := tacky_val_to_asm_oper(ag, tacky_dst)
		if tacky_src.tag == .var && tacky_dst.tag == .var {
			// When both are var need to split the function in two movl
			asm_append_inst(ag, Asm_Mov{src = src, dst = Asm_Reg.r10})
			asm_append_inst(ag, Asm_Mov{src = Asm_Reg.r10, dst = dst})
		} else {
			asm_append_inst(ag, Asm_Mov{src = src, dst = dst})
		}
		unary_tag := tacky_unary_to_asm_unary(ti.tag)
		asm_append_inst(ag, Asm_Unary{op = unary_tag, opr = dst})
	}
}

asm_append_inst :: proc(ag: ^Asm_Generator, inst: Asm_Inst) {
	append(&ag.insts, inst)
}

tacky_unary_to_asm_unary :: proc(tinst: Tacky_Tag) -> Asm_Unary_Tag {
	#partial switch (tinst) {
	case .comp:
		return .not
	case .neg:
		return .neg
	case:
		fmt.panicf("Can not convert tacky tag: '%s' into asm unary tag", tinst)
	}

	return {}
}

tacky_val_to_asm_oper :: proc(ag: ^Asm_Generator, tval: Tacky_Val) -> Asm_Opr {
	switch (tval.tag) {
	case .var:
	    stack_pos := (tval.val + 1) * 4
		ag.stack_size = max(ag.stack_size, stack_pos)
		return Asm_Stack{val = -stack_pos}
	case .const:
		return Asm_Imm{val = tval.val}
	}

	return {}
}

@(test)
asm_generator_test :: proc(t: ^testing.T) {
	src := "int main(void) { return 2; }"
	assem, ok := assembly(src)
	defer asm_deinit(&assem)

	buffer := bytes.Buffer{}
	defer bytes.buffer_destroy(&buffer)
	asm_emit(bytes.buffer_to_stream(&buffer), assem)

	expected: string = `.globl _main
_main:
movl $2, %eax
ret
`
	testing.expect_value(t, bytes.buffer_to_string(&buffer), expected)
}
