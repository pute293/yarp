require 'stringio'

module PDF
  
  class InvalidStreamError < InvalidPdfError; end
  
  class Stream < PdfObject
    def initialize(*args)
      super
      filters = self[:Filter]
      params = self[:DecodeParms]
      @filters = filters.kind_of?(Enumerable) ? filters.to_a : [filters]
      @decode_params = params.kind_of?(Array) ? params : [params]
      @self_encrypt = @filters.include?(:Crypt)
    end
    
    def size
      self[:Length]
    end
    
    def stream
      decode_stream
    end
    
    def raw_stream
      offset = self[:_stream_]
      raise InvalidStreamError, "stream offset unknown; #{self}" if offset.nil?
      len = self[:Length]
      @parser.read_stream(offset, len)
    end
    
    def decrypt_stream
      data = raw_stream
      if !@self_encrypt && @parser.encrypted?
        data = @parser.decrypt_stream(self, raw_stream)
      end
      data
    end
    
    def decode_stream
      data = decrypt_stream
      @filters.zip(@decode_params).each do |filter, param|
        return nil if data.nil?
        filter = case filter
        when nil then nil
        when :ASCIIHexDecode  then Filter::AsciiHex
        when :ASCII85Decode   then Filter::Ascii85
        when :LZWDecode       then Filter::Lzw
        when :FlateDecode     then Filter::Flate
        when :RunLengthDecode then Filter::RunLength
        when :CCITTFaxDecode  then Filter::Ccitt
        when :JBIG2Decode     then Filter::Jbig2
        when :DCTDecode       then Filter::Dct
        when :JPXDecode       then Filter::Jpx
        when :Crypt
          if param.nil?
            # pass through
            nil
          else
            raise NotImplementedError, "not implemented filter: #{filter}; params: #{param}"
          end
        else
          raise NotImplementedError, "not implemented filter: #{filter}"
        end
        data = filter.decode(data, param) unless filter.nil?
      end
      data
    end
    
    def ops
      @ops ||= Parser::OperationParser.try_parse(decode_stream)
    end
    
    def to_s
      contents = to_string(@original_data)
      "#{@num} #{@gen} obj\n#{contents}\nstream \n  ~~~~~\nendstream\nendobj"
    end
    
    def pretty_print_cycle(q)
      q.text("#{@num} #{@gen} obj ... \nstream ... endstream\nendobj")
    end
    
  end
  
  class ObjStream < Stream
    RE_PDF_STREAM_DFN = /\A\s*(\d+)\s+(\d+)(?=[^\d])/n
    
    def initialize(*args)
      super
      fst = self[:First]
      @first = fst
      @objects = {}
      hash = {}
      n = self[:N]
      
      StringIO.open(decode_stream, 'rb:ASCII-8BIT') do |sio|
        buf = sio.read(128)
        pair = []
        n.times do |idx|
          RE_PDF_STREAM_DFN =~ buf
          until $&
            add_buf = sio.read(128)
            raise InvalidStreamError, 'invalid stream; unexpected end-of-stream' if add_buf.nil?
            buf += add_buf
            RE_PDF_STREAM_DFN =~ buf
          end
          buf = $'
          pair.push([$1.to_i, $2.to_i, idx])
        end
        objs = pair.sort_by{|a|-a[1]} # descending sort
        last_offset = sio.size
        objs.each do |n, o, i|
          offset = o + fst
          hash[n] = {:offset => offset, :length => last_offset - offset, :idx => i}
          last_offset = offset
        end
      end
      @objects = hash
    end
    
    def get(num)
      obj = begin
        @objects.fetch(num)
      rescue KeyError
        # /Extends entry means this object stream is part of it
        ext = self[:Extends]
        raise unless ext  # re-raise KeyError
        ext.get(num)
      end
      StringIO.open(decode_stream, 'rb:ASCII-8BIT') do |sio|
        sio.seek(obj[:offset])
        stream = sio.read(obj[:length])
        obj = @parser.parse_string(stream)
        if obj.kind_of?(PdfObject)
          obj
        else
          # generation of object in object-stream is always 0
          PdfObject.create(@parser, num, 0, obj, encrypted: false, in_stream: true)
        end
      end
    end
    
  end
  
end
