package main
import "core:fmt"
import "core:strconv"
import "core:testing"
import "core:bytes"

Tacky :: struct {
	root: Tacky_Root,
}

tacky_deinit :: proc(t: ^Tacky) {
	delete(t.root.function.vals)
	delete(t.root.function.insts)
}

Tacky_Root :: struct {
	function: Tacky_Fn,
}

Tacky_Fn :: struct {
	name:  string,
	vals:  []Tacky_Val,
	insts: []Tacky_Inst,
}

Tacky_Tag :: enum {
	// ret value in src1
	ret,
	// src in src1 and dst in dst
	neg,
	// src in src1 and dst in dst
	comp,
}

Tv_Tag :: enum {
	var,
	const,
}

Tacky_Val :: struct {
	tag: Tv_Tag,
	val: int,
}

Tacky_Val_Idx :: int
Tacky_Inst :: struct {
	tag:  Tacky_Tag,
	src1: Tacky_Val_Idx,
	src2: Tacky_Val_Idx,
	dst:  Tacky_Val_Idx,
}

tacky :: proc(src: string) -> (tacky: Tacky, rok: bool) {
	ast, ok := parse(src)
	defer ast_deinit(&ast)
	if (!ok) {
		print_errors(ast.errors, src)
		return {}, false
	}

	tacky = generate_tacky(ast)
	return tacky, true
}

generate_tacky :: proc(ast: Ast) -> Tacky {
	root_ast_node := ast.nodes[0]
	fn_ast_node := ast.nodes[root_ast_node.lhs]
	tacky_fn := gen_tacky_fn(ast, fn_ast_node)

	return Tacky{root = {function = tacky_fn}}
}

Tacky_Generator :: struct {
	ast:   Ast,
	vals:  [dynamic]Tacky_Val,
	insts: [dynamic]Tacky_Inst,
}

gen_tacky_fn :: proc(ast: Ast, ast_node: Node) -> Tacky_Fn {
	name_node := ast.nodes[ast_node.lhs]
	name_token := ast.tokens[name_node.main_token]

	tg := Tacky_Generator {
		ast = ast,
	}

	gen_tacky_process_stmt(&tg, ast.nodes[ast_node.rhs])

	return Tacky_Fn {
		name = string(ast.src[name_token.start:name_token.end]),
		vals = tg.vals[:],
		insts = tg.insts[:],
	}
}

gen_tacky_process_stmt :: proc(tg: ^Tacky_Generator, ast_node: Node) {
	#partial switch (ast_node.tag) {
	case .stmt_return:
		gen_tacky_return(tg, ast_node)
	case:
		fmt.panicf("Unknow node %s when processing tacky stmt", ast_node.tag)
	}
}

gen_tacky_return :: proc(tg: ^Tacky_Generator, ast_node: Node) {
	exp_node := tg.ast.nodes[ast_node.lhs]
	val_idx := gen_tacky_expr(tg, exp_node)
	tacky_add_instr(tg, Tacky_Inst{tag = .ret, src1 = val_idx})
}

gen_tacky_expr :: proc(tg: ^Tacky_Generator, ast_node: Node) -> Tacky_Val_Idx {
	#partial switch (ast_node.tag) {
	case .exp_integer:
		int_token := tg.ast.tokens[ast_node.main_token]
		int_value, ok := strconv.parse_int(tg.ast.src[int_token.start:int_token.end])
		assert(ok, "Couldn't convert int in gen_tacky_expr")
		return tacky_add_constant(tg, int_value)
	case .exp_negate_op, .exp_complement_op:
		inner_node := tg.ast.nodes[ast_node.lhs]
		src := gen_tacky_expr(tg, inner_node)
		dst := tacky_make_temporary(tg)
		tacky_op := tacky_op_from_ast_op(ast_node.tag)
		tacky_add_instr(tg, Tacky_Inst{tag = tacky_op, src1 = src, dst = dst})
		return dst
	case:
		fmt.panicf("Unknow expression node %s", ast_node.tag)
	}

	assert(false, "Unreachable")
	return -1
}

tacky_op_from_ast_op :: proc(node_tag: Node_Tag) -> Tacky_Tag {
	#partial switch (node_tag) {
	case .stmt_return:
		return .ret
	case .exp_negate_op:
		return .neg
	case .exp_complement_op:
		return .comp
	case:
		fmt.panicf("Can not convert from node tag: %s,  to tacky tag", node_tag)
	}
}

tacky_add_instr :: proc(tg: ^Tacky_Generator, inst: Tacky_Inst) {
	append(&tg.insts, inst)
}

tacky_add_constant :: proc(tg: ^Tacky_Generator, const: int) -> Tacky_Val_Idx {
	result := len(tg.vals)
	append(&tg.vals, Tacky_Val{tag = .const, val = const})
	return result
}

__global_tacky_temp: int = 0
tacky_make_temporary :: proc(tg: ^Tacky_Generator) -> Tacky_Val_Idx {
	result := len(tg.vals)
	append(&tg.vals, Tacky_Val{tag = .var, val = __global_tacky_temp})
	__global_tacky_temp += 1
	return result
}


@(test)
tacky_test :: proc(t: ^testing.T) {
	src := "int main(void) { return ~(-2); }"
	ta, ok := tacky(src)
	defer tacky_deinit(&ta)

	buffer := bytes.Buffer{}
	defer bytes.buffer_destroy(&buffer)
	tacky_render(bytes.buffer_to_stream(&buffer), ta)

	expected: string = `main:
    tmp.0 = -2
    tmp.1 = ~tmp.0
    ret tmp.1
`
	testing.expect_value(t, bytes.buffer_to_string(&buffer), expected)
}
