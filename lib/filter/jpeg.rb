# coding: utf-8

# These filters are usually used for image compression,
# and the raw data consists of whole file.
# So filters defined here are return the raw data, without decompression.

module YARP::Filter
  
  module Dct
    def self.decode(raw_bytes, *args)
      raw_bytes
    end
  end
  
  module Jbig2
    JBIG2_MAGIC = [151, 74, 66, 50, 13, 10, 26, 10]   # "\x97JB2\r\n\x1A\n"
    
    def self.decode(raw_bytes, *args)
      # usual jbig2 filtered object has no header in pdf file.
      # see spec p.33
      header = raw_bytes.unpack('C8')
      if header == JBIG2_MAGIC
        raw_bytes
      else
        # add header
        JBIG2_MAGIC.pack('C*') + raw_bytes
      end
    end
  end
  
  module Jpx
    def self.decode(raw_bytes, *args)
      raw_bytes
    end
  end
  
end
