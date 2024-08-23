package main
import "core:log"
import "core:odin/tokenizer"
import "core:testing"

Token_Tag :: enum {
	invalid,
	l_paren,
	r_paren,
	l_brace,
	r_brace,
	semicolon,
	tilde,
	minus,
	minus_minus,
	identifier,
	keyword_void,
	keyword_return,
	keyword_int,
	constant,
	eof,
}

@(private)
keyword_map := map[string]Token_Tag {
	"void"   = .keyword_void,
	"return" = .keyword_return,
	"int"    = .keyword_int,
}

Token :: struct {
	tag:   Token_Tag,
	start: int,
	end:   int,
}

Lexer :: struct {
	idx: int,
	src: []u8,
}

lexer_next_token :: proc(l: ^Lexer) -> Token {
	result: Token = {
		start = l.idx,
	}

	State :: enum {
		start,
		identifier,
		minus,
		constant,
	}

	state: State = .start

	loop: for ;; l.idx += 1 {
		c := read_byte(l)
		switch (state) {
		case .start:
			switch (c) {
			case 0:
				return Token{tag = .eof, start = l.idx, end = l.idx}
			case '\n', ' ', '\t', '\r':
				result.start += 1
				continue
			case ';':
				result.tag = .semicolon
				l.idx += 1
				break loop
			case '(':
				result.tag = .l_paren
				l.idx += 1
				break loop
			case ')':
				result.tag = .r_paren
				l.idx += 1
				break loop
			case '{':
				result.tag = .l_brace
				l.idx += 1
				break loop
			case '}':
				result.tag = .r_brace
				l.idx += 1
				break loop
			case '~':
				result.tag = .tilde
				l.idx += 1
				break loop
			case '-':
				state = .minus
				result.tag = .minus
			case 'a' ..= 'z', 'A' ..= 'Z', '_':
				state = .identifier
				result.tag = .identifier
			case '0' ..= '9':
				state = .constant
				result.tag = .constant
			case:
				result.tag = .invalid
				result.end = l.idx
				l.idx = len(l.src)
				return result
			}

		case .identifier:
			switch (c) {
			case '0' ..= '9', 'a' ..= 'z', 'A' ..= 'Z', '_':
				continue
			case:
				tag, ok := keyword_map[string(l.src[result.start:l.idx])]
				if (ok) {
					result.tag = tag
				}
				break loop
			}

		case .constant:
			switch (c) {
			case '0' ..= '9':
				continue
			case 'a' ..= 'z', 'A' ..= 'Z', '_':
				result.tag = .invalid
			case:
				break loop
			}

		case .minus:
			switch (c) {
			case '-':
				result.tag = .minus_minus
				l.idx += 1
				break loop
			case:
				break loop
			}
		}
	}

	result.end = l.idx
	return result
}

@(private)
read_byte :: #force_inline proc(l: ^Lexer) -> u8 {
	if (l.idx >= len(l.src)) do return 0
	return l.src[l.idx]
}


@(test)
lexer_test :: proc(t: ^testing.T) {
	test_lexer :: proc(t: ^testing.T, src: []u8, expected: []Token_Tag) {
		lexer := Lexer {
			idx = 0,
			src = src,
		}

		for expected_tag in expected {
			token := lexer_next_token(&lexer)
			testing.expect_value(t, token.tag, expected_tag)
			if (token.tag == .invalid) do break
		}

		// Last element should always be eof
		eof := lexer_next_token(&lexer)
		testing.expect_value(t, eof.tag, Token_Tag.eof)
	}

	src: string = " { ( ) } ; "
	test_lexer(
		t,
		transmute([]u8)src,
		[]Token_Tag{.l_brace, .l_paren, .r_paren, .r_brace, .semicolon},
	)

	src = "`"
	test_lexer(
		t,
		transmute([]u8)src,
		[]Token_Tag{.invalid},
	)

	src = "-2 --2 -~2 ~2 ~~2"
	test_lexer(
		t,
		transmute([]u8)src,
		[]Token_Tag {
			.minus,
			.constant,
			.minus_minus,
			.constant,
			.minus,
			.tilde,
			.constant,
			.tilde,
			.constant,
			.tilde,
			.tilde,
			.constant,
		},
	)
	src = "main other"
	test_lexer(t, transmute([]u8)src, []Token_Tag{.identifier, .identifier})

	src = "   {main}   "
	test_lexer(t, transmute([]u8)src, []Token_Tag{.l_brace, .identifier, .r_brace})

	src = "void return int main"
	test_lexer(
		t,
		transmute([]u8)src,
		[]Token_Tag{.keyword_void, .keyword_return, .keyword_int, .identifier},
	)

	src = "int main(void) { return 2; }"
	test_lexer(
		t,
		transmute([]u8)src,
		[]Token_Tag {
			.keyword_int,
			.identifier,
			.l_paren,
			.keyword_void,
			.r_paren,
			.l_brace,
			.keyword_return,
			.constant,
			.semicolon,
			.r_brace,
		},
	)

	src = "1foo"
	test_lexer(
		t,
		transmute([]u8)src,
		[]Token_Tag {
		  .invalid,
		},
	)
}
