#! ruby

require 'stringio'
require 'pp'
require_relative '../lib/yarp'

$bar = '-' * 80
$barb = '=' * 80

class Integer
  def to_f2dot14
    raise TypeError, 'overflow' unless (0..0xffff).include?(self)
    mantissa = case self >> 14
      when 0 then 0
      when 1 then 1
      when 2 then -2
      when 3 then -1
    end
    frac = Rational(self & 0b0011_1111_1111_1111, 16384)  # 16384 == 0b0100_0000_0000_0000
    (mantissa + (mantissa < 0 ? -frac : frac)).to_f
  end
end

class Glyph
  
  class << self
    
    alias :newobj :new
    
    def new(font, gid, cmaps, gpos)
      raise ArgumentError, 'unknown type of font' unless font.respond_to?(:type)
      case font.type
      when :TrueType
        TtGlyph.newobj(font, gid, cmaps, gpos)
      when :OpenType
        PsGlyph.newobj(font, gid, cmaps, gpos)
      else raise ArgumentError, 'unknown type of font'
      end
    end
    
  end
  
  attr_reader :font, :gid, :uni, :features, :anchors
  attr_reader :xmin, :xmax, :ymin, :ymax, :aw, :lsb, :ah, :tsb
  attr_reader :coordinates, :eoc, :insts
  
  def rsb; aw - (lsb + xmax - xmin) end
  
  def bsb; ah - (tsb + ymax - ymin) end
  
  def valid?; @data && !@data.empty? end
  
  def composite?; false end
  
  def initialize(font, gid, cmaps, gpos)
    @font = font
    @gid = gid
    @data = font.glyph_data(gid)
    
    hmtx = font.get_hmetrics(gid)
    vmtx = font.get_vmetrics(gid)
    @aw = hmtx ? hmtx[:aw] : 0
    @ah = vmtx ? vmtx[:ah] : nil
    @lsb = hmtx ? hmtx[:lsb] : 0
    @tsb = vmtx ? vmtx[:tsb] : nil
    @xmin = @xmax = @ymin = @ymax = 0
    @coordinates = []
    @eoc = []
    @insts = ''
    
    unicode = cmaps.inject(0) do |uni, cmap|
      if cmap.format == 14
        unis = cmap.code2gid.key(gid)
        break unis.unpack('N*') if unis
        uni
      else
        fmt = case cmap.bytes
        when 1 then 'C'
        when 2 then 'n'
        when 4 then 'N'
        else raise 'must not happen'
        end
        u = cmap.code2gid.reverse_each.find{|code, v| break code if v == gid}
        if u
          u, = u.unpack(fmt)
          uni < u ? u : uni
        else uni
        end
        #u = cmap.code2gid.keys(gid).collect{|key| key.unpack(fmt)[0]}.max
      end
    end
    @uni = unicode.kind_of?(Array) ? unicode : unicode == 0xffff ? nil : [unicode]
    
    #lookups = gpos[2]
    #p gpos[2].flatten.size
    #pp gpos
    @features = []
    @anchors = []
    gpos[2].each_with_index do |hashs, i|
      if hashs.find {|hash| hash[:coverages].include?(gid)}
        fts = gpos[1].select{|ft| ft[:lookup_indices].include?(i)}
        fs = fts.collect.with_index{|ft, i| [ft[:tag], i]}
        next unless fs
        #gpos[0].each do |script|
        #  strs = script[:langs].collect {|lang|
        #    f = fs.find{|ft| lang[:feature_indices].include?(ft[1])}
        #    tag = lang[:tag] == :DFLT ? script[:tag] : lang[:tag]
        #    f ? [tag, *f] : nil
        #  }.compact.collect{|lang| "#{lang[0]}/#{lang[1]}"}
        #  @features.push(*strs)
        #end
        fs = fs.collect(&:first)
        @features.push(*fs)
        
        # add anchors
        fts.each do |ft|
          next unless %i{ mark mkmk curs }.include?(ft[:tag])
          ft[:lookup_indices].each do |lk_idx|
            lookups = gpos[2][lk_idx].select{|lk| lk[:coverages].include?(gid)}
            until lookups.empty?
            #lookups.each do |lookup|
              lookup = lookups.pop
              next unless values = lookup[:values]
              
              case subtype = lookup[:subtype]
              when :single_adjust, :pair_adjust # do nothing
              when :base, :mark
                @anchors.push(*values.collect{|klass, (x, y)| ["#{lk_idx}:#{subtype}", x, y]})
              when :cursive
                idx = lookup[:coverages].index(gid)
                ent, exi = values.fetch(idx).values_at(:entry, :exit)
                @anchors.push(["#{lk_idx}:entry", *ent]) if ent
                @anchors.push(["#{lk_idx}:exit", *exi]) if exi
              when :ligature
                idx = lookup[:coverages].index(gid)
                pts = values.fetch(idx)
                pts.each do |pts_lig|
                  @anchors.push(*pts_lig.collect{|klass, (x, y)| ["#{lk_idx}:#{subtype}", x, y]})
                end
              when :context
                idx = lookup[:coverages].index(gid)
                entry = values.find{|val| val[0] == idx}
                next unless entry
                lks = gpos[2][entry[1]]
                lk = lks.find{|lk| lk[:coverages].include?(gid)}
                lookups.push(lk) if lk
              end
            end
          end
          #lookups = gpos[2].values_at(*ft[:lookup_indices]).collect{|lookups| lookups.select{|lk| lk[:type] == :GPOS && lk[:coverages].include?(gid)}}.flatten(1)
          #lookups.each do |lookup|
          #  next unless values = lookup[:values]
          #  #idx = lookup[:coverages].index(gid)
          #  #pts = lookup[:values].fetch(idx)
          #  lk_idx = gpos[2].index(lookup)
          #  case subtype = lookup[:subtype]
          #  when :single_adjust, :pair_adjust # do nothing
          #  when :base, :mark
          #    @anchors.push(*values.collect{|klass, (x, y)| ["#{lk_idx}:#{subtype}", x, y]})
          #  when :ligature
          #    idx = lookup[:coverages].index(gid)
          #    pts = lookup[:values].fetch(idx)
          #    pts.each do |pts_lig|
          #      @anchors.push(*pts_lig.collect{|klass, (x, y)| ["#{lk_idx}:#{subtype}", x, y]})
          #    end
          #    #pp pts
          #    #@anchors.push(*pts.collect{|klass, (x, y)| ["#{klass}:#{subtype}", x, y]})
          #  end
          #end
          #pts = pts.select{|obj| obj.kind_of?(Array) && obj.size == 2}
          #@anchors.push(*pts.collect do |klass, (x, y)|
          #  klass = case ft[:tag]
          #  when :mark then "#{klass}:base"
          #  when :mkmk then "#{klass}:mark"
          #  else ''
          #  end
          #  [klass, x, y]
          #end)
        end
      end
    end
    @features.uniq!
    @anchors.uniq!
    #pp @anchors
  end
  
