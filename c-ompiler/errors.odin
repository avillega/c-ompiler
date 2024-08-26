package main
import "core:fmt"

Error_Tag :: enum {
	parse_error,
	unexpected_token,
	error_during_generation,
}

Compile_Error :: struct {
	tag:   Error_Tag,
	token: Token,
}

print_errors :: proc(errors: []Compile_Error, src: string) {
    for err in errors {
        print_error(err, src)
    }
}

print_error :: proc(err: Compile_Error, src: string) {
    switch (err.tag) {
    case .unexpected_token:
        fmt.eprintfln("Unexpected token: ", src[err.token.start:err.token.end])
    case .parse_error:
        fmt.eprintfln("Error during parsing")
    case .error_during_generation:
        fmt.eprintfln("Error during generation")
    }
}
