module PDF

class InvalidXRefError < InvalidPdfError; end

class XRef < Stream
  class XRefEntry
    attr_reader :offset, :num, :gen, :parent
    def initialize(parser, offset, num, gen, used, object_stream = nil)
      @parser = parser
      @offset = offset
      @num = num
      @gen = gen
      @used = used
      @parent = object_stream
    end
    
    def realize
      return nil unless @used
      if @parent.nil?
        @parser.deref([@num, @gen])
      else
        os_num, os_idx = @parent
        # generation of object stream is always 0
        os = @parser.deref([os_num, 0])
        os.get(@num)
      end
    end
  end
  
  attr_reader :xref, :trailer
  def initialize(parser, *args)
    if args[0].kind_of?(Hash)
      # old fasion; xref ... trailer << ... >>
      xref = args[0]
      trailer = args[1]
      super(parser, :XRef, 0, trailer, false, false)
      @xref = xref.collect {|ref,hash| XRefEntry.new(parser, hash[:offset], ref.num, ref.gen, hash[:used]) }
      @trailer = trailer
    else  # cross reference stream (new fasion); args = [num, gen, data, encrypted, instream]
      super
      xref = decode_xref
      @xref = xref
      @trailer = args[2]
    end
    @encrypted = false
  end
  
  def encrypted?; false end
  
  include Enumerable
  
  def each
    @xref.each(&proc)
  end
  
  def decode_xref
    w = self[:W]
    w_size = w.inject(:+)
    raise InvalidXRefError, "unexpected Filter Window #{w}" if w.size != 3
    indices = (self[:Index] || [0, self[:Size]]).each_slice(2).collect{|f,l|Range.new(f, f + l, true).to_a}.flatten
    x = decode_stream
    data = x.scan(/[\x00-\xff]{#{w_size}}/n)
    raise InvalidXRefError, "invalid data count in cross reference stream #{data.size}; expected #{indices.size}" if data.size != indices.size
    data.collect do |entry|
      # each fields consist of intergers in big-endian
      entry = entry.unpack('C*')
      type  = entry.shift(w[0]).inject{|acc,cur|acc = (acc << 8) + cur}
      f1    = entry.shift(w[1]).inject{|acc,cur|acc = (acc << 8) + cur}
      f2    = entry.shift(w[2]).inject{|acc,cur|acc = (acc << 8) + cur}
      type ||= 1  # when w[0] == 0; default value is 1
      num = indices.shift
      
      # offset, gen, used, object-stream
      o, g, used, os = -1, 0, false, nil
      case type
      when 0
        # unused object;  f1 = num of next free object; f2 = gen
        g = f2
      when 1
        # using object;   f1 = offset,  f2 = gen
        f2 ||= 0  # when w[2] == 0; defalut value is 0
        o, g, used = f1, f2, true
      when 2
        # using object in object stream(os); f1 = num of os, f2 = index of object in os
        used, os = true, [f1, f2]
      else
        raise InvalidXRefError, "unexpected field type #{type}; expected 0, 1 or 2"
      end
      XRefEntry.new(@parser, o, num, g, used, os)
    end
  end
end

end
