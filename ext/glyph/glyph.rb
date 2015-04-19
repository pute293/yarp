class Glyph
  
  class << self
    
    alias :newobj :new
    
    def new(font, gid, cmaps=nil, gpos=nil)
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
  
  def valid?; !!@data && !@data.empty? end
  
  def composite?; false end
  
  def initialize(font, gid, cmaps=nil, gpos=nil)
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
    
    if cmaps
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
    else
      @uni = nil
    end
    
    if gpos
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
          end
        end
      end
      @features.uniq!
      @anchors.uniq!
    else
      @features = nil
      @anchors = []
    end
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
