#!/bin/bash

# Check if required argument is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 INPUT_FILE [--lex] [--parse] [--code_gen]"
    exit 1
fi

INPUT_FILE=$1
shift

# Extract the base name of the input file (without extension)
BASE_NAME=$(basename "$INPUT_FILE" | sed 's/\.[^.]*$//')
OUTPUT_FILE="${BASE_NAME}"

# Set default values for optional flags
LEX=false
PARSE=false
CODE_GEN=false

# Parse optional flags
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
        --code_gen)
            CODE_GEN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Generate unique filenames for intermediate files
PREPROCESSED_FILE="${BASE_NAME}.i"

# Step 1: Run GCC preprocessor
arch -x86_64 gcc -E -P "$INPUT_FILE" -o "$PREPROCESSED_FILE"

if [ $? -ne 0 ]; then
    echo "Preprocessing failed"
    rm -f "$PREPROCESSED_FILE"
    exit 1
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


odin build ./c-ompiler
./c-ompiler.bin  "$PREPROCESSED_FILE" $C_OMPILER_FLAGS

if [ $? -ne 0 ]; then
    echo "c-ompiler failed"
    rm -f "${BASE_NAME}.s"
    rm -f "$PREPROCESSED_FILE"
    exit 1
fi

if [[ ! -z $C_OMPILER_FLAGS ]]; then
    rm -f "$PREPROCESSED_FILE"
    exit 0
fi

# Step 3: Compile assembly to executable
arch -x86_64 gcc "${BASE_NAME}.s" -o "$OUTPUT_FILE"

if [ $? -ne 0 ]; then
    echo "assembler + linking failed"
    rm -f "${BASE_NAME}.s"
    rm -f "$PREPROCESSED_FILE"
    rm -f "$OUTPUT_FILE"
    exit 1
fi

echo "Compilation successful. Output file: $OUTPUT_FILE"

rm -f "$PREPROCESSED_FILE" "${BASE_NAME}.s"