#  def to_s
#    header = <<EOS
##{$barb}
#Font: #{@font.fullname.first}
#Type: #{@font.class.name.split('::').last}
##{$bar}
#Glyph: #{gid}
#EOS
#    return "#{header}\n(not defined)" unless self.valid?
#    return "#{header}\n(composite glyph)" if self.composite?
#    
#    eoc = @eoc.each_with_index.collect{|c, i| " | #{i}: #{c.to_s.rjust(2)}"}.join("\n")
#    instructions = @insts.each_slice(32).collect{|ins| ins = ins.collect{|x| '%02x' % x}.join(' '); " | #{ins}"}.join("\n")
#    cords = @coordinates.each_with_index.collect{|(x, y, on), i|
#      on = on ? 'end-point' : 'cotrol-point'
#      " | #{i}: (#{x.to_s.rjust(4)}, #{y.to_s.rjust(4)}) ; #{on}"
#    }.join("\n")
#    body = <<EOS
#Contours: #{@nc}
#xmin: #{xmin.to_s.rjust(4)}, xmax: #{xmax.to_s.rjust(4)}
#ymin: #{ymin.to_s.rjust(4)}, ymax: #{ymax.to_s.rjust(4)}
#End Points:
##{eoc}
#Instrunction Length: #{insts.size}
#Instructions:
##{instructions}
#Coordinates:
##{cords}
#EOS
#    header + body
#  end
end

class TtGlyph < Glyph
  
  def composite?; !@simple_glyph end
  
  def initialize(*args)
    super
    @simple_glyph = true
    return unless self.valid?
    d = StringIO.new(@data, 'rb:ASCII-8BIT')
    @nc = d.read(2).unpack('n').pack('s').unpack('s')[0]
    @simple_glyph = 0 <= @nc
    @xmin, @ymin, @xmax, @ymax = d.read(8).unpack('n4').pack('s4').unpack('s4')
    if @simple_glyph
      *eoc, insn = d.read(@nc * 2 + 2).unpack('n*')
      @eoc = eoc
      @insts = d.read(insn).unpack('C*')
      last_contour = eoc.last + 1
      flags = loop.each_with_object([]) do |_, acc|
        break acc if acc.size == last_contour
        flag = d.read(1).ord
        acc.push(flag)
        if flag & 8 != 0
          rep = d.read(1).ord
          acc.push(*([flag] * rep))
        end
      end
      xcdt = flags.collect{|f| f & 2 != 0 ? ((f & 16 == 0 ? -1 : 1) * d.read(1).ord) : (f & 16 == 0 ? d.read(2).unpack('n').pack('s').unpack('s')[0] : nil)}.inject([]){|acc,cur| rel = acc.last || 0; acc.push(rel + (cur || 0))}
      ycdt = flags.collect{|f| f & 4 != 0 ? ((f & 32 == 0 ? -1 : 1) * d.read(1).ord) : (f & 32 == 0 ? d.read(2).unpack('n').pack('s').unpack('s')[0] : nil)}.inject([]){|acc,cur| rel = acc.last || 0; acc.push(rel + (cur || 0))}
      @coordinates = flags.zip(xcdt, ycdt).collect{|flag, x, y| [x, y, flag[0] == 1]}
    else
      flag = 0
      @eoc = []
      @coordinates = []
      begin
        trans = []
        apply = Proc.new {|x, y| trans.empty? ? [x, y] : trans.each_with_object([x, y]){|f, xy|xy.replace(f.call(*xy))}}
        
        flag, idx = d.read(4).unpack('n2')
        x, y = flag[0] == 0 ? d.read(2).unpack('c2') : d.read(4).unpack('n2').pack('s2').unpack('s2')
        #trans.push(Proc.new{|x, y| [(x.round + 32) & ~63, (y.round + 32) & ~63]}) if flag[2] == 1
        
        raise 'ARGS_ARE_XY_VALUES is false' if flag[1] == 0
        
        scale = case
        when flag[3] == 1
          scale = d.read(2).unpack('n').to_f2dot14
          Proc.new {|x, y| [x * scale, y * scale]}
        when flag[6] == 1
          scale_x, scale_y = d.read(4).unpack('n2').collect{|n| n.to_f2dot14}
          Proc.new {|x, y| [x * scale_x, y * scale_y]}
        when flag[7] == 1
          scales = d.read(8).unpack('n4').collect{|n| n.to_f2dot14}
          Proc.new {|x, y|
            x_ = x; y_ = y
            [scales[0] * x_ + scales[1] * y_, y = scales[2] * x_ + scales[3] * y_]
          }
        end
        trans.unshift(scale) if scale
        
        glyph = self.class.new(font, idx, args[2], args[3])
        last_eoc = @eoc.empty? ? 0 : (@eoc.last + 1)
        eoc = glyph.eoc.collect{|n| n + last_eoc}
        @eoc.push(*eoc)
        #cords = glyph.coordinates.collect{|pt| [*scale.call(pt[0] + x, pt[1] + y), pt[2]]}
        cords = glyph.coordinates.collect{|pt| x_, y_ = apply.call(pt[0], pt[1]); [x_ + x, y_ + y, pt[2]]}
        @coordinates.push(*cords)
      end while flag[5] == 1
      
      if flag[8] == 1
        insn = d.read(2).unpack('n')[0]
        @insts = d.read(insn)
      end
    end
  end
  
