#!/usr/bin/env ruby

require_relative 'util'

def assemble(inpath, outpath)
  values = File.open(inpath) { |f| f.read.split.map(&:to_i) }
  spit(outpath, values)
end

if ARGV.length == 2
  assemble(*ARGV)
else
  puts 'usage: assembler.rb <in.syn> <out.bin>'
  exit(1)
end
