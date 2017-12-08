def assert(condition)
  raise('assertion failed') unless condition
end

class IO
  def read_u16le
    low = readbyte
    assert(!eof?)
    high = readbyte
    high << 8 | low
  end

  def write_u16le(n)
    assert(n >= 0 && n < 32_768)
    high = n >> 8
    low = n & 0xFF
    putc(low)
    putc(high)
  end
end
