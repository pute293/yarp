# coding: utf-8
require 'stringio'

module PDF::Filter
  module RunLength
    
    # simple byte-oriented run-length decoder
    def self.decode(raw_bytes, *args)
      data = ''.b
      return data if raw_bytes.size < 2
      
      StringIO.open(raw_bytes, 'rb:ASCII-8BIT') do |sio|
        len = sio.read(1).ord
        while len != 128
          if len < 128
            # copy stream
            len += 1
            data << sio.read(len)
          else
            # repeat next byte
            len = 257 - len
            byte = sio.read(1)
            data << byte * len
          end
          len = sio.read(1)
          break if len.nil?  # eof
          len = len.ord
        end
      end
      
      data
    end
  
  end
end