end

class PsGlyph < Glyph
  
  def initialize(*args)
    super
    return unless self.valid?
    
    dw, hints, ops = parse_ops(@data)
    return if ops == [:endchar]
    
    @eoc = []
    @coordinates = []
    x, y = 0, 0
    stack = []
    until ops.empty?
      case op = ops.shift
      when Numeric
        stack.push(op)
      when :return    # do nothing
      when :hintmask
        ops.shift     # throw away
      when :rmoveto
        # close path
        @eoc.push(@coordinates.size - 1)
        @coordinates.push([x, y, true])
        dx, dy = stack.pop(2)
        x += dx; y += dy
        stack.clear
      when :hmoveto
        # close path
        @eoc.push(@coordinates.size - 1)
        @coordinates.push([x, y, true])
        x += stack.pop
        stack.clear
      when :vmoveto
        # close path
        @eoc.push(@coordinates.size - 1)
        @coordinates.push([x, y, true])
        y += stack.pop
        stack.clear
      when :rlineto
        stack.each_slice(2) do |dx, dy|
          @coordinates.push([x, y, true])
          x += dx; y += dy
        end
        stack.clear
      when :hlineto
        stack.each_with_index do |d, i|
          @coordinates.push([x, y, true])
          i.even? ? (x += d) : (y += d)
        end
        stack.clear
      when :vlineto
        stack.each_with_index do |d, i|
          @coordinates.push([x, y, true])
          i.even? ? (y += d) : (x += d)
        end
        stack.clear
      when :rrcurveto
        stack.each_slice(6) do |dx1, dy1, dx2, dy2, dx3, dy3|
          @coordinates.push([x, y, true], [x += dx1, y += dy1, false], [x += dx2, y += dy2, false])
          x += dx3; y += dy3
        end
        stack.clear
      when :hhcurveto
        dy1 = stack.size % 4 == 0 ? 0 : stack.shift
        dx1, dx2, dy2, dx3 = stack.shift(4)
        @coordinates.push([x, y, true], [x += dx1, y += dy1, false], [x += dx2, y += dy2, false])
        x += dx3
        stack.each_slice(4) do |dx1, dx2, dy2, dx3|
          @coordinates.push([x, y, true], [x += dx1, y, false], [x += dx2, y += dy2, false])
          x += dx3
        end
        stack.clear
      when :hvcurveto
        form = stack.size % 8
        if form == 0 || form == 1
          # |- {dx0 dx1 dy1 dy2 dy3 dx4 dy4 dx5}+ dy5?
          dy_last = form == 0 ? 0 : stack.pop
          stack.each_slice(8) do |dx0, dx1, dy1, dy2, dy3, dx4, dy4, dx5|
            @coordinates.push(
              [x, y, true],
              [x += dx0, y, false],
              [x += dx1, y += dy1, false],
              [x, y += dy2, true],
              [x, y += dy3, false],
              [x += dx4, y += dy4, false],
            )
            x += dx5
          end
          y += dy_last
        else
          # |- dx0 dx1 dy1 dy2 {dy3 dx4 dy4 dx5 dx6 dx7 dy7 dy8}* dx8?
          dx_last = stack.size % 4 == 0 ? 0 : stack.pop
          dx0, dx1, dy1, dy2 = stack.shift(4)
          @coordinates.push([x, y, true], [x += dx0, y, false], [x += dx1, y += dy1, false])
          y += dy2
          stack.each_slice(8) do |dy3, dx4, dy4, dx5, dx6, dx7, dy7, dy8|
            @coordinates.push(
              [x, y, true],
              [x, y += dy3, false],
              [x += dx4, y += dy4, false],
              [x += dx5, y, true],
              [x += dx6, y, false],
              [x += dx7, y += dy7, false]
            )
            y += dy8
          end
          x += dx_last
        end
        stack.clear
      when :rcurveline
        line_args = stack.pop(2)
        stack.each_slice(6) do |dx1, dy1, dx2, dy2, dx3, dy3|
          @coordinates.push([x, y, true], [x += dx1, y += dy1, false], [x += dx2, y += dy2, false], [x += dx3, y += dy3, true])
        end
        x += line_args[0]
        y += line_args[1]
        stack.clear
      when :rlinecurve
        curve_args = stack.pop(6)
        stack.each_slice(2) do |dx, dy|
          @coordinates.push([x, y, true])
          x += dx; y += dy
        end
        dx1, dy1, dx2, dy2, dx3, dy3 = curve_args
        @coordinates.push([x, y, true], [x += dx1, y += dy1, false], [x += dx2, y += dy2, false])
        x += dx3; y += dy3
        stack.clear
      when :vhcurveto
        form = stack.size % 8
        if form == 0 || form == 1
          # |- {dy0 dx1 dy1 dx2 dx3 dx4 dy4 dy5}+ dx5?
          dx_last = form == 0 ? 0 : stack.pop
          stack.each_slice(8) do |dy0, dx1, dy1, dx2, dx3, dx4, dy4, dy5|
            @coordinates.push(
              [x, y, true],
              [x, y += dy0, false],
              [x += dx1, y += dy1, false],
              [x += dx2, y, true],
              [x += dx3, y, false],
              [x += dx4, y += dy4, false]
            )
            y += dy5
          end
          x += dx_last
        else
          # |- dy0 dx1 dy1 dx2 {dx3 dx4 dy4 dy5 dy6 dx7 dy7 dx8}* dy8?
          dy_last = stack.size % 4 == 0 ? 0 : stack.pop
          dy0, dx1, dy1, dx2 = stack.shift(4)
          @coordinates.push([x, y, true], [x, y += dy0, false], [x += dx1, y += dy1, false])
          x += dx2
          stack.each_slice(8) do |dx3, dx4, dy4, dy5, dy6, dx7, dy7, dx8|
            @coordinates.push(
              [x, y, true],
              [x += dx3, y, false],
              [x += dx4, y += dy4, false],
              [x, y += dy5, true],
              [x, y += dy6, false],
              [x += dx7, y += dy7, false]
            )
            x += dx8
          end
          y += dy_last
        end
        stack.clear
      when :vvcurveto
        dx1 = stack.size % 4 == 0 ? 0 : stack.shift
        dy1, dx2, dy2, dy3 = stack.shift(4)
        @coordinates.push([x, y, true], [x += dx1, y += dy1, false], [x += dx2, y += dy2, false])
        y += dy3
        stack.each_slice(4) do |dy1, dx2, dy2, dy3|
          @coordinates.push([x, y, true], [x, y += dy1, false], [x += dx2, y += dy2, false])
          y += dy3
        end
        stack.clear
      when :endchar
        @coordinates.shift
        @eoc.shift
        @coordinates.push([x, y, true])
        @eoc.push(@coordinates.size - 1)
        xmin, xmax = @coordinates.minmax{|pt0, pt1| pt0[0] <=> pt1[0]}
        ymin, ymax = @coordinates.minmax{|pt0, pt1| pt0[1] <=> pt1[1]}
        @xmin, @xmax = xmin[0], xmax[0]
        @ymin, @ymax = ymin[1], ymax[1]
        break
      else
        raise NotImplementedError, op.to_s
      end
    end
    
    if @tsb.nil?
      # get y-origin from VORG table
      # Note: VORG table obtains only vertical origin,
      # not includes advance height. It is contained only
      # 'vmtx' table
      yorigin = font.get_vmetrics(gid)
      @tsb = yorigin[:origin] - @ymax if (yorigin && yorigin.has_key?(:origin))
    end
    
  end
  
  private
  
  def parse_ops(str, detect=true, stack=[])
    op = str.bytes
    until op.empty?
      case v = op.shift
      when 28 then stack.push([(op.shift << 8) | op.shift].pack('s').unpack('s')[0])
      when (0..31)
        v = (v << 8) | op.shift if v == 12
        o = Operators.fetch(v)
        case o
        when :return
          break
        when :callsubr
          subr = font.subr(stack.pop, gid)
          parse_ops(subr, false, stack)
        when :callgsubr
          subr = font.gsubr(stack.pop)
          parse_ops(subr, false, stack)
        when :hintmask, :cntrmask
          n = stack.each_with_object([0, 0]) do |cur, acc|
            case cur
            when Numeric then acc[1] += 1
            when :vstem, :hstem, :vstemhm, :hstemhm
              acc[0] += acc[1] / 2
              acc[1] = 0
            when :hintmask, :cntrmask
              break acc
            else acc[1] = 0
            end
          end
          n = [((n[0] + n[1] / 2) / 8.0).ceil, 1].max
          stack.push(o, op.shift(n)) # as array
        else stack.push(o)
        end
      when (32..246)  then stack.push(v - 139)
      when (247..250) then stack.push((v - 247) * 256 + op.shift + 108)
      when (251..254) then stack.push(-(v - 251) * 256 - op.shift - 108)
      when 255        then stack.push(op.shift(4).reverse.pack('l').unpack('l')[0])
      end
    end
    
    return stack unless detect
    
    last_op_idx = -1
    fst_op, idx = stack.find.with_index do |op, i|
      next if op.kind_of?(Numeric)
      break [op, i] if /move|endchar|line|curve|flex/ =~ op.to_s
      last_op_idx = i
      false
    end
    
    dw, hints, ops = case
    when fst_op == :endchar
      # blank operators
      raise ArgumentError, 'invalid operators' if 2 < stack.size
      dw = stack.size == 2 ? stack.shift : 0
      [dw, [], stack]  # => [ dw, [], [:endchar] ]
    when 0 < last_op_idx
      # include hint operator
      # hint operators always take even count of arguments
      hints = stack.shift(last_op_idx + 1)
      dw = hints.index{|op| op.instance_of?(Symbol)}.odd? ? hints.shift : 0
      # check hstemhm-hintmask sequence, and making up vstemhm operator
      case hints.last
      when :hintmask
        # treat hintmask ops as path operator because it would be included in path operators
        # so move itself to path ops stack
        stack.unshift(hints.pop)
        last_hint_op = hints.rindex{|op| op.instance_of?(Symbol)}
        hints.push(:vstemhm) if last_hint_op == :hstemhm
      when :cntrmask
        # treat cntrmask ops as hint operator because it will not be included in path operators
        # so move its operand from bottom of the path ops stack to hints stack
        hints.push(stack.unshift)
      end
      [dw, hints, stack]
    else
      # not include any hint operators
      case fst_op
      when :hmoveto, :vmoveto
        # take one argument
        dw = idx == 2 ? stack.shift : 0
        [dw, [], stack]
      when :rmoveto
        # takes two arguments
        dw = idx == 3 ? stack.shift : 0
        [dw, [], stack]
      else
        # must not happen
        [0, [], stack]
      end
    end
    
    raise ArgumentError, 'numeric width expected, but else given' unless dw.kind_of?(Numeric)
    raise ArgumentError, 'invalid cntrmask operator' if hints.each_cons(2).any?{|op1, op2| op1 == :cntrmask && !op2.instance_of?(Array)}
    raise ArgumentError, 'invalid hintmask operator' if ops.each_cons(2).any?{|op1, op2| op1 == :hintmask && !op2.kind_of?(Array)}
    [dw, hints, ops]
  end
  
  Operators = {
    0 => :Reserved, 1 => :hstem, 2 => :Reserved, 3 => :vstem, 4 => :vmoveto, 5 => :rlineto, 6 => :hlineto, 7 => :vlineto,
    8 => :rrcurveto, 9 => :Reserved, 10 => :callsubr, 11 => :return, 13 => :Reserved, 14 => :endchar, 15 => :Reserved,
    16 => :Reserved, 17 => :Reserved, 18 => :hstemhm, 19 => :hintmask, 20 => :cntrmask, 21 => :rmoveto, 22 => :hmoveto, 23 => :vstemhm,
    24 => :rcurveline, 25 => :rlinecurve, 26 => :vvcurveto, 27 => :hhcurveto, 29 => :callgsubr, 30 => :vhcurveto, 31 => :hvcurveto,
    0x0c00 => :Reserved, 0x0c01 => :Reserved, 0x0c02 => :Reserved, 0x0c03 => :and,
    0x0c04 => :or, 0x0c05 => :not, 0x0c06 => :Reserved, 0x0c07 => :Reserved,
    0x0c08 => :Reserved, 0x0c09 => :abs, 0x0c0a => :add, 0x0c0b => :sub,
    0x0c0c => :div, 0x0c0d => :Reserved, 0x0c0e => :neg, 0x0c0f => :eq,
    0x0c10 => :Reserved, 0x0c11 => :Reserved, 0x0c12 => :drop, 0x0c13 => :Reserved,
    0x0c14 => :put, 0x0c15 => :get, 0x0c16 => :ifelse, 0x0c17 => :random,
    0x0c18 => :mul, 0x0c19 => :Reserved, 0x0c1a => :sqrt, 0x0c1b => :dup,
    0x0c1c => :exch, 0x0c1d => :index, 0x0c1e => :roll, 0x0c1f => :Reserved,
    0x0c20 => :Reserved, 0x0c21 => :Reserved, 0x0c22 => :hflex, 0x0c23 => :flex,
    0x0c24 => :hflex1, 0x0c25 => :flex1,
    #0x0c260cff => :Reserved, 
  }.delete_if{|k, v| v == :Reserved}.freeze
  
  def exec_ops(ops)
  end
  
