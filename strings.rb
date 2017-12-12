#!/usr/bin/env ruby

require_relative 'util'

def matches(string, re)
  results = []
  pos = 0
  loop do
    match = string.match(re, pos)
    break unless match
    results.push(match)
    pos = match.end(0)
  end
  results
end

def find_prints(input)
  matches(str(input), /(\x13[[:print:]])+/).map do |match|
    "#{pad_pc(match.begin(0))} | #{match[0].delete("\x13")}"
  end
end

def find_strings(input)
  matches(str(input), /[[:print:]]{4,}/).map do |match|
    "#{pad_pc(match.begin(0))} | #{match[0]}"
  end
end

if ARGV.length == 1
  input = slurp(ARGV[0])
  puts find_prints(input)
  puts find_strings(input)
else
  puts 'usage: strings.rb <in.bin>'
end
