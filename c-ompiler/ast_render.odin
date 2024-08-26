package main
import "core:fmt"
import "core:strings"

// Caller should free i
ast_render :: proc(ast: Ast) -> string {
	sb := strings.builder_make()
	ast_render_root(ast, &sb)
	return strings.to_string(sb)
}


ast_render_root :: proc(ast: Ast, sb: ^strings.Builder) {
	root_node := ast.nodes[0]
	strings.write_string(sb, "root\n")
	ast_render_element(ast, root_node.lhs, 1, sb)
}

ast_render_element :: proc(
	ast: Ast,
	node_idx: Node_Idx,
	indentation: int,
	sb: ^strings.Builder,
	extra_pipe := false,
) {
	node := ast.nodes[node_idx]
	#partial switch (node.tag) {
	// lhs -> function element
	case .root: // Unreachable
	// lhs -> indentifier, rhs -> body
	case .function:
		ast_render_function(ast, node_idx, indentation, sb, extra_pipe)
	// lhs -> expression
	case .stmt_return:
		ast_render_stmt_return(ast, node_idx, indentation, sb, extra_pipe)
	// main_token -> actual value
	case .exp_integer:
		ast_render_integer(ast, node_idx, indentation, sb, extra_pipe)
	// main_token -> actual value
	case .identifier:
		ast_render_identifier(ast, node_idx, indentation, sb, extra_pipe)
	case .exp_negate_op, .exp_complement_op:
		ast_render_unary(ast, node_idx, indentation, sb, extra_pipe)
	}
}

ast_render_function :: proc(
	ast: Ast,
	node_idx: Node_Idx,
	indentation: int,
	sb: ^strings.Builder,
	extra_pipe := false,
) {
	// lhs -> indentifier, rhs -> body
	node := ast.nodes[node_idx]
	indent(sb, indentation, true)
	strings.write_string(sb, "function\n")
	indent(sb, indentation + 1)
	strings.write_string(sb, "name\n")
	ast_render_element(ast, node.lhs, indentation + 2, sb, true)
	indent(sb, indentation + 1, true)
	strings.write_string(sb, "body\n")
	ast_render_element(ast, node.rhs, indentation + 2, sb)

}

ast_render_stmt_return :: proc(
	ast: Ast,
	node_idx: Node_Idx,
	indentation: int,
	sb: ^strings.Builder,
	extra_pipe := false,
) {
	// lhs -> expression
	node := ast.nodes[node_idx]
	indent(sb, indentation, true)
	strings.write_string(sb, "return_stmt\n")
	ast_render_element(ast, node.lhs, indentation + 1, sb)
}

ast_render_integer :: proc(
	ast: Ast,
	node_idx: Node_Idx,
	indentation: int,
	sb: ^strings.Builder,
	extra_pipe := false,
) {
	// main_token -> actual value
	node := ast.nodes[node_idx]
	token := ast.tokens[node.main_token]
	indent(sb, indentation, true)
	fmt.sbprintf(sb, "integer {{ %s }}\n", ast.src[token.start:token.end])
}

ast_render_unary :: proc(
	ast: Ast,
	node_idx: Node_Idx,
	indentation: int,
	sb: ^strings.Builder,
	extra_pipe := false,
) {
	// main_token -> actual value
	node := ast.nodes[node_idx]
	token := ast.tokens[node.main_token]
	indent(sb, indentation, true)
	strings.write_string(sb, "unary\n")
	indent(sb, indentation + 1)
	strings.write_string(sb, "op { ")
	strings.write_string(sb, ast.src[token.start:token.end])
	strings.write_string(sb, " }\n")
	indent(sb, indentation + 1, true)
	strings.write_string(sb, "operand\n")
	ast_render_element(ast, node.lhs, indentation + 2, sb)
}

ast_render_identifier :: proc(
	ast: Ast,
	node_idx: Node_Idx,
	indentation: int,
	sb: ^strings.Builder,
	extra_pipe := false,
) {
	// main_token -> actual value
	node := ast.nodes[node_idx]
	token := ast.tokens[node.main_token]
	indent(sb, indentation, true, extra_pipe)
	fmt.sbprintf(sb, "identifier {{ %s }}\n", ast.src[token.start:token.end])
}

@(private = "file")
indent :: #force_inline proc(
	sb: ^strings.Builder,
	indent: int,
	last: bool = false,
	print_extra_pipe: bool = false,
) {
	if (indent <= 0) do return
	indent_spaces := indent - 1
	space(indent_spaces, sb, print_extra_pipe)
	ch := '└' if last else '├'
	fmt.sbprintf(sb, "%c─ ", ch)
}


@(private = "file")
space :: #force_inline proc(indent: int, sb: ^strings.Builder, print_extra_pipe: bool = false) {
	if (indent < 1) do return
	spaces := indent - 1

	s := strings.repeat("    ", spaces)
	ch := print_extra_pipe ? '│' : ' '
	defer delete(s)

	fmt.sbprintf(sb, "%s%c   ", s, ch)
}
