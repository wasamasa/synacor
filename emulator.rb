#!/usr/bin/env ruby

require_relative 'util'
require 'readline'
require 'set'
require 'yaml'

MAX_PROGRAM_SIZE = 32_768
MAX_INT = 32_768
MAX_REGISTER = 32_776
SAFE_COMMANDS = [:run, :reset, :step,
                 :show, :set,
                 :dump, :restore,
                 :breakpoint, :breakop, :watch].freeze
PROMPT = 'dbg> '.freeze
HIST_FILE = '.repl_history'.freeze

class System
  def initialize(program)
    assert(program.length <= MAX_PROGRAM_SIZE)
    program.each { |value| assert(value >= 0 && value < MAX_REGISTER) }
    @program = program
    @breakpoints = Set.new
    @breakops = Set.new
    @watches = Set.new
    @cycles = 0
  end

  def reset
    @memory = Array.new(MAX_PROGRAM_SIZE)
    @registers = Array.new(8, 0)
    @stack = []
    @pc = 0
    info("loading up #{@program.length} instructions...")
    @program.each_with_index { |value, i| @memory[i] = value }
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
    raise SystemExit, 'halt'
  end

  def _set
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
    @registers[register] = (arg1 == arg2 ? 1 : 0)
  end

  def gt
    register = register_index(fetch)
    arg1 = lookup(fetch)
    arg2 = lookup(fetch)
    @registers[register] = (arg1 > arg2 ? 1 : 0)
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
    arg = STDIN.getc
    raise SystemExit, 'EOF' unless arg
    @registers[register] = arg.ord
  end

  def noop; end

  def step(n = 1)
    n.times { single_step }
  end

  def check_breakpoints
    op = OP_TO_NAME[@memory[@pc]]
    raise SystemExit, "breakpoint at #{@pc}" if @breakpoints.include?(@pc)
    raise SystemExit, "break op: #{op}" if @breakops.include?(op)
  end

  def check_watches
    op = @memory[@pc]
    return unless [15, 16].include?(op)
    if op == 15
      address = lookup(@memory[@pc + 2])
      message = "intercepted read from #{address}"
    else
      address = lookup(@memory[@pc + 1])
      message = "intercepted write to #{address}"
    end
    raise SystemExit, message if @watches.include?(address)
  end

  def single_step
    op = fetch
    assert(op && op >= 0 && op < 22)
    case op
    when 0  then halt
    when 1  then _set
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
    check_breakpoints
    check_watches
    @cycles += 1
  end

  def run
    loop do
      step
    end
  end

  def rep(op, args)
    if SAFE_COMMANDS.include?(op)
      begin
        send(op, *args)
      rescue => e
        puts e.to_s, e.backtrace
      rescue SystemExit => e
        info(e.message)
      end
    else
      info('unknown command')
    end
  end

  def load_history
    File.open(HIST_FILE) do |f|
      f.readlines.each do |line|
        line = line.chomp
        Readline::HISTORY << line unless line.empty?
      end
    end
  rescue Errno::ENOENT
  end

  def add_history!(line)
    return unless line && !line.empty?
    Readline::HISTORY << line
    File.open(HIST_FILE, 'a') { |f| f.puts(line) }
  end

  def read_line
    line = Readline.readline(PROMPT)
    add_history!(line) if line && !line.empty?
    line
  end

  def repl
    reset
    load_history
    loop do
      line = read_line
      break unless line
      next if line.empty?
      op, args = parse_user_input(line)
      rep(op.to_sym, args)
    end
    puts
  end

  def show(thing = nil, from = @pc, to = nil)
    case thing
    when 'pc' then info("pc: #{@pc}")
    when 'registers' then info("registers: #{@registers.join(' ')}")
    when 'stack' then info("stack: #{@stack.join(' ')}")
    when 'memory' then show_memory(from, to)
    when 'breakpoints' then info("breakpoints: #{@breakpoints.to_a.join(' ')}")
    when 'breakops' then info("breakops: #{@breakops.to_a.join(' ')}")
    when 'watches' then info("watches: #{@watches.to_a.join(' ')}")
    when 'cycles' then info("cycles: #{@cycles}")
    when nil
      show('pc')
      show('registers')
      show('stack')
    else info('unknown thing')
    end
  end

  def show_memory(from, to)
    to = from unless to
    (from..to).each do |i|
      break unless @memory[i]
      info("#{pad_pc(i)}: #{@memory[i]}")
    end
  end

  def set(thing, *values)
    assert(values[0])
    case thing
    when 'pc' then @pc = values[0]
    when 'registers' then @registers = values
    when 'stack' then @stack = values
    when 'memory' then set_memory(values[0], values[1])
    else info('unknown thing')
    end
  end

  def set_memory(address, value)
    assert(address && value)
    @memory[address] = value
  end

  def dump
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')

    state_filename = "dump_#{timestamp}.yml"
    state = { pc: @pc, registers: @registers, stack: @stack }
    File.open(state_filename, 'w') { |f| f.puts YAML.dump(state) }
    info("dumped emulator state to #{state_filename}")

    core_filename = "dump_#{timestamp}.bin"
    core = @memory.compact
    spit(core_filename, core)
    info("dumped #{core.length} bytes to #{core_filename}")
  end

  def restore(filename)
    state = YAML.load_file(filename)
    @pc = state[:pc]
    @registers = state[:registers]
    @stack = state[:stack]
    info("restored emulator state from #{filename}")
  end

  def breakpoint(arg)
    assert(arg > 0 && arg < MAX_PROGRAM_SIZE && @memory[arg])
    @breakpoints << arg
  end

  def breakop(arg)
    assert(OP_TO_NAME.include?(arg.to_sym))
    @breakops << arg.to_sym
  end

  def watch(arg)
    assert(arg > 0 && arg < MAX_PROGRAM_SIZE && @memory[arg])
    @watches << arg
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
