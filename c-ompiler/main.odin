package main
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:io"


main :: proc() {
	args := os.args
	if len(args) < 2 {
		fmt.eprintfln("Missing INPUT_FILE")
		os.exit(2)
	}

	input_name := args[1]
	command, ok := parse_arg_commands(args[2:])
	if !ok {
		fmt.eprintfln("Unknown command flag")
		os.exit(2)
	}

	src, ok2 := os.read_entire_file_from_filename(input_name)
	defer delete(src)
	if (!ok2) {
		fmt.eprintfln("Couln't read file: %s", input_name)
		os.exit(2)
	}


	if (command == .lex) {
		lexer := Lexer {
			src = src,
		}

		for {
			token := lexer_next_token(&lexer)
			if (token.tag == .eof) do break

			fmt.printfln(".%s: %s", token.tag, src[token.start:token.end])
		}
		return
	}

	if (command == .parse) {
		ast := parse(string(src))
		defer ast_deinit(&ast)

		s := ast_render(ast)
		defer delete(s)

		fmt.print(s)
		return
	}

	// code_gen and emit the .s file
	ast := parse(string(src))
	defer ast_deinit(&ast)

	assem := asm_generate(&ast)
	defer asm_deinit(&assem)

	stream: io.Stream
	if (command == .code_gen) {
		stream = os.stream_from_handle(os.stdout)
		asm_emit(stream, assem)
	} else {
		stem := filepath.short_stem(input_name)
		outputfile_name := fmt.tprintf("%s.s", stem)
		output_fd, err := os.open(outputfile_name, os.O_RDWR | os.O_CREATE, 0o666)
		if err != 0 {
			fmt.println("Error creating file:", err)
			return
		}
		defer os.close(output_fd)

		stream = os.stream_from_handle(output_fd)
		asm_emit(stream, assem)
	}
}

Command :: enum {
	lex,
	parse,
	code_gen,
	none,
}

parse_arg_commands :: proc(args: []string) -> (Command, bool) {
	command := Command.none
	for arg in args {
		switch arg {
		case "--lex":
			command = .lex
		case "--parse":
			command = .parse
		case "--code_gen":
			command = .code_gen
		case:
			return .none, false
		}
	}

	return command, true
}