end

def update_window(window, glyph, show_box, show_point, show_metrics, aa)
  window.caption = "#{glyph.font.fullname.first} / #{glyph.gid}"
  unless glyph.valid?
    window.draw_font_ex(5, 0, "GID #{glyph.gid}", $font, color: [0,0,0])
    str = glyph.composite? ? 'composite glyph' : 'not defined'
    window.draw_font_ex(5, 16, str, $font, color: [0,0,0])
    return
  end
  
  w, h = window.width, window.height
  
  font = glyph.font
  xmin, xmax, ymin, ymax = %i{ xmin xmax ymin ymax }.collect{|sym| font.send(sym)}
  gw = xmax - xmin
  gh = ymax - ymin
  g = [gw, gh].max.to_f
  r = w / g * $scale.to_f
  mx, my = $margin_x, $margin_y
  
  gxmin, gxmax, gymin, gymax = %i{ xmin xmax ymin ymax }.collect{|sym| glyph.send(sym)}
  
  # bounding box
  if show_box
    bbox0 = [xmin * r + mx, h - ymin * r - my, xmax * r + mx, h - ymax * r - my]
    bbox0_h_dotline = Image.create_from_array(1, h, ([[128, 0, 0, 255], [0, 0, 0, 0]] * (h / 2)).flatten(1))
    bbox0_v_dotline = Image.create_from_array(w, 1, ([[128, 0, 0, 255], [0, 0, 0, 0]] * (w / 2)).flatten(1))
    bbox = [gxmin * r + mx, h - gymin * r - my, gxmax * r + mx, h - gymax * r - my]
    window.draw_box_fill(*bbox0, [200, 200, 255])
    window.draw(bbox0[0], 0, bbox0_h_dotline)
    window.draw(0, bbox0[1], bbox0_v_dotline)
    window.draw(bbox0[2], 0, bbox0_h_dotline)
    window.draw(0, bbox0[3], bbox0_v_dotline)
    window.draw_box_fill(*bbox, [255, 200, 200])
  end
  
  # axes
  #origin = [[-gxmin, 0].max * r, [-gymin, 0].max * r]
  origin = [0, 0]
  window.draw_line(0, h - origin[1] - my, w, h - origin[1] - my, [32, 0, 0, 0]) # x-axis
  window.draw_line(origin[0] + mx, 0, origin[0] + mx, h, [32, 0, 0, 0])         # y-axis
  
  # horizontal and vertical metrics
  if show_metrics
    # horizontal
    aw, lsb = glyph.aw, glyph.lsb
    h_dotline = Image.create_from_array(1, h, ([[128, 255, 0, 0], [0, 0, 0, 0]] * (h / 2)).flatten(1))
    aw_x, lsb_x = [aw, lsb].collect{|w| w * r - 3 + mx}
    aw_y = lsb_y = h - origin[1] - my - 3
    window.draw(aw_x, 0, h_dotline)
    window.draw_font_ex(aw_x + 5, h - 12,  "aw=#{aw}", $font_small, color: [0,0,0])
    window.draw(lsb_x, 0, h_dotline)
    lsb_w = $font_small.get_width("lsb=#{lsb}")
    window.draw_font_ex(lsb_x - lsb_w - 3, h - 12,  "lsb=#{lsb}", $font_small, color: [0,0,0])
    
    # vertical
    ah, tsb = glyph.ah, glyph.tsb
    if tsb
      v_dotline = Image.create_from_array(w, 1, ([[128, 0, 0, 255], [0, 0, 0, 0]] * (w / 2)).flatten(1))
      tsb_x = origin[0] + mx - 3
      tsb_y = h - (gymax + tsb) * r - my - 3
      window.draw(0, tsb_y + 3, v_dotline)
      window.draw_font_ex(3, tsb_y + 5,  "tsb=#{tsb}", $font_small, color: [0,0,0])
      if ah
        ah_x = origin[0] + mx - 3
        ah_y = tsb_y + ah * r
        window.draw(0, ah_y + 3, v_dotline)
        #window.draw(ah_x, ah_y, ah_box)
        #window.draw_font_ex(ah_x - 12, ah_y + 5,  "ah", $font_small, color: [0,0,0])
        #window.draw_font_ex(ah_x - 28, ah_y + 15,  ah.to_s.rjust(5), $font_small, color: [0,0,0])
        window.draw_font_ex(3, ah_y + 5,  "ah=#{ah}", $font_small, color: [0,0,0])
      end
    end
  end
  
  # glyph
  points = glyph.coordinates.collect{|x, y, on| [x * r, y * r, on]}
  first_idx = 0
  on_box = Image.new(5, 5); on_box.fill([0, 0, 255])
  off_box = Image.new(6, 6); #off_box.box(0, 0, 5, 5, [255, 0, 0])
  off_box.line(0, 0, 5, 5, [255, 0, 0]); off_box.line(0, 5, 5, 0, [255, 0, 0])
  glyph.eoc.each do |idx|
    pts = points[first_idx..idx] << points[first_idx]
    pts[0][2] = true
    
    if aa
      from = pts.shift
      real_knot = from[2]
      until pts.empty?
        to = pts.shift
        x0, y0 = real_knot ? [from[0] + mx, h - from[1] - my] : from
        x1, y1 = to[0] + mx, h - to[1] - my
        
        window.draw(x0 - 2, y0 - 2, on_box) if show_point && real_knot
        
        if to[2]
          # straigh line
          window.draw_line(x0, y0, x1, y1, [0, 0, 0])
          from = to
          real_knot = true
        else
          # "to", x1 and y1 defined above is control point
          window.draw(x1 - 3, y1 - 3, off_box) if show_point
          to = pts.shift
          x2 = to[0] + mx
          y2 = h - to[1] - my
          if $bezier
            # 3-order bezier curve
            window.draw(x2 - 3, y2 - 3, off_box) if show_point
            to = pts.shift
            x3 = to[0] + mx
            y3 = h - to[1] - my
            window.draw_spline3(x0, y0, x1, y1, x2, y2, x3, y3, [0, 0, 0])
            from = to
            real_knot = true
          elsif to[2]
            window.draw_spline2(x0, y0, x1, y1, x2, y2, [0, 0, 0])
            from = to
            real_knot = true
          else
            # center of [x1, y1] and [x2, y2] is temporary knot point
            pts.unshift(to)
            x2, y2 = [(x1 + x2) / 2, (y1 + y2) / 2]
            window.draw_spline2(x0, y0, x1, y1, x2, y2, [0, 0, 0])
            from = [x2, y2]
            real_knot = false
          end
        end
      end
    else
      pts.each_cons(2) do |from, to|
        x0, y0 = from[0] + mx, h - from[1] - my
        x1, y1 = to[0] + mx, h - to[1] - my
        if show_point
          from[2] ? window.draw(x0 - 2, y0 - 2, on_box) : window.draw(x0 - 3, y0 - 3, off_box)
        end
        window.draw_line(x0, y0, x1, y1, [0, 0, 0])
      end
    end
    first_idx = idx + 1
  end
  
  # anchors
  if show_point && !glyph.anchors.empty?
    anchor_box = Image.new(10, 10)
    anchor_box.line(0, 0, 9, 9, [255, 0, 255]); anchor_box.line(0, 9, 9, 0, [255, 0, 255])
    anchor_box.circle_fill(5, 5, 3, [255, 0, 255])
    y_center = bbox[1] / 2
    xy = []
    glyph.anchors.each do |klass, x, y|
      x = x * r + mx
      y = h - y * r - my
      dx = $font_small.get_width(klass)
      dy = y < y_center ? -16 : 7
      dy *= xy.count([x, y]) + 1
      window.draw_font_ex(x - dx / 2, y + dy, klass, $font_small, color: [0,0,0])
      window.draw(x - 5, y - 5, anchor_box)
      xy.push([x, y])
    end
  end
  
  
  # infomations
  y = 0
  s = $font.size
  window.draw_font_ex(5, y,  "GID #{glyph.gid}", $font, color: [0,0,0]); y += s
  #window.draw_font_ex(5, 16, "O=(#{origin[0].round(3)}, #{origin[1].round(3)})", $font, color: [0,0,0]); y += s
  window.draw_font_ex(5, y, "#{glyph.uni ? glyph.uni.collect{|u|'U+%04x'%u}.join(', ') : 'U+????'}", $font, color: [0,0,0]); y += s
  window.draw_font_ex(5, y, "scale=#{r.round(3)}", $font, color: [0,0,0]); y += s
  window.draw_font_ex(5, y, "x=(#{gxmin}..#{gxmax}), y=(#{gymin}..#{gymax})", $font, color: [0,0,0]); y += s
  mouse_x, mouse_y = Input.mouse_pos_x, Input.mouse_pos_y
  mouse_x = (mouse_x - mx) / r - origin[0]; mouse_y = (h - mouse_y - my) / r - origin[1]
  window.draw_font_ex(5, y, "(#{mouse_x.round(3)}, #{mouse_y.round(3)})", $font, color: [0,0,0]); y += s
  window.draw_font_ex(5, y, 'Features:', $font, color: [0,0,0]); y += s
  features = glyph.features
  if features.empty?
    window.draw_font_ex(21, y, '(none)', $font, color: [0,0,0]); y += s
  else
    features.each {|ft| window.draw_font_ex(21, y, "<#{ft}>", $font, color: [0,0,0]); y += s}
  end
