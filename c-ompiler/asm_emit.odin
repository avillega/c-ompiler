package main
import "core:fmt"
import "core:io"
import "core:os"

asm_emit :: proc(w: io.Stream, assem: Assembly) {
	asm_emit_root(w, assem.root)
}

asm_emit_root :: proc(w: io.Stream, root: Asm_Root) {
	// For macos just emit its contained function
	asm_emit_function(w, root.function)
}

asm_emit_function :: proc(w: io.Stream, asm_fn: Asm_Fn) {
	fmt.wprintf(w, "    .globl _%s\n", asm_fn.name)
	fmt.wprintf(w, "_%s:\n", asm_fn.name)

	// Function epiloge

	fmt.wprintln(w, "    pushq %rbp")
	fmt.wprintln(w, "    movq  %rsp, %rbp")

	for inst in asm_fn.insts {
		asm_emit_instr(w, inst)
	}
}

asm_emit_instr :: proc(w: io.Stream, inst: Asm_Inst) {
	fmt.wprint(w, "    ")
	switch ins in inst {
	case Asm_Ret:
		fmt.wprintln(w, "movq  %rbp, %rsp")
		fmt.wprintln(w, "    popq  %rbp")
		fmt.wprint(w, "    ret")
	case Asm_Mov:
		fmt.wprint(w, "movl  ")
		asm_emit_operand(w, ins.src)
		fmt.wprint(w, ", ")
		asm_emit_operand(w, ins.dst)
	case Asm_Binary:
		switch ins.op {
		case .add:
			fmt.wprint(w, "addl  ")
		case .sub:
			fmt.wprint(w, "subl  ")
		case .mul:
			fmt.wprint(w, "imull  ")
		case .or:
			fmt.wprint(w, "orl  ")
		case .xor:
			fmt.wprint(w, "xorl  ")
		case .and:
			fmt.wprint(w, "andl  ")
		case .shl:
			fmt.wprint(w, "shll  ")
		case .sar:
			fmt.wprint(w, "sarl  ")
		}
		asm_emit_operand(w, ins.src)
		fmt.wprint(w, ", ")
		asm_emit_operand(w, ins.dst)
	case Asm_Cdq:
		fmt.wprint(w, "cdq")
	case Asm_Idiv:
		fmt.wprint(w, "idivl  ")
		asm_emit_operand(w, ins.opr)
	case Asm_Unary:
		switch ins.op {
		case .neg:
			fmt.wprint(w, "negl  ")
		case .not:
			fmt.wprint(w, "notl  ")
		}
		asm_emit_operand(w, ins.opr)
	case Asm_Alloc_Stack:
		fmt.wprintf(w, "subq  $%d, %%rsp", ins.val)
	}
	fmt.wprint(w, "\n")
}


asm_emit_operand :: proc(w: io.Stream, operand: Asm_Opr) {
    reprs : [Asm_Reg]string = {
        .ax = "eax",
        .dx = "edx",
        .cx = "ecx",
        .cl = "cl",
        .r10 = "r10d",
        .r11 = "r11d",
    }
	switch opr in operand {
	case Asm_Reg:
	   fmt.wprintf(w, "%%%s", reprs[opr])
	case Asm_Imm:
		fmt.wprintf(w, "$%d", opr.val)
	case Asm_Pseudo:
		fmt.wprintf(w, "pseudo(%d)", opr.tmp)
	case Asm_Stack:
		fmt.wprintf(w, "%d(%%rbp)", opr.val)
	}
}
