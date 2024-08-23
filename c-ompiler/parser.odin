package main
import "core:fmt"
import "core:testing"

// Own its data, must free after has been used
Ast :: struct {
	src:    string,
	tokens: []Token,
	nodes:  []Node,
	errors: []Compile_Error,
}

ast_deinit :: proc(ast: ^Ast) {
    delete(ast.tokens)
    delete(ast.nodes)
    delete(ast.errors)
}

Node_Idx :: int
Token_Idx :: int
Node_Tag :: enum {
	// lhs -> function element
	root,
	// lhs -> indentifier, rhs -> body
	function,
	// lhs -> expression
	stmt_return,
	// main_token -> actual value
	exp_integer,
	// main_token -> operator, lhs -> operand (exp)
	exp_negate_op,
	// main_token -> operator, lhs -> operand (exp)
	exp_complement_op,
	// main_token -> actual value
	identifier,
}

Node :: struct {
	tag:        Node_Tag,
	main_token: Token_Idx,
	lhs:        Node_Idx,
	rhs:        Node_Idx,
	extra:      Node_Idx,
}

// Do not own its data
Parser :: struct {
	t_idx:  int,
	tokens: []Token,
	nodes:  [dynamic]Node,
	errors: [dynamic]Compile_Error,
}

parse :: proc(src: string) -> Ast {
	tokens := make([dynamic]Token)

	lexer := Lexer {
		src = transmute([]u8)src,
	}

	for {
		token := lexer_next_token(&lexer)
		append(&tokens, token)
		if (token.tag == .eof) do break
	}

	parser := Parser {
		tokens = tokens[:],
		nodes  = make([dynamic]Node),
		errors = make([dynamic]Compile_Error),
	}

	parse_root(&parser)
	return Ast{src = src, tokens = tokens[:], nodes = parser.nodes[:], errors = parser.errors[:]}
}

parse_root :: proc(p: ^Parser) {
	append(&p.nodes, Node{tag = .root, main_token = 0, lhs = -1, rhs = -1})

	function, ok := parse_function(p)

	// node 0 is the root
	p.nodes[0].lhs = function
	parser_expect_token(p, .eof)
}

parse_function :: proc(p: ^Parser) -> (result: Node_Idx, ok: bool) {
	// First create the place holder for the function data, so it is first than it childer in the node array
	result = parser_append_node(p, Node{tag = .function, main_token = p.t_idx})

	parser_expect_token(p, .keyword_int) or_return
	identifier := parse_identifier(p) or_return
	parser_expect_token(p, .l_paren) or_return
	parser_expect_token(p, .keyword_void) or_return
	parser_expect_token(p, .r_paren) or_return
	body := parse_function_body(p) or_return

	p.nodes[result].lhs = identifier
	p.nodes[result].rhs = body

	return result, true
}

parse_identifier :: proc(p: ^Parser) -> (result: Node_Idx, ok: bool) {
	tokenIdx := parser_expect_token(p, .identifier) or_return

	result = len(p.nodes)
	append(&p.nodes, Node{tag = .identifier, main_token = tokenIdx, lhs = -1, rhs = -1})

	return result, true
}

parse_function_body :: proc(p: ^Parser) -> (result: Node_Idx, ok: bool) {
	parser_expect_token(p, .l_brace) or_return
	stmt := parse_stmt(p) or_return
	parser_expect_token(p, .r_brace)
	return stmt, true
}

parse_stmt :: proc(p: ^Parser) -> (result: Node_Idx, ok: bool) {
	token := parser_peek_token(p)
	#partial switch (token.tag) {
	case .keyword_return:
		return parse_return_stmt(p)
	case:
		return -1, parser_fail(p)
	}

	// unreachable
	return -1, false
}

parse_return_stmt :: proc(p: ^Parser) -> (result: Node_Idx, ok: bool) {
	tokenIdx := parser_expect_token(p, .keyword_return) or_return

	result = parser_append_node(p, Node{tag = .stmt_return, main_token = tokenIdx})
	expression := parse_expression(p) or_return
	p.nodes[result].lhs = expression

	parser_expect_token(p, .semicolon) or_return
	return result, true
}

parse_expression :: proc(p: ^Parser) -> (result: Node_Idx, ok: bool) {
    token := parser_peek_token(p)


	tokenIdx := parser_expect_token(p, .constant) or_return
	result = parser_append_node(p, Node{tag = .exp_integer, main_token = tokenIdx})

	return result, true
}

parser_fail :: proc(p: ^Parser) -> (ok: bool) {
	append(&p.errors, Compile_Error{tag = .unexpected_token, token = p.t_idx - 1})
	return false
}

parser_append_node :: proc(p: ^Parser, node: Node) -> Node_Idx {
	result := len(p.nodes)
	append(&p.nodes, node)
	return result
}

parser_expect_token :: proc(p: ^Parser, token_tag: Token_Tag) -> (result: Token_Idx, ok: bool) {
	result = p.t_idx
	p.t_idx += 1

	if (p.tokens[result].tag != token_tag) {
		append(&p.errors, Compile_Error{tag = .unexpected_token, token = p.t_idx - 1})
		return -1, false
	}

	return result, true
}

@(private)
parser_next_token :: proc(p: ^Parser) -> Token {
	if (p.t_idx < len(p.tokens)) {
		result := p.tokens[p.t_idx]
		p.t_idx += 1
		return result
	}

	return p.tokens[len(p.tokens) - 1]
}

@(private)
parser_peek_token :: proc(p: ^Parser) -> Token {
	if (p.t_idx < len(p.tokens)) {
		result := p.tokens[p.t_idx]
		return result
	}

	return p.tokens[len(p.tokens) - 1]
}

@(test)
parser_test :: proc(t: ^testing.T) {
	src := "int main(void) { return 2; }"
	ast := parse(src)
	defer delete(ast.tokens)
	defer delete(ast.nodes)

	expected_ast := `root {
  function {
    name {
      identifier { main }
    }
    body {
      return_stmt {
        integer { 2 }
      }
    }
  }
}
`
	s := ast_render(ast)
	defer delete(s)
	testing.expect_value(t, expected_ast, s)
}