end

require 'dxruby'

def Window.draw_spline2(x0, y0, x1, y1, x2, y2, color=[0, 0, 0], div: 20)
  if div <= 1.0
    self.draw_line(x0, y0, x1, y1, color)
    self.draw_line(x1, y1, x2, y2, color)
    return
  end
  
  dt = 1.0 / div
  ctrls = 0.0.step(1.0, dt).collect do |t|
    u = 1 - t
    u2 = u * u
    t2 = t * t
    tu = u * t
    x = u2 * x0 + 2 * tu * x1 + t2 * x2
    y = u2 * y0 + 2 * tu * y1 + t2 * y2
    [x, y]
  end
  
  ctrls.unshift([x0, y0])
  ctrls.push([x2, y2])
  
  ctrls.each_cons(2){|pt0, pt1| self.draw_line(*pt0, *pt1, color)}
end

def Window.draw_spline3(x0, y0, x1, y1, x2, y2, x3, y3, color=[0, 0, 0], div: 20)
  if div <= 1.0
    self.draw_line(x0, y0, x1, y1, color)
    self.draw_line(x1, y1, x2, y2, color)
    self.draw_line(x2, y2, x3, y3, color)
    return
  end
  
  dt = 1.0 / div
  ctrls = 0.0.step(1.0, dt).collect do |t|
    u = 1 - t
    u2 = u * u
    u3 = u2 * u
    t2 = t * t
    t3 = t2 * t
    tu = u * t
    x = u3 * x0 + 3 * u2 * t * x1 + 3 * u * t2 * x2 + t3 * x3
    y = u3 * y0 + 3 * u2 * t * y1 + 3 * u * t2 * y2 + t3 * y3
    [x, y]
  end
  
  ctrls.unshift([x0, y0])
  ctrls.push([x3, y3])
  
  ctrls.each_cons(2){|pt0, pt1| self.draw_line(*pt0, *pt1, color)}
