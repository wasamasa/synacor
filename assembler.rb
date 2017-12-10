#!/usr/bin/env ruby

require_relative 'util'

INSTRUCTION_TO_ID = {
  halt: 0,
  set: 1,
  push: 2,
  pop: 3,
  eq: 4,
  gt: 5,
  jmp: 6,
  jt: 7,
  jf: 8,
  add: 9,
  mult: 10,
  mod: 11,
  and: 12,
  or: 13,
  not: 14,
  rmem: 15,
  wmem: 16,
  call: 17,
  ret: 18,
  out: 19,
  in: 20,
  noop: 21
}.freeze

def parse_literal(arg)
  literal = arg.to_i
  assert(literal >= 0 && literal < 32_776)
  literal
end

def parse_register(arg)
  register = arg.to_i + 32_768
  assert(register >= 32_768 && register < 32_776)
  register
end

def parse_instruction_or_label(arg, labels)
  label = labels[arg]
  instruction = INSTRUCTION_TO_ID[arg.downcase.to_sym]
  result = label || instruction
  raise("unknown label or instruction: #{arg}") unless result
  result
end

def parse_escape(arg)
  case arg
  when '\a' then "\a"
  when '\b' then "\b"
  when '\t' then "\t"
  when '\n' then "\n"
  when '\v' then "\v"
  when '\f' then "\f"
  when '\r' then "\r"
  when '\s' then ' ' # stolen from elisp
  end
end

def parse_char(arg)
  if arg.length == 1
    arg.ord
  elsif arg[/^\\[abtnvfrs]$/]
    parse_escape(arg).ord
  else
    raise('invalid character')
  end
end

def arg_to_int(arg, labels)
  case arg
  when /^[0-9]+$/ then parse_literal(arg)
  when /^r([0-9]+)$/ then parse_register($1)
  when /^[a-zA-Z0-9_]+$/ then parse_instruction_or_label(arg, labels)
  when /^'([^']+)'$/ then parse_char($1)
  else raise("unknown arg type for: #{arg}")
  end
end

def strip_labels!(words)
  labels = {}
  i = 0
  words.delete_if do |word|
    is_label = word[/:$/]
    label = is_label ? word.chop : word
    labels[label] = i if is_label
    i += 1 unless is_label
    is_label
  end
  labels
end

def assemble(inpath, outpath)
  # TODO: use a proper lexer to handle comments and ' '
  words = File.open(inpath) { |f| f.read.split }
  labels = strip_labels!(words)
  values = words.map { |word| arg_to_int(word, labels) }
  spit(outpath, values)
end

if ARGV.length == 2
  assemble(*ARGV)
else
  puts 'usage: assembler.rb <in.syn> <out.bin>'
  exit(1)
end
