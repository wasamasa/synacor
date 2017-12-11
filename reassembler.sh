#!/bin/bash

set -e

tmpfile=$(mktemp)
trap "rm -f $tmpfile" EXIT

if [[ -n "$1" && -n "$2" ]]; then
    ./disassembler.rb "$1" | sed -r 's/ *[0-9]+ \| (.*)/\1/' > "$tmpfile"
    ./assembler.rb "$tmpfile" "$2"
    cmp "$1" "$2"
else
    printf 'usage: %s <in.bin> <out.bin>\n' "$0"
    exit 1
fi