end

Margin_X = 50
Margin_Y = 50
Scale = Rational(1, 1)
Scale_a = Rational(2, 3)
$margin_x = Margin_X
$margin_y = Margin_Y
$scale = Scale
$font = Font.new(16, 'Consolas')
$font_small = Font.new(12, 'Consolas')

#until ARGV.empty?
font_path = ARGV.shift || 'c:/windows/fonts/arial.ttf'
#next unless /\.[ot]tf$/ =~ font_path
#next unless FileTest.file?(font_path)
#puts font_path
font = YARP::Utils::Font.new(font_path)
cmaps = font.get_cmaps.select(&:unicode_keyed?)
gpos = font[:GPOS]
#end
#exit
$bezier = font.kind_of?(YARP::Utils::Font::OpenType)
max_gid = font.glyphcount - 1
gid = 0
glyph = Glyph.new(font, gid, cmaps, gpos)

$width = 512
$height = 512

Window.width = $width
Window.height = $height
Window.bgcolor = [255, 255, 255]
Window.fps = 30

Input.set_repeat(10, 5)

def Input.key_repeat_off(*keys)
  keys.flatten.each {|key| self.set_key_repeat(key, 0, 0)}
end

key_to_off = [
  K_A, K_S, K_D, K_LALT, K_RALT, K_0, K_1, K_2, K_3, K_4, K_5, K_6, K_7, K_8, K_9,
  K_NUMPAD0, K_NUMPAD1, K_NUMPAD2, K_NUMPAD3, K_NUMPAD4, K_NUMPAD5, K_NUMPAD6, K_NUMPAD7, K_NUMPAD8, K_NUMPAD9
]
Input.key_repeat_off(key_to_off)

