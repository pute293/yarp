# coding: utf-8

require_relative 'predictor'

module PDF::Filter
  module Lzw
    
    # LZW decoder with predictor
    def self.decode(raw_bytes, params)
      data = decode_lzw(raw_bytes)
      if params.nil?
        data 
      else
        Predictor.decode(data, params)
      end
    end
    
    
    # LZW decoder
    # This is not original Lempel-Ziv-Welch algorithm;
    # extended with CLEAR marker (256) and EOD marker (257)
    def self.decode_lzw(raw_bytes, bit_order=:msb)
      ret = ''.b
      
      r = Utils::BitReader.new(raw_bytes, bit_order)
      bitlen = 9
      table = (0..255).collect{|i|i.chr.b}.push(nil, nil)
      prev_code = nil
      
      until r.eof? do
        code = r.read(bitlen)
        
        case code
        when 256  # clear table
          bitlen = 9
          table = (0..255).collect{|i|i.chr.b}.push(nil, nil)
          prev_code = nil
        when 257  # end of document
          break
        else
          if prev_code.nil?
            # first char
            # code.chr result 'us-ascii' if code < 128(0x80),
            # but 'ascii-8bit' + 'us-ascii' results always 'ascii-8bit'.
            # so ret has always 'ascii-8bit' encoding.
            prev_code = code
            ret << code.chr
          else
            # table referencing
            bytes = nil
            if code < table.size
              bytes = table[code]
            else
              bytes = table[prev_code]
              bytes += bytes[0]   # (a)
            end
            # bytes is sure to ascii-8bit encoding
            # because all entries of initialized table are ascii-8bit,
            # and 'ascii-8bit' + 'us-ascii' (pointed at above '(a)') results always 'ascii-8bit'.
            ret << bytes
            
            # update table
            new_entry = table[prev_code] + bytes[0]
            table.push(new_entry)
            prev_code = code
            
            case table.size
            when 511
              bitlen = 10
            when 1023
              bitlen = 11
            when 2047
              bitlen = 12
            when 4096
              raise FilterError, "table over flow", caller(1)
            end
          end
        end
      end
      
      ret
    end
  end
end
