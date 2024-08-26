#!/bin/bash

# Set default values for optional flags
LEX=false
PARSE=false
CODE_GEN=false
TACKY=false
INPUT_FILE=""

# Function to print usage
print_usage() {
    echo "Usage: $0 [--lex] [--parse] [--code_gen] INPUT_FILE"
    echo "Or:    $0 INPUT_FILE [--lex] [--parse] [--code_gen]"
    exit 42
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --lex)
            LEX=true
            shift
            ;;
        --parse)
            PARSE=true
            shift
            ;;
        --codegen)
            CODE_GEN=true
            shift
            ;;
        --tacky)
            TACKY=true
            shift
            ;;
        *)
            if [[ -z "$INPUT_FILE" ]]; then
                INPUT_FILE="$1"
                shift
            else
                echo "Unknown option or multiple input files specified: $1"
                print_usage
            fi
            ;;
    esac
done

# Check if input file is provided
if [[ -z "$INPUT_FILE" ]]; then
    echo "Error: No input file specified."
    print_usage
fi

# Extract the base name of the input file (without extension)
BASE_NAME="${INPUT_FILE%.*}"
OUTPUT_FILE="${BASE_NAME}"

# Generate unique filenames for intermediate files
PREPROCESSED_FILE="${BASE_NAME}.i"

# Step 1: Run GCC preprocessor
gcc -E -P "$INPUT_FILE" -o "$PREPROCESSED_FILE"
if [ $? -ne 0 ]; then
    echo "Preprocessing failed"
    rm -f "$PREPROCESSED_FILE"
    exit 42
fi

# Step 2: Run c-ompiler with appropriate flags
C_OMPILER_FLAGS=""
if $LEX; then
    C_OMPILER_FLAGS="$C_OMPILER_FLAGS --lex"
fi
if $PARSE; then
    C_OMPILER_FLAGS="$C_OMPILER_FLAGS --parse"
fi
if $CODE_GEN; then
    C_OMPILER_FLAGS="$C_OMPILER_FLAGS --code_gen"
fi
if $TACKY; then
    C_OMPILER_FLAGS="$C_OMPILER_FLAGS --tacky"
fi

"$HOME/code/c-ompiler/c-ompiler.bin" "$PREPROCESSED_FILE" $C_OMPILER_FLAGS
if [ $? -ne 0 ]; then
    echo "c-ompiler failed"
    rm -f "${BASE_NAME}.s"
    rm -f "$PREPROCESSED_FILE"
    exit 42
fi

if [[ ! -z $C_OMPILER_FLAGS ]]; then
    rm -f "$PREPROCESSED_FILE"
    exit 0
fi

# Step 3: Compile assembly to executable
gcc "${BASE_NAME}.s" -o "$OUTPUT_FILE"
if [ $? -ne 0 ]; then
    echo "assembler + linking failed"
    rm -f "${BASE_NAME}.s"
    rm -f "$PREPROCESSED_FILE"
    rm -f "$OUTPUT_FILE"
    exit 42
fi

echo "Compilation successful. Output file: $OUTPUT_FILE"
rm -f "$PREPROCESSED_FILE" "${BASE_NAME}.s"
