#!/usr/bin/env ruby

require_relative 'util'

class System
  def initialize
    @memory = Array.new(2**15)
    @registers = Array.new(8, 0)
    @stack = []
    @ip = 0
  end

  def load(program)
    assert(program.length <= @memory.length)
    puts "Loading up #{program.length} instructions..."
    program.each_with_index do |value, i|
      assert(value >= 0 && value < 32_776)
      @memory[i] = value
    end
  end

  def fetch
    assert(@ip < @memory.length)
    result = @memory[@ip]
    @ip += 1
    result
  end

  def register?(value)
    value >= 32_768
  end

  def register_index(value)
    assert(register?(value))
    value - 32_768
  end

  def register_value(value)
    assert(register?(value))
    @registers[value - 32_768]
  end

  def lookup(value)
    register?(value) ? register_value(value) : value
  end

  def halt
    exit(0)
  end

  def set
    register = register_index(fetch)
    value = lookup(fetch)
    @registers[register] = value
  end

  def push
    value = lookup(fetch)
    @stack.push(value)
  end

  def pop
    register = register_index(fetch)
    value = @stack.pop
    assert(value)
    @registers[register] = value
  end

  def eq
    register = register_index(fetch)
    arg1 = lookup(fetch)
    arg2 = lookup(fetch)
    if arg1 == arg2
      @registers[register] = 1
    else
      @registers[register] = 0
    end
  end

  def gt
    register = register_index(fetch)
    arg1 = lookup(fetch)
    arg2 = lookup(fetch)
    if arg1 > arg2
      @registers[register] = 1
    else
      @registers[register] = 0
    end
  end

  def jmp
    target = lookup(fetch)
    @ip = target
  end

  def jt
    condition = lookup(fetch)
    target = lookup(fetch)
    @ip = target unless condition.zero?
  end

  def jf
    condition = lookup(fetch)
    target = lookup(fetch)
    @ip = target if condition.zero?
  end

  def add
    register = register_index(fetch)
    arg1 = lookup(fetch)
    arg2 = lookup(fetch)
    @registers[register] = (arg1 + arg2) % 32_768
  end

  def mult
    register = register_index(fetch)
    arg1 = lookup(fetch)
    arg2 = lookup(fetch)
    @registers[register] = (arg1 * arg2) % 32_768
  end

  def mod
    register = register_index(fetch)
    arg1 = lookup(fetch)
    arg2 = lookup(fetch)
    @registers[register] = arg1 % arg2
  end

  def _and
    register = register_index(fetch)
    arg1 = lookup(fetch)
    arg2 = lookup(fetch)
    @registers[register] = arg1 & arg2
  end

  def _or
    register = register_index(fetch)
    arg1 = lookup(fetch)
    arg2 = lookup(fetch)
    @registers[register] = arg1 | arg2
  end

  def _not
    register = register_index(fetch)
    arg = lookup(fetch)
    @registers[register] = ~arg & (2**15 - 1)
  end

  def rmem
    register = register_index(fetch)
    address = lookup(fetch)
    value = @memory[address]
    assert(value)
    @registers[register] = value
  end

  def wmem
    address = lookup(fetch)
    value = lookup(fetch)
    @memory[address] = value
  end

  def call
    assert(@memory[@ip + 1])
    @stack.push(@ip + 1)
    target = lookup(fetch)
    @ip = target
  end

  def ret
    target = @stack.pop
    exit(0) unless target
    @ip = target
  end

  def out
    arg = lookup(fetch)
    assert(arg >= 0 && arg < 128)
    print(arg.chr)
  end

  def _in
    register = register_index(fetch)
    arg = STDIN.getc.ord
    @registers[register] = arg
  end

  def noop; end

  def step
    op = fetch
    assert(op && op >= 0 && op < 22)
    case op
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

  def run
    loop do
      step
    end
  end
end

def emulate(program)
  system = System.new
  system.load(program)
  system.run
end

if ARGV.length == 1
  emulate(slurp(ARGV[0]))
else
  puts 'usage: emulator.rb <in.bin>'
  exit(1)
end
