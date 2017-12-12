#!/usr/bin/env ruby

require_relative 'util'
require 'readline'

MAX_PROGRAM_SIZE = 32_768
MAX_INT = 32_768
MAX_REGISTER = 32_776
# TODO: help, break (on pc value, instruction kind), set
SAFE_COMMANDS = [:run, :reset, :step, :show, :dump].freeze
PROMPT = 'dbg> '.freeze

class System
  def initialize(program)
    assert(program.length <= MAX_PROGRAM_SIZE)
    program.each { |value| assert(value >= 0 && value < MAX_REGISTER) }
    @program = program
  end

  def rep(op, args)
    if SAFE_COMMANDS.include?(op)
      begin
        send(op, *args)
      rescue => e
        puts e.backtrace
      rescue SystemExit
      end
    else
      puts 'unknown command'
    end
  end

  def repl
    reset
    loop do
      line = Readline.readline(PROMPT, true)
      break unless line
      op, args = parse_user_input(line)
      rep(op.to_sym, args)
    end
    puts
  end

  def reset
    @memory = Array.new(MAX_PROGRAM_SIZE)
    @registers = Array.new(8, 0)
    @stack = []
    @pc = 0
    puts "Loading up #{@program.length} instructions..."
    @program.each_with_index { |value, i| @memory[i] = value }
  end

  def show(thing, from = @pc, to = nil)
    case thing
    when 'pc' then puts "pc: #{@pc}"
    when 'registers' then puts "registers: #{@registers.join(' ')}"
    when 'stack' then puts "stack: #{@stack.join(' ')}"
    when 'memory' then show_memory(from, to)
    else puts 'unknown thing'
    end
  end

  def show_memory(from, to)
    to = from unless to
    (from..to).each do |i|
      break unless @memory[i]
      puts "#{pad_pc(i)}: #{@memory[i]}"
    end
  end

  def dump
    filename = "dump_#{Time.now.strftime('%Y%m%d_%H%M%S')}.bin"
    core = @memory.compact
    spit(filename, core)
    puts "Dumped #{core.length} bytes to #{filename}"
  end

  def fetch
    assert(@pc < @memory.length)
    result = @memory[@pc]
    @pc += 1
    result
  end

  def register_value(value)
    assert(register?(value))
    @registers[value - MAX_INT]
  end

  def lookup(value)
    register?(value) ? register_value(value) : value
  end

  def halt
    raise SystemExit
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
    @pc = target
  end

  def jt
    condition = lookup(fetch)
    target = lookup(fetch)
    @pc = target unless condition.zero?
  end

  def jf
    condition = lookup(fetch)
    target = lookup(fetch)
    @pc = target if condition.zero?
  end

  def add
    register = register_index(fetch)
    arg1 = lookup(fetch)
    arg2 = lookup(fetch)
    @registers[register] = (arg1 + arg2) % MAX_INT
  end

  def mult
    register = register_index(fetch)
    arg1 = lookup(fetch)
    arg2 = lookup(fetch)
    @registers[register] = (arg1 * arg2) % MAX_INT
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
    assert(@memory[@pc + 1])
    @stack.push(@pc + 1)
    target = lookup(fetch)
    @pc = target
  end

  def ret
    target = @stack.pop
    exit(0) unless target
    @pc = target
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

  def step(n = 1)
    n.times { single_step }
  end

  def single_step
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
      single_step
    end
  end
end

def parse_arg(arg)
  if arg[/^\d+$/]
    arg.to_i
  else
    arg
  end
end

def parse_user_input(line)
  args = line.split.map { |arg| parse_arg(arg) }
  op = args.shift
  [op, args]
end

trap('INT', 'SIG_IGN')
if ARGV.length == 1
  system = System.new(slurp(ARGV[0]))
  system.repl
else
  puts 'usage: emulator.rb <in.bin>'
  exit(1)
end
