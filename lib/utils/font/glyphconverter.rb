module YARP::Utils::Font
  
  class GlyphConverter
    
    def self.compare(type1, type2)
      
      
    end
    
  end
  
  class PsGlyph
    def initialize(str)
      operators = self.class.const_get(:OP)
      op = str.bytes
      stack = []
      until op.empty?
        v = op.shift
        case v
        when 28 then stack.push([(v << 8) | op.shift].pack('s').unpack('s')[0])
        when (0..31)
          v = (v << 8) | op.shift if v == 12
          o = operators.fetch(v)
          n = o[1]
          args = stack.pop(n)
          args = o[2].call(stack, args) if o[2]
          stack.push([o[0], *args])
        when (32..246)  then stack.push(v - 139)
        when (247..250) then stack.push((v - 247) * 256 + op.shift + 108)
        when (251..254) then stack.push(-(v - 251) * 256 - op.shift - 108)
        when 255        then stack.push(op.shift(4).reverse.pack('l').unpack('l')[0])
        end
      end
      @operators = normalize(stack)
    end
    
    def to_s
      @operators.collect{|op| op.kind_of?(Array) ? op.join(' ') : op}.join("\n")
    end
    
    private
    def normalize(stack)
      stack
    end
  end
  
  class GlyphType1 < PsGlyph
    OP = {
      1 => [:hstem, 2],
      3 => [:vstem, 2],
      4 => [:vmoveto, 1],
      5 => [:rlineto, 2],
      6 => [:hlineto, 1],
      7 => [:vlineto, 1],
      8 => [:rrcurveto, 6],
      9 => [:closepath, 0],
      10 => [:callsubr, 1],
      11 => [:return, 0],
      13 => [:hsbw, 2],
      14 => [:endchar, 0],
      21 => [:rmoveto, 2],
      22 => [:hmoveto, 1],
      30 => [:vhcurveto, 4],
      31 => [:hvcurveto, 4],
      0x0c00 => [:dotsection, 0],
      0x0c01 => [:vstem3, 6],
      0x0c02 => [:hstem3, 6],
      0x0c06 => [:seac, 5],
      0x0c07 => [:sbw, 4],
      0x0c0a => [:div, 2],
      0x0c10 => [:callothersubr, 2, Proc.new{|ops,args| [args[1], *ops.pop(args[0])]}],
      0x0c11 => [:pop, 0],
      0x0c21 => [:setcurrentpoint, 2],
    }.freeze
  end
  
  class GlyphType2 < PsGlyph
    #OP = {
    #  1 => [:hstem, ],
    #  3 => [:vstem, ],
    #  4 => [:vmoveto, 1],
    #  5 => [:rlineto, 2, Proc.new{|ops,args| [*args, *get_args(ops, 2)]}]
    #  6 => [:hlineto, ],
    #  7 => [:vlineto, ],
    #  8 => [:rrcurveto, ],
    #  10 => [:callsubr, ],
    #  11 => [:return, ],
    #  14 => [:endchar, ],
    #  18 => [:hstemhm, ],
    #  19 => [:hintmask, ],
    #  20 => [:cntrmask, ],
    #  21 => [:rmoveto, 2],
    #  22 => [:hmoveto, 1],
    #  23 => [:vstemhm, ],
    #  24 => [:rcurveline, ],
    #  25 => [:rlinecurve, ],
    #  26 => [:vvcurveto, ],
    #  27 => [:hhcurveto, ],
    #  28 => [:shortint, ],
    #  29 => [:callgsubr, ],
    #  30 => [:vhcurveto, ],
    #  31 => [:hvcurveto, ],
    #  0x0c03 => [:and, ],
    #  0x0c04 => [:or, ],
    #  0x0c05 => [:not, ],
    #  0x0c09 => [:abs, ],
    #  0x0c0a => [:add, ],
    #  0x0c0b => [:sub, ],
    #  0x0c0c => [:div, ],
    #  0x0c0e => [:neg, ],
    #  0x0c0f => [:eq, ],
    #  0x0c012 => [:drop, ],
    #  0x0c014 => [:put, ],
    #  0x0c015 => [:get, ],
    #  0x0c016 => [:ifelse, ],
    #  0x0c017 => [:random, ],
    #  0x0c018 => [:mul, ],
    #  0x0c01a => [:sqrt, ],
    #  0x0c01b => [:dup, ],
    #  0x0c01c => [:exch, ],
    #  0x0c01d => [:index, ],
    #  0x0c01e => [:roll, ],
    #  0x0c020 => [:0c, ],
    #  0x0c022 => [:hflex, ],
    #  0x0c023 => [:flex, ],
    #  0x0c024 => [:hflex1, ],
    #  0x0c025 => [:flex1, ],
    #}
    
    private
    
    def get_args(stack, unit)
      stack.reverse.each_slice(unit).inject([]) do |acc,cur|
        if cur.all?{|a|a.kind_of?(Numeric)}
          acc.shift(*cur.reverse)
          acc
        else break acc
        end
      end
    end
  end
  
end

