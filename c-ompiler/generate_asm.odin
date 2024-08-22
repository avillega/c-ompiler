package main
import "core:bytes"
import "core:fmt"
import "core:log"
import "core:os"
import "core:strconv"
import "core:testing"

// Owns asm_nodes, extra and errors must free those
Assembly :: struct {
	src:       string,
	tokens:    []Token,
	asm_nodes: []Asm_Node,
	extra:     []Asm_Idx,
	errors:    []Compile_Error,
}

asm_deinit :: proc(assm: ^Assembly) {
	delete(assm.asm_nodes)
	delete(assm.extra)
	delete(assm.errors)
}

Asm_Idx :: int
Asm_Tag :: enum {
	// lhs -> function element
	root,
	// value: name, lhs -> start_subrange, rhs -> end_subrange
	function,
	// no data
	ins_return,
	// lhs -> src, rhs -> dst
	ins_move,
	// value -> actual value
	opr_imm,
	// reg no data for now is alway eax
	opr_reg,
}

Asm_Value :: union {
	int,
	string,
}

Asm_Node :: struct {
	tag:   Asm_Tag,
	value: Asm_Value,
	lhs:   Asm_Idx,
	rhs:   Asm_Idx,
}

// Do not own its data
Asm_Generator :: struct {
	n_idx:     Node_Idx,
	ast:       ^Ast,
	asm_nodes: [dynamic]Asm_Node,
	errors:    [dynamic]Compile_Error,
}

asm_generate :: proc(ast: ^Ast) -> Assembly {
	generator := Asm_Generator {
		n_idx     = 0,
		ast       = ast,
		asm_nodes = make([dynamic]Asm_Node),
		errors    = make([dynamic]Compile_Error),
	}

	asm_gen_root(&generator)

	return Assembly {
		src = ast.src,
		tokens = ast.tokens,
		asm_nodes = generator.asm_nodes[:],
		errors = generator.errors[:],
	}
}

asm_gen_root :: proc(ag: ^Asm_Generator) {
	root_ast := ag.ast.nodes[0]
	root_idx := asm_gen_add_node(ag, Asm_Node{tag = .root})
	child_idx := asm_gen_function(ag, root_ast.lhs)
	ag.asm_nodes[root_idx].lhs = child_idx
}


asm_process_terminal_value :: proc(ag: ^Asm_Generator, ast_node_idx: Node_Idx) -> Asm_Idx {
	ast_node := ag.ast.nodes[ast_node_idx]
	#partial switch (ast_node.tag) {
	// main_token -> actual value
	case .exp_integer:
		return asm_gen_imm(ag, ast_node_idx)
	case:
		assert(false) // Should be unreachable, not processing a terminal value
	}

	assert(false) // Unreachable
	return -1
}

asm_gen_function :: proc(ag: ^Asm_Generator, ast_node_idx: Node_Idx) -> Asm_Idx {
	fn_node := ag.ast.nodes[ast_node_idx]
	ident_node := ag.ast.nodes[fn_node.lhs]
	ident_token := ag.ast.tokens[ident_node.main_token]
	fn_name := ag.ast.src[ident_token.start:ident_token.end]
	result := asm_gen_add_node(ag, Asm_Node{tag = .function, value = fn_name})
	stmt_start, stmt_end := asm_process_stmt_node(ag, fn_node.rhs)
	ag.asm_nodes[result].lhs = stmt_start
	ag.asm_nodes[result].rhs = stmt_end

	return result
}

asm_process_stmt_node :: proc(
	ag: ^Asm_Generator,
	ast_node_idx: Node_Idx,
) -> (
	start: Asm_Idx,
	end: Asm_Idx,
) {
	ast_node := ag.ast.nodes[ast_node_idx]
	#partial switch (ast_node.tag) {
	case .stmt_return:
		return asm_gen_return(ag, ast_node_idx)
	case:
		assert(false) // Should be unreachable, not processing a terminal value
	}

	assert(false) // Unreachable
	return -1, -1
}

// Generates a set of nodes in the asm tree, returns the start and end of this nodes.
asm_gen_return :: proc(
	ag: ^Asm_Generator,
	ast_node_idx: Node_Idx,
) -> (
	start: Asm_Idx,
	end: Asm_Idx,
) {
	ret_node := ag.ast.nodes[ast_node_idx]
	first := asm_gen_add_node(ag, Asm_Node{tag = .ins_move})
	last := asm_gen_add_node(ag, Asm_Node{tag = .ins_return})

	op_src := asm_process_terminal_value(ag, ret_node.lhs)
	op_reg := asm_gen_register_node(ag)
	ag.asm_nodes[first].lhs = op_src
	ag.asm_nodes[first].rhs = op_reg


	return first, last + 1
}

asm_gen_imm :: proc(ag: ^Asm_Generator, ast_node_idx: Node_Idx) -> Asm_Idx {
	int_node := ag.ast.nodes[ast_node_idx]
	int_token := ag.ast.tokens[int_node.main_token]
	int_value, ok := strconv.parse_int(ag.ast.src[int_token.start:int_token.end])

	assert(ok)
	result := asm_gen_add_node(ag, Asm_Node{tag = .opr_imm, value = int_value})
	return result
}

asm_gen_register_node :: proc(ag: ^Asm_Generator) -> Asm_Idx {
	result := asm_gen_add_node(ag, Asm_Node{tag = .opr_reg})
	return result
}


asm_gen_add_node :: proc(ag: ^Asm_Generator, asm_node: Asm_Node) -> Asm_Idx {
	result := len(ag.asm_nodes)
	append(&ag.asm_nodes, asm_node)
	return result
}

@(test)
asm_generator_test :: proc(t: ^testing.T) {
	// TODO: write a test that can take a string or fd to write the asm output and
	// compare it.
	src := "int main(void) { return 2; }"
	ast := parse(src)
	defer ast_deinit(&ast)

	assem := asm_generate(&ast)
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
