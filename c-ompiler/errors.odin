package main

Error_Tag :: enum {
	parseError,
	unexpected_token,
	error_during_generation,
}

Compile_Error :: struct {
	tag:   Error_Tag,
	token: Token_Idx,
}
