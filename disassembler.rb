#!/usr/bin/env ruby

require_relative 'util'

class Disassembler
  def initialize(program)
    @program = program
    @instructions = []
    @labels = {}
    @label_index = 1
    @subrs = {}
    @subr_index = 1
    @ip = 0
  end

  def gen_label(target)
    return @labels[target] if @labels[target]
    label = "label_#{@label_index}"
    @labels[target] = label
    @label_index += 1
    label
  end

  def gen_subr(target)
    return @subrs[target] if @subrs[target]
    subr = "subr_#{@subr_index}"
    @subrs[target] = subr
    @subr_index += 1
    subr
  end

  def skip(n = 1)
    @ip += n
  end

  def peek(n)
    @program.slice(@ip, n)
  end

  def pp_register(arg)
    "r#{register_index(arg)}"
  end

  def pp_value(arg)
    register?(arg) ? pp_register(arg) : arg
  end

  def pp_char(arg)
    char = arg.chr
    case char
    when "\a" then char = '\a'
    when "\b" then char = '\b'
    when "\t" then char = '\t'
    when "\n" then char = '\n'
    when "\v" then char = '\v'
    when "\f" then char = '\f'
    when "\r" then char = '\r'
    when ' '  then char = '\s'
    end
    "'#{char}'"
  end

  def halt
    skip
    'halt'
  end

  def set
    _, register, value = peek(3)
    return unless register?(register) && value
    skip(3)
    "set #{pp_register(register)} #{pp_value(value)}"
  end

  def push
    _, value = peek(2)
    return unless value
    skip(2)
    "push #{pp_value(value)}"
  end

  def pop
    _, register = peek(2)
    return unless register?(register)
    skip(2)
    "pop #{pp_register(register)}"
  end

  def eq
    _, register, arg1, arg2 = peek(4)
    return unless register?(register) && arg1 && arg2
    skip(4)
    "eq #{pp_register(register)} #{pp_value(arg1)} #{pp_value(arg2)}"
  end

  def gt
    _, register, arg1, arg2 = peek(4)
    return unless register?(register) && arg1 && arg2
    skip(4)
    "gt #{pp_register(register)} #{pp_value(arg1)} #{pp_value(arg2)}"
  end

  def jmp
    _, target = peek(2)
    return unless target
    raise('unknown jump target') if register?(target)
    skip(2)
    "jmp #{gen_label(target)}"
  end

  def jt
    _, condition, target = peek(3)
    return unless condition && target
    raise('unknown jump target') if register?(target)
    skip(3)
    "jt #{pp_value(condition)} #{gen_label(target)}"
  end

  def jf
    _, condition, target = peek(3)
    return unless condition && target
    raise('unknown jump target') if register?(target)
    skip(3)
    "jf #{pp_value(condition)} #{gen_label(target)}"
  end

  def add
    _, register, arg1, arg2 = peek(4)
    return unless register?(register) && arg1 && arg2
    skip(4)
    "add #{pp_register(register)} #{pp_value(arg1)} #{pp_value(arg2)}"
  end

  def mult
    _, register, arg1, arg2 = peek(4)
    return unless register?(register) && arg1 && arg2
    skip(4)
    "mult #{pp_register(register)} #{pp_value(arg1)} #{pp_value(arg2)}"
  end

  def mod
    _, register, arg1, arg2 = peek(4)
    return unless register?(register) && arg1 && arg2
    skip(4)
    "mod #{pp_register(register)} #{pp_value(arg1)} #{pp_value(arg2)}"
  end

  def _and
    _, register, arg1, arg2 = peek(4)
    return unless register?(register) && arg1 && arg2
    skip(4)
    "and #{pp_register(register)} #{pp_value(arg1)} #{pp_value(arg2)}"
  end

  def _or
    _, register, arg1, arg2 = peek(4)
    return unless register?(register) && arg1 && arg2
    skip(4)
    "or #{pp_register(register)} #{pp_value(arg1)} #{pp_value(arg2)}"
  end

  def _not
    _, register, arg = peek(3)
    return unless register?(register) && arg
    skip(3)
    "not #{pp_register(register)} #{pp_value(arg)}"
  end

  def rmem
    _, register, address = peek(3)
    return unless register?(register) && address
    skip(3)
    "rmem #{pp_register(register)} #{pp_value(address)}"
  end

  def wmem
    _, address, value = peek(3)
    return unless address && value
    skip(3)
    "wmem #{pp_value(address)} #{pp_value(value)}"
  end

  def call
    _, target = peek(2)
    return unless target
    skip(2)
    "call #{pp_value(target)} ; #{gen_subr(target)}"
  end

  def ret
    skip
    'ret'
  end

  def out
    _, arg = peek(2)
    return unless arg && (register?(arg) || arg < 128)
    skip(2)
    return "out #{pp_register(arg)}" if register?(arg)
    return "out #{pp_char(arg)}" if arg < 128
  end

  def _in
    _, register = peek(2)
    return unless register?(register)
    skip(2)
    "in #{pp_register(register)}"
  end

  def noop
    skip
    'noop'
  end

  def read_instruction
    case @program[@ip]
    when 0  then halt
    when 1  then set
    when 2  then push
    when 3  then pop
    when 4  then eq
    when 5  then gt
    when 6  then jmp
    when 7  then jt
    when 8  then jf
    when 9  then add
    when 10 then mult
    when 11 then mod
    when 12 then _and
    when 13 then _or
    when 14 then _not
    when 15 then rmem
    when 16 then wmem
    when 17 then call
    when 18 then ret
    when 19 then out
    when 20 then _in
    when 21 then noop
    end
  end

  def disassemble
    while @ip < @program.length
      ip = @ip # @ip might be changed by read_instruction
      instruction = read_instruction
      if instruction
        @instructions << [ip, instruction]
      else
        @instructions << [ip, @program[@ip]]
        @ip += 1
      end
    end
  end

  def pp_instructions
    lines = []
    @instructions.each do |ip, line|
      label = @labels[ip]
      subr = @subrs[ip]
      lines << "#{label}:" if label
      lines << ";; #{subr}" if subr
      lines << "#{ip.to_s.rjust(5, ' ')} | #{line}"
    end
    lines.join("\n")
  end
end

def disassemble(program)
  disassembler = Disassembler.new(program)
  disassembler.disassemble
  disassembler.pp_instructions
end

if ARGV.length == 1
  puts disassemble(slurp(ARGV[0]))
elsif ARGV.length == 2
  File.open(ARGV[1], 'w') { |f| f.puts(disassemble(slurp(ARGV[0]))) }
else
  puts 'usage: Disassembler.rb <in.bin> [out.dis]'
  exit(1)
end
