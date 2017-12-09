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
  assert(literal >= 0 && literal < 32_768)
  literal
end

def parse_register(arg)
  register = arg.to_i + 32_768
  assert(register >= 32_768 && register < 32_776)
  register
end

def parse_instruction(arg)
  instruction = INSTRUCTION_TO_ID[arg.downcase.to_sym]
  assert(instruction)
  instruction
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

def arg_to_int(arg)
  case arg
  when /^[0-9]+$/ then parse_literal(arg)
  when /^r([0-9]+)$/ then parse_register($1)
  when /^[a-zA-Z]{2,4}$/ then parse_instruction(arg)
  when /^'([^']+)'$/ then parse_char($1)
  else raise("unknown arg type for: #{arg}")
  end
end

def assemble(inpath, outpath)
  words = File.open(inpath) { |f| f.read.split }
  values = words.map { |word| arg_to_int(word) }
  spit(outpath, values)
end

# TODO: support label syntax

if ARGV.length == 2
  assemble(*ARGV)
else
  puts 'usage: assembler.rb <in.syn> <out.bin>'
  exit(1)
end
