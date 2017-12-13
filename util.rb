def assert(condition)
  raise('assertion failed') unless condition
end

def register?(value)
  value >= 32_768
end

def register_index(value)
  assert(register?(value))
  value - 32_768
end

class IO
  def readbyte_u16le
    low = readbyte
    assert(!eof?)
    high = readbyte
    high << 8 | low
  end

  def read_u16le
    result = []
    result << readbyte_u16le until eof?
    result
  end

  def putc_u16le(n)
    assert(n >= 0 && n < 32_776)
    high = n >> 8
    low = n & 0xFF
    putc(low)
    putc(high)
  end

  def write_u16le(values)
    values.each { |value| putc_u16le(value) }
  end
end

def slurp(path)
  File.open(path, &:read_u16le)
end

def spit(path, values)
  File.open(path, 'wb') { |f| f.write_u16le(values) }
end

def str(bytes)
  bytes.pack('C*')
end

def pad_pc(pc)
  pc.to_s.rjust(5, ' ')
end

def info(message)
  puts "[info] #{message}"
end
