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

  def fetchn(n)
    assert(@ip < @memory.length)
    assert((@ip + n) <= @memory.length)
    result = @memory.slice(@ip, @ip + n)
    @ip += n
    result
  end

  def fetch2
    fetchn(2)
  end

  def fetch3
    fetchn(3)
  end

  def halt
    exit(0)
  end

  def out
    arg = fetch
    assert(arg >= 0 && arg < 128)
    print(arg.chr)
  end

  def noop; end

  def step
    op = fetch
    assert(op && op >= 0 && op < 22)
    case op
    when 0 then halt
    when 19 then out
    when 21 then noop
    else raise("unimplemented op: #{op}")
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

def slurp(path)
  result = []
  File.open(path) { |f| result << f.read_u16le until f.eof? }
  result
end

if ARGV.length == 1
  emulate(slurp(ARGV[0]))
else
  puts 'usage: emulator.rb <in.bin>'
  exit(1)
end
