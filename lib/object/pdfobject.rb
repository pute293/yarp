require 'forwardable'

module YARP
  
  class PdfObject
    
    attr_reader :num, :gen
    
    extend Forwardable
    def_delegators :@data,  :each_key, :each_value,
                            :has_key?, :include?, :key?, :member?,
                            :has_value?, :value?,
                            :key, :keys, :rassoc, :reject, :select,
                            :values, :values_at,
                            :find
    
    def initialize(parser, num, gen, data, encrypted, instream)
      num = -1 if num.kind_of?(Symbol)
      @parser = parser
      @encrypted = encrypted
      @in_stream = instream
      @num = num
      @gen = gen
      @data = data.dup
      #define_method_missing(@data)
      define_method_missing(self)
      @original_data = data.dup.freeze   # for to_s method
    end
    
    def type
      self[:Type].to_s.intern
    end
    
    def subtype
      self[:Subtype].to_s.intern
    end
    
    def encrypted?; @encrypted end
    
    def in_stream?; @in_stream end
    
    # for compatibility to YARP::Stream
    def size; 0 end
    alias length size
    
    def [](key)
      data = @data[key]
      case data
      when Array
        data = data.collect{|v|v.kind_of?(Ref) ? v.data : v}
        @data[key] = data
      when Hash
        data = data.collect{|k,v|v = v.kind_of?(Ref) ? v.data : v;[k,v]}
        data = Hash[*data.flatten(1)]
        @data[key] = data
      when Ref
        data = data.data
        @data[key] = data
      when String
        data = encode_string(data)
      end
      data
    end
    
    def []=(key,val)
      @data[key] = val
    end
    
    def fetch(key)
      if @data.has_key?(key)
        self[key]
      else
        @data.fetch(key) # raise error
      end
    end
    
    def dict; @data end
    
    def to_s
      contents = to_string(@original_data)
      "#{@num} #{@gen} obj\n#{contents}\nendobj"
    end
    
    def pretty_print(q)
      q.text(to_s)
    end
    
    def pretty_print_cycle(q)
      q.text("#{@num} #{@gen} obj ... endobj")
    end
    
    def ==(other)
      if other.kind_of?(PdfObject)
        @num == other.num && @gen == other.gen
      else
        false
      end
    end
    
    def hash
      [@num, @gen].hash
    end
    
    def eql?(other)
      if other.kind_of?(PdfObject)
        self.num == other.num && self.gen == other.gen
      else
        false
      end
    end
    
    #def method_missing(name, *args)
    #  if @data.has_key?(name)
    #    self[name]
    #  else
    #    super
    #  end
    #end
    
    
    private
    
    def warn(*args)
      YARP.warn(*args)
    end
    
    def define_method_missing(dict)
      def dict.method_missing(name, *args)
        if self.has_key?(name)
          v = self[name]
          v = v.data if v.kind_of?(Ref)
          if v.kind_of?(Array)
            v.collect{|item|item.kind_of?(Ref) ? item.data : item}
          else
            v
          end
        else
          super
        end
      end
      dict.values.each{|v|define_method_missing(v) if v.kind_of?(Hash)}
    end
    
    def to_string(val, depth=1)
      case val
      when String
        "(#{normalize_string(val)})"
      when Symbol
        "/#{val}"
      when Array
        items = val.collect{|item|to_string(item)}
        "[ #{items.join(' ')} ]"
      when Hash
        indent      = "    " * depth
        end_indent  = "    " * (depth - 1)
        size = val.keys.inject(0){|max,k|max < k.size ? k.size : max} + 2
        contents = val.collect do |k,v|
          next if k.to_s.start_with?('_')
          space = v.kind_of?(Hash) ? '  ' : ' ' * (size-k.size)
          "#{indent}/#{k}#{space}#{to_string(v,depth+1)}"
        end
        contents = contents.compact.join("\n")
        "<<\n#{contents}\n#{end_indent}>>"
      when Ref
        "#{val.num} #{val.gen} R"
      when nil
        'null'
      else val.to_s
      end
    end
    
    def normalize_string(str)
      encode_string(decrypt_string(str))
    end
    
    def decrypt_string(str)
      @parser.decrypt_string(self, str)
    end
    
    def encode_string(str)
      str = str.b
      if @parser.encrypt_obj?(self)
        # any strings in encrypt dictionary do not encrypted
        # so nothing to do here
        str
      elsif str.start_with?("\xfe\xff".b)
        # UTF-16 with BOM "\xfe\xff"
        # BOM is consist of "LATIN SMALL LETTER THORN" (\xfe in latin-1) and "LATIN SMALL LETTER Y WITH DIAERESIS" (\xff in latin-1).
        # Because they are unlikely to be a meaningful beginning of a word or phrase,
        # we can ignore those cases.
        str[2..-1].force_encoding('UTF-16BE').encode('UTF-8')
      else
        # PDFDocEncoding
        # chr \0 means termination of string (at least Adobe Reader)
        enc = Utils::Encoding::PDFDocEncoding
        str.chars.collect{|x|enc[x]}.take_while{|x|x != 0 && !x.nil?}.pack('U*')
      end
    end
    
  end
  
  #class PdfArray < PdfObject
  #  def initialize(parser, num, gen, data, encrypted, instream)
  #    _data = {}
  #    data.each_with_index {|v,i|_data[i] = v}
  #    super(parser, num, gen, _data, encrypted, instream)
  #  end
  #  def type; :Array end
  #  def subtype; ''.intern end
  #end
  
end