Input.set_cursor(IDC_CROSS)
#$unit_per_pixel = 8.0

gid_changed = true
show_box = true
show_point = true
show_metrics = true
aa = true
gid_wait = nil
begin
Window.loop do
  update_window(Window, glyph, show_box, show_point, show_metrics, aa)
  #if gid_changed
  #  update_window(Window, glyph)
  #  gid_changed = false
  #end
  
  #a = Input.key_down?(K_LALT) || Input.key_down?(K_RALT)
  s = Input.key_down?(K_LSHIFT) || Input.key_down?(K_RSHIFT)
  c = Input.key_down?(K_LCONTROL) || Input.key_down?(K_RCONTROL)
  #gid+=1;glyph=Glyph.new(font,gid,cmaps, gpos)
  case
  when Input.key_down?(K_LALT) || Input.key_down?(K_RALT)
    gid_wait ||= []
    n = case
    when Input.key_push?(K_0) || Input.key_push?(K_NUMPAD0) then 0
    when Input.key_push?(K_1) || Input.key_push?(K_NUMPAD1) then 1
    when Input.key_push?(K_2) || Input.key_push?(K_NUMPAD2) then 2
    when Input.key_push?(K_3) || Input.key_push?(K_NUMPAD3) then 3
    when Input.key_push?(K_4) || Input.key_push?(K_NUMPAD4) then 4
    when Input.key_push?(K_5) || Input.key_push?(K_NUMPAD5) then 5
    when Input.key_push?(K_6) || Input.key_push?(K_NUMPAD6) then 6
    when Input.key_push?(K_7) || Input.key_push?(K_NUMPAD7) then 7
    when Input.key_push?(K_8) || Input.key_push?(K_NUMPAD8) then 8
    when Input.key_push?(K_9) || Input.key_push?(K_NUMPAD9) then 9
    end
    gid_wait.push(n) if n
  when (Input.key_release?(K_LALT) || Input.key_release?(K_RALT)) && gid_wait && !gid_wait.empty?
    gid_ = gid_wait.inject(0){|acc, n| acc = acc * 10 + n}
    gid = gid_ < 0 ? 0 : max_gid < gid_ ? max_gid : gid_
    glyph = Glyph.new(font, gid, cmaps, gpos)
    gid_wait = nil
  end
  
  case
  when Input.key_push?(K_HOME)
    gid = 0
    glyph = Glyph.new(font, gid, cmaps, gpos)
  when Input.key_push?(K_END)
    gid = max_gid
    glyph = Glyph.new(font, gid, cmaps, gpos)
  when Input.key_push?(K_END)
    gid = max_gid
    glyph = Glyph.new(font, gid, cmaps, gpos)
  when s && Input.key_down?(K_PRIOR)
    gid -= 16
    gid = 0 if gid < 0
    glyph = Glyph.new(font, gid, cmaps, gpos)
  when s && Input.key_down?(K_NEXT)
    gid += 16
    gid = max_gid if max_gid < gid
    glyph = Glyph.new(font, gid, cmaps, gpos)
  when s && Input.key_down?(K_LEFT)
    if gid != 0
      gid -= 1
      glyph = Glyph.new(font, gid, cmaps, gpos)
    end
  when s && Input.key_down?(K_RIGHT)
    if gid != max_gid
      gid += 1
      glyph = Glyph.new(font, gid, cmaps, gpos)
    end
  when c && Input.key_down?(K_UP)
    $margin_y -= 10
    $margin_x += 10 if Input.key_down?(K_LEFT)
    $margin_x -= 10 if Input.key_down?(K_RIGHT)
  when c && Input.key_down?(K_DOWN)
    $margin_y += 10
    $margin_x += 10 if Input.key_down?(K_LEFT)
    $margin_x -= 10 if Input.key_down?(K_RIGHT)
  when c && Input.key_down?(K_LEFT)
    $margin_x += 10
  when c && Input.key_down?(K_RIGHT)
    $margin_x -= 10
  when Input.key_push?(K_PRIOR)
    gid -= 16
    gid = 0 if gid < 0
    glyph = Glyph.new(font, gid, cmaps, gpos)
  when Input.key_push?(K_NEXT)
    gid += 16
    gid = max_gid if max_gid < gid
    glyph = Glyph.new(font, gid, cmaps, gpos)
  when Input.key_push?(K_LEFT)
    if gid != 0
      gid -= 1
      glyph = Glyph.new(font, gid, cmaps, gpos)
    end
  when Input.key_push?(K_RIGHT)
    if gid != max_gid
      gid += 1
      glyph = Glyph.new(font, gid, cmaps, gpos)
    end
  when Input.key_push?(K_A)
    aa = !aa
  when Input.key_push?(K_S)
    show_box = !show_box
  when Input.key_push?(K_D)
    show_point = !show_point
  when Input.key_push?(K_F)
    show_metrics = !show_metrics
  when Input.key_push?(K_O)
    $margin_x = Margin_X
    $margin_y = Margin_Y
    $scale = Scale
  when s && Input.key_push?(K_Z)
    w, h = Window.width, Window.height
    w *= Scale_a; h *= Scale_a
    Window.resize(w, h)
  when s && Input.key_push?(K_X)
    w, h = Window.width, Window.height
    w /= Scale_a; h /= Scale_a
    Window.resize(w, h)
  when Input.key_push?(K_Z)
    $scale *= Scale_a
  when Input.key_push?(K_X)
    $scale /= Scale_a
  when Input.key_push?(K_ESCAPE) || Input.key_push?(K_Q)
    break
  end
end
rescue Exception
  puts gid
  p $@
  raise
end

