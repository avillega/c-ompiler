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


Asm_Unary_Tag :: enum {
	neg,
	not,
}

Asm_Binary_Tag :: enum {
	add,
	sub,
	mul,
	sar,
	shl,
	xor,
	or,
	and,
}

Asm_Ret :: struct {}

Asm_Unary :: struct {
	op:  Asm_Unary_Tag,
	opr: Asm_Opr,
}

Asm_Binary :: struct {
	op:  Asm_Binary_Tag,
	src: Asm_Opr,
	dst: Asm_Opr,
}

Asm_Idiv :: struct {
	opr: Asm_Opr,
}

Asm_Cdq :: struct {}

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
	Asm_Binary,
	Asm_Idiv,
	Asm_Cdq,
	Asm_Mov,
	Asm_Alloc_Stack,
}

Asm_Reg :: enum u8 {
	ax,
	dx,
	cx,
	cl,
	r10,
	r11,
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
		src := tacky_idx_to_asm_opr(ag, ti.src1)
		dst := Asm_Reg.ax
		asm_gen_mov(ag, src, dst)
		asm_append_inst(ag, Asm_Ret{})
	case .neg, .comp:
		src := tacky_idx_to_asm_opr(ag, ti.src1)
		dst := tacky_idx_to_asm_opr(ag, ti.dst)
		asm_gen_mov(ag, src, dst)
		unary_tag := tacky_unary_to_asm_unary(ti.tag)
		asm_append_inst(ag, Asm_Unary{op = unary_tag, opr = dst})
	case .add, .sub, .mul, .xor, .or, .and, .shl, .shr:
		src1 := tacky_idx_to_asm_opr(ag, ti.src1)
		src2 := tacky_idx_to_asm_opr(ag, ti.src2)
		dst := tacky_idx_to_asm_opr(ag, ti.dst)
		binary_op := tacky_binary_to_asm_binary[ti.tag]
		asm_gen_binary(ag, binary_op, src1, src2, dst)
	case .div, .rem:
		src1 := tacky_idx_to_asm_opr(ag, ti.src1)
		src2 := tacky_idx_to_asm_opr(ag, ti.src2)
		dst := tacky_idx_to_asm_opr(ag, ti.dst)
		asm_gen_mov(ag, src1, Asm_Reg.ax)
		asm_append_inst(ag, Asm_Cdq{})
		asm_gen_idiv(ag, src2)
		if ti.tag == .div {
			asm_gen_mov(ag, Asm_Reg.ax, dst)
		} else if ti.tag == .rem {
			asm_gen_mov(ag, Asm_Reg.dx, dst)
		}
	}
}

asm_gen_idiv :: proc(ag: ^Asm_Generator, opr: Asm_Opr) {
	_, is_imm := opr.(Asm_Imm)
	if is_imm {
		asm_gen_mov(ag, opr, Asm_Reg.r10)
		asm_append_inst(ag, Asm_Idiv{Asm_Reg.r10})
	} else {
		asm_append_inst(ag, Asm_Idiv{opr})
	}
}

asm_gen_binary :: proc(ag: ^Asm_Generator, op: Asm_Binary_Tag, src1, src2, dst: Asm_Opr) {
	asm_gen_mov(ag, src1, dst)

	switch op {
	case .add, .sub, .xor, .or, .and:
		_, opr2_stack := src2.(Asm_Stack)
		_, dst_stack := dst.(Asm_Stack)
		if dst_stack && opr2_stack {
			// When both are var need to split the function in two operations
			asm_gen_mov(ag, src2, Asm_Reg.r10)
			asm_append_inst(ag, Asm_Binary{op = op, src = Asm_Reg.r10, dst = dst})
		} else {
			asm_append_inst(ag, Asm_Binary{op = op, src = src2, dst = dst})
		}

	case .shl, .sar:
		_, opr2_imm := src2.(Asm_Imm)
		if opr2_imm {
			asm_append_inst(ag, Asm_Binary{op = op, src = src2, dst = dst})
		} else {
			asm_gen_mov(ag, src2, Asm_Reg.cx)
			asm_append_inst(ag, Asm_Binary{op = op, src = Asm_Reg.cl, dst = dst})
		}


	case .mul:
		_, dst_is_stack := dst.(Asm_Stack)
		if dst_is_stack {
			asm_gen_mov(ag, dst, Asm_Reg.r11)
			asm_append_inst(ag, Asm_Binary{op = op, src = src2, dst = Asm_Reg.r11})
			asm_gen_mov(ag, Asm_Reg.r11, dst)
		} else {
			asm_append_inst(ag, Asm_Binary{op = op, src = src2, dst = dst})
		}
	}
}


asm_gen_mov :: proc(ag: ^Asm_Generator, src: Asm_Opr, dst: Asm_Opr) {
	_, src_is_stack := src.(Asm_Stack)
	_, dst_is_stack := dst.(Asm_Stack)
	if src_is_stack && dst_is_stack {
		// When both are var need to split the function in two movl
		asm_append_inst(ag, Asm_Mov{src = src, dst = Asm_Reg.r10})
		asm_append_inst(ag, Asm_Mov{src = Asm_Reg.r10, dst = dst})
	} else {
		asm_append_inst(ag, Asm_Mov{src = src, dst = dst})
	}

}

asm_append_inst :: proc(ag: ^Asm_Generator, inst: Asm_Inst) {
	append(&ag.insts, inst)
}

tacky_binary_to_asm_binary: [Tacky_Tag]Asm_Binary_Tag = #partial {
	.add = .add,
	.mul = .mul,
	.sub = .sub,
	.shl = .shl,
	.shr = .sar,
	.or  = .or,
	.and = .and,
	.xor = .xor,
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

tacky_idx_to_asm_opr :: proc(ag: ^Asm_Generator, t_idx: Tacky_Val_Idx) -> Asm_Opr {
	tacky_val := ag.tfn.vals[t_idx]
	return tacky_val_to_asm_oper(ag, tacky_val)
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

	expected: string = `    .globl _main
_main:
    pushq %rbp
    movq  %rsp, %rbp
    subq  $0, %rsp
    movl  $2, %eax
    movq  %rbp, %rsp
    popq  %rbp
    ret
`
	testing.expect_value(t, bytes.buffer_to_string(&buffer), expected)
}
