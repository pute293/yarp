module PDF
  class GraphicState
    
    attr_accessor :ctm, :ts
    
    def initialize
      @ctm = Utils::Mat3.new
      @ts  = TextState.new
    end
    
    def dup
      ret = super
      ret.ctm = @ctm.dup
      ret.ts = @ts.dup
      ret
    end
    
  end
  
  class TextState
    
    attr_accessor :tm, :tlm, :c, :w, :h, :l, :font, :fs, :mode, :rise, :k
    
    def initialize
      @tm = Utils::Mat3.new
      @tlm = Utils::Mat3.new
      @c, @w, @h, @l = 0.0, 0.0, 1.0, 0.0
      @font, @fs, @mode, @rise, @k = nil, 1, 0, 0.0, false
    end
    
    def dup
      ret = super
      ret.tm = @tm.dup
      ret.tlm = @tlm.dup
      ret
    end
    
  end
end
