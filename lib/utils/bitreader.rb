# coding: utf-8

module PDF::Utils
  class BitReader
    
    # endianness
    #   MSB first:
    #     bit               byte
    #     1111_1011_1101    fb d0
    #   LSB first:
    #     bit               byte
    #     1111_1011_1101    bd 0f
    
    
    def initialize(bytes, order=:msb)
      @order = case order.to_s.downcase.intern
      when :msb then true
      when :lsb then false
      else raise ArgumentError, "invalid order #{order}; exptected :msb, :lsb"
      end
      @data = bytes.b
      @size = @data.size
      @bit_pos = 0
      @byte_pos = 0
    end
    
    def read(bit_len)
      raise EOFError, "requested #{bit_len} bits, but remained #{remain_bits} bits" if remain_bits < bit_len
      @order ? read_msb(bit_len) : read_lsb(bit_len)
    end
    
    def remain_bits
      remain_bytes = @size - @byte_pos - 1
      remain_bits_ = 8 - @bit_pos
      remain_bytes * 8 + remain_bits_
    end
    
    def eof?
      remain_bits <= 0
    end
    
    private
    
    def read_msb(bit_len)
      bit_pos = @bit_pos
      byte_len = bit_len / 8
      byte_len += 1 if bit_len % 8 != 0
      
      bits = @data[@byte_pos, byte_len].unpack('B*')[0]
      bits = bits[bit_pos, bit_len].to_i(2)
      bit_pos += bit_len
      @byte_pos += bit_pos / 8
      @bit_pos = bit_pos % 8
      bits
    end
    
    def read_lsb(bit_len)
      bit_pos = @bit_pos
      byte_len = bit_len / 8
      byte_len += 1 if bit_len % 8 != 0
      
      bits = @data[@byte_pos, byte_len].unpack('b*')[0]
      bits = bits[bit_pos, bit_len].reverse.to_i(2)#.to_i(2)
      bit_pos += bit_len
      @byte_pos += bit_pos / 8
      @bit_pos = bit_pos % 8
      bits
    end
  end
  
end
