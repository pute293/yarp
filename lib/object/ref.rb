module PDF
  
  class Ref
    attr_reader :num, :gen
    
    def initialize(parser, n, g)
      @parser = parser
      @num = n
      @gen = g
    end
    
    def data
      @parser.deref(self)
    end
    
    def to_a; [@num,@gen] end
    
    def inspect; "#{@num}/#{@gen}" end
    
    def hash
      [@num, @gen].hash
    end
    
    def eql?(other)
      if other.kind_of?(Ref)
        self.to_a == other.to_a
      else
        false
      end
    end
    
    def ==(other)
      self.eql?(other)
    end
  end
  
end
