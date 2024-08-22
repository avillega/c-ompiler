package main
import "core:fmt"
import "core:os"
import "core:io"

asm_emit :: proc(w: io.Stream, assem: Assembly) {
    asm_emit_elem(w, assem, 0)
}

asm_emit_elem :: proc(w: io.Stream, assem: Assembly, asm_idx: Asm_Idx) {
	asm_node := assem.asm_nodes[asm_idx]
	switch (asm_node.tag) {
	// lhs -> function element
	case .root:
		asm_emit_root(w, assem, asm_node)
	// value: name, lhs -> start_subrange, rhs -> end_subrange
	case .function:
		asm_emit_function(w, assem, asm_node)
	// no data
	case .ins_return:
		asm_emit_ret(w, assem, asm_node)
	// lhs -> src, rhs -> dst
	case .ins_move:
		asm_emit_mov(w, assem, asm_node)
	// value -> actual value
	case .opr_imm:
		asm_emit_imm(w, assem, asm_node)
	// always eax for now
	case .opr_reg:
		asm_emit_reg(w, assem, asm_node)
	}
}

asm_emit_root :: proc(w: io.Stream, assem: Assembly, asm_node: Asm_Node) {
    // For macos just emit its contained function
    asm_emit_elem(w, assem, asm_node.lhs)
}

asm_emit_function :: proc(w: io.Stream, assem: Assembly, asm_node: Asm_Node) {
    name := asm_node.value
    fmt.wprintf(w, ".globl _%s\n", name)
    fmt.wprintf(w, "_%s:\n", name)

    for inst_idx in asm_node.lhs..<asm_node.rhs  {
        asm_emit_elem(w, assem, inst_idx)
    }
}

asm_emit_ret :: proc(w: io.Stream, assem: Assembly, asm_node: Asm_Node) {
    fmt.wprint(w, "ret\n")
}

asm_emit_mov :: proc(w: io.Stream, assem: Assembly, asm_node: Asm_Node) {
    fmt.wprint(w, "movl ")
    asm_emit_elem(w, assem, asm_node.lhs) // emit src
    fmt.wprint(w, ", ")
    asm_emit_elem(w, assem, asm_node.rhs) // emit dst
    fmt.wprint(w, "\n")
}

// OPERANDS emition
// The functions below shouldn't add endl when emmiting since they are operands
asm_emit_imm :: proc(w: io.Stream, assem: Assembly, asm_node: Asm_Node) {
    fmt.wprintf(w, "$%d", asm_node.value)
}
asm_emit_reg :: proc(w: io.Stream, assem: Assembly, asm_node: Asm_Node) {
    fmt.wprint(w, "%eax")
}
