#!/usr/bin/env ruby

require_relative 'util'

def find_strings(input)
  str(input).scan(/((\x13[[:graph:][:space:]])+)/)
            .map { |m| m[0].delete("\x13") }
end

if ARGV.length == 1
  puts find_strings(slurp(ARGV[0]))
else
  puts 'usage: strings.rb <in.bin>'
end
