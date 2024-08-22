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
	strings.write_string(sb, "root {\n")
	ast_render_element(ast, root_node.lhs, 1, sb)
	strings.write_string(sb, "}\n")
}

ast_render_element :: proc(ast: Ast, node_idx: Node_Idx, indentation: int, sb: ^strings.Builder) {
	node := ast.nodes[node_idx]
	switch (node.tag) {
	// lhs -> function element
	case .root: // Unreachable
	// lhs -> indentifier, rhs -> body
	case .function:
		ast_render_function(ast, node_idx, indentation, sb)
	// lhs -> expression
	case .stmt_return:
		ast_render_stmt_return(ast, node_idx, indentation, sb)
	// main_token -> actual value
	case .exp_integer:
		ast_render_integer(ast, node_idx, indentation, sb)
	// main_token -> actual value
	case .identifier:
		ast_render_identifier(ast, node_idx, indentation, sb)
	}
}

ast_render_function :: proc(ast: Ast, node_idx: Node_Idx, indentation: int, sb: ^strings.Builder) {
	// lhs -> indentifier, rhs -> body
	node := ast.nodes[node_idx]
	ident(indentation, sb)
	strings.write_string(sb, "function {\n")
	ident(indentation + 1, sb)
	strings.write_string(sb, "name {\n")
	ast_render_element(ast, node.lhs, indentation + 2, sb)
	ident(indentation + 1, sb)
	strings.write_string(sb, "}\n")
	ident(indentation + 1, sb)
	strings.write_string(sb, "body {\n")
	ast_render_element(ast, node.rhs, indentation + 2, sb)
	ident(indentation + 1, sb)
	strings.write_string(sb, "}\n")
	ident(indentation, sb)
	strings.write_string(sb, "}\n")

}

ast_render_stmt_return :: proc(
	ast: Ast,
	node_idx: Node_Idx,
	indentation: int,
	sb: ^strings.Builder,
) {
	// lhs -> expression
	node := ast.nodes[node_idx]
	ident(indentation, sb)
	strings.write_string(sb, "return_stmt {\n")
	ast_render_element(ast, node.lhs, indentation + 1, sb)
	ident(indentation, sb)
	strings.write_string(sb, "}\n")
}

ast_render_integer :: proc(ast: Ast, node_idx: Node_Idx, indentation: int, sb: ^strings.Builder) {
	// main_token -> actual value
	node := ast.nodes[node_idx]
	token := ast.tokens[node.main_token]
	ident(indentation, sb)
	strings.write_string(sb, "integer { ")
	strings.write_string(sb, ast.src[token.start:token.end])
	strings.write_string(sb, " }\n")

}

ast_render_identifier :: proc(
	ast: Ast,
	node_idx: Node_Idx,
	indentation: int,
	sb: ^strings.Builder,
) {
	// main_token -> actual value
	node := ast.nodes[node_idx]
	token := ast.tokens[node.main_token]
	ident(indentation, sb)
	strings.write_string(sb, "identifier { ")
	strings.write_string(sb, ast.src[token.start:token.end])
	strings.write_string(sb, " }\n")
}

@(private = "file")
ident :: #force_inline proc(indentation: int, sb: ^strings.Builder) {
	indent := indentation * 2
	for i in 0 ..< indent {
		strings.write_byte(sb, ' ')
	}
}
