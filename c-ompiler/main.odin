package main
import "core:fmt"
import "core:io"
import "core:os"
import "core:path/filepath"
import "core:mem"


main :: proc() {
    // Setup the tracking allocator
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

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

	file_content, ok2 := os.read_entire_file_from_filename(input_name)
	defer delete(file_content)
	if (!ok2) {
		fmt.eprintfln("Couln't read file: %s", input_name)
		os.exit(2)
	}

	src := string(file_content)

	if (command == .lex) {
		lexer := Lexer {
			src = src,
		}

		for {
			token := lexer_next_token(&lexer)
			if (token.tag == .eof) do break
			if (token.tag == .invalid) {
				fmt.eprintfln("invalid token: %s", src[token.start:token.end])
				os.exit(42)
			}

			fmt.printfln(".%s: %s", token.tag, src[token.start:token.end])
		}
		return
	}

	if command == .parse {
		ast, parse_ok := parse(string(src))
		defer ast_deinit(&ast)

		if !parse_ok {
			print_errors(ast.errors, src)
			os.exit(42)
		}

		s := ast_render(ast)
		defer delete(s)

		fmt.print(s)
		return
	}

	if command == .tacky {
		t, ok := tacky(src)
		defer tacky_deinit(&t)
		if !ok {
			os.exit(42)
		}

		tacky_render(os.stream_from_handle(os.stdout), t)
		return
	}

	// code_gen and emit the .s file

	assem, asm_ok := assembly(src)
	defer asm_deinit(&assem)
	if !asm_ok {
	   os.exit(42)
	}

	stream: io.Stream
	if command == .code_gen {
		stream = os.stream_from_handle(os.stdout)
		asm_emit(stream, assem)
	} else {
		stem := filepath.stem(input_name)
		dir := filepath.dir(input_name)
		defer delete(dir)

		outputfile_name := fmt.tprintf("%s/%s.s", dir, stem)
		fmt.println(outputfile_name)
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
	tacky,
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
		case "--tacky":
			command = .tacky
		case "--code_gen":
			command = .code_gen
		case:
			return .none, false
		}
	}

	return command, true
}
