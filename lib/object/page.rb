module PDF
  
  class PageTree < PdfObject
    
    attr_reader :count
    
    def initialize(*args)
      super
      @pages = Hash.new{|hash, key| hash[key] = reload_page(key)}
      #@pages = Hash.new{|_, key| reload_page(key)}
      @count = self[:Count]
    end
    
    include Enumerable
    def each
      count.times do |n|
        yield @pages[n]
      end
    end
    
    # some entries in Pages Object is inheritable
    def [](key)
      if key.kind_of?(Integer)
        #@pages.fetch(key)
        @pages[key]
      else
        ret = super
        unless ret
          parent = self[:Parent]
          ret = parent ? parent[key] : nil
        end
        ret
      end
    end
    
    def fetch(key)
      begin
        super
      rescue KeyError
        parent = self[:Parent]
        raise if parent.nil?  # re-raise KeyError
        parent.fetch(key)
      end
    end
    
    private
    
    def reload_page(n)
      kids = @kids ||= self[:Kids]
      last_page = 0
      kids.each do |page_or_pagetree|
        if page_or_pagetree.kind_of?(self.class)
          # page tree
          tree = page_or_pagetree
          return tree[n - last_page] if n - last_page < tree.count
          last_page += tree.count
        else
          page = page_or_pagetree
          return page if n == last_page
          last_page += 1
        end
      end
    end
    
  end
  
  class Page < PdfObject
    def initialize(*args)
      super
      rc_ = self.Resources
      @rc = case rc_
        when nil    then nil
        when Ref then rc_.data
        else rc_
        end
      define_method_missing(@rc) if @rc.kind_of?(Hash)
      @op_parser = Parser::OperationParser.new
    end
    
    # some entries in Page Object is inheritable
    def [](key)
      ret = super
      unless ret
        parent = self[:Parent]
        ret = parent[key]
      end
      ret
    end
    
    def fetch(key)
      begin
        super
      rescue KeyError
        parent = self[:Parent]
        parent.fetch(key)
      end
    end
    
    def contents
      cont = self[:Contents]
      case cont
      when Enumerable
        cont.collect {|c| c.kind_of?(Ref) ? c.data : c}
      when PdfObject then cont
      when Ref    then cont.data
      else nil
      end
    end
    
    def stream
      cont = self.contents
      case cont
      when Enumerable
        cont.collect{|c|c.decode_stream}.join
      when nil
        nil
      else
        cont.decode_stream
      end
    end
    
    def resources; @rc end
    alias rc resources
    
    def objects
      self.to_enum(:each_object)
    end
    
    def each_object
      objs = @rc[:XObject] || []
      objs = objs.data if objs.kind_of?(Ref)
      objs = objs.dict if objs.kind_of?(PdfObject)
      objs.each {|k,v|
        v = v.data if v.kind_of?(Ref)
        yield v
      }
    end
    
    def images
      self.to_enum(:each_image)
    end
    
    def each_image
      each_object {|obj| yield obj if obj.subtype == :Image }
    end
    
    def raw_operators
      ops
    end
    
    def operators
      return @operators if @operators
      
      fonts = self.resources[:Font]
      font = nil
      @operators = ops.collect do |dict|
        op, args = dict[:op], dict[:args]
        case op
        when :Tf
          font = fonts.fetch(args[0])
          font = font.data if font.kind_of?(Ref)
          {:op => op, :args => args}
        when :Tj, :'"', :"'"
          str = args.last
          str = font.decode(str)
          {:op => op, :args => [str]}
        when :TJ
          args = args[0].collect {|item| item.kind_of?(String) ? font.decode(item) : item}
          {:op => op, :args => [args]}
        else {:op => op, :args => args}
        end
      end
    end
    
    def strings
      @strings ||= get_string_boxes.collect(&:to_s)
    end
    
    def text(
        keep_layout: true,    # if true, keep line feeds in contents; otherwise, detect paragraphs and concatenate each lines in a paragraph
        newline: "\n",        # newline marker which used to concatenate each line (when keep_layout is true) or each paragraph
        indent: true,         # [ignored if keep_layout is false] if true, do not modify the original indentations;
                              # if false, remove all original indentations; otherwise, concatenate this value (#to_s will be called) with each paragraph
        replace_cntrl: false, # if true, resulted text's control characters (\x00-\x1f) except for white space (TAB:\x09, LF:\x0a, CR:\x0d) are replaced to a space (\x20)
                              # note: VT:\x0b and FF:\x0c are not treated as white space in this method, so they are also replaced to a space
        margin_h: nil,        # 
        margin_v: nil,        # 
        line_height: nil,     # [ignored if keep_layout is false] used to detect wheather a line belongs to a paragraph
        epsilon: nil          # 
      )
      
      StringBox.margin_h = margin_h.to_f if margin_h
      StringBox.margin_v = margin_v.to_f if margin_v
      StringBox.line_height = line_height.to_f if line_height
      StringBox.epsilon = epsilon.to_f if epsilon
      
      newline = newline.to_s
      indent = case indent
      when TrueClass then ''
      when FalseClass, NilClass then false
      else indent.to_s
      end
      epsilon = StringBox.epsilon
      
      mediabox = self[:MediaBox]
      m = Magick
      canvas = m::Image.new(mediabox[2], mediabox[3])
      canvas.format = 'PNG'
      draw = m::Draw.new
      draw.stroke('red')
      draw.stroke_width(1)
      draw.fill_opacity(0.0)
      
      #require_relative '../utils/histgram'
      #h = Histgram.new(0, mediabox[2])
      
      strs = get_string_boxes.group_by(&:angle)
      nans = strs.delete(Float::NAN)
      #strs = @strings.group_by(&:section)
      strs = strs.collect do |angle, boxes|
        #boxes.each do |box|
        #  x0,y0,x1,y1 = box.rectangle
        #  #warn box.to_s
        #  #warn [x0,y0,x1,y1].to_s
        #  draw.rectangle(x0,mediabox[3]-y1,x1,mediabox[3]-y0)
        #  #x0, y0 = box.origin
        #  #w, h = box.box_size
        #  #x1, y1 = x0 + h, y0 - w
        #  #warn box.to_s
        #  #warn [x0,y0,x1,y1, w, h].to_s
        #  draw.rectangle(x0,mediabox[3]-y0,x1,mediabox[3]-y1)
        #end
        next if boxes.empty?
        
        # 
        # 1. resolve intersected strings
        # 
        
        intersected = boxes.combination(2).select{|a,b| a.intersect?(b)}
        intersected = intersected.inject([]) {|acc, item1|
          # make multi-intersected boxes [[a1, b], [a2, b], ...] to be single array [a1, b, a2, b, ...]
          ary = acc.find{|item2| (item1 & item2).empty?.!}
          if ary
            ary.push(*item1)
            acc
          else acc.push(item1)
          end
        }.collect(&:uniq) # [a1, b, a2, b, ...] => [a1, a2, b, ...]
        
        isolated = boxes - intersected.flatten
        intersected = intersected.collect{|array| array.inject{|item1,item2| item1.join(item2)}}
        boxes = isolated | intersected
        
        while ab = boxes.combination(2).find{|a,b| a.intersect?(b) ? (break [a, b]) : false }
          a, b = boxes.delete(ab[0]), boxes.delete(ab[1])
          boxes.push(a.join(b))
        end
        
        next boxes[0].to_s.rstrip if boxes.size == 1
        
        # "lines" has more than two items.
        
        # Sort by opetrator order (for column sets), then top-to-down, then left-to-right.
        # If successive two items are in same height, they are joined.
        #lines = boxes.sort_by{|box| box.origin[0]}.sort_by.with_index{|box, i| [-box.origin[1], i]}.sort_by.with_index{|box, i| [box.section, i]}
        lines = boxes.sort_by{|box| box.origin[0]}.sort_by.with_index{|box, i| [-box.origin[1], i]}.sort_by.with_index{|box, i| [box.order, i]}
        lines = lines.drop(1).each_with_object([lines[0]]) do |line, acc|
          #o = acc.last.origin
          #if o[1] == line.origin[1]
          if line.same_line?(acc.last)
          then acc[-1] = acc.last.join(line)  # Array#last= is not defined...
          else acc.push(line)
          end
        end
        
        next lines.collect(&:to_s).collect(&:rstrip).join(newline) if keep_layout
        
        # 
        # 2. detect paragraphs
        # 
        
        # clusterize near lines
        chapters = lines.each_with_object([]) do |line, acc|
          chapter = acc.find{|lines| line.neighbor?(lines)}
          if chapter
          then chapter.push(line)
          else acc.push([line])
          end
        end
        
        paragraphs = chapters.each_with_object([]) do |chapter, acc|
          next if chapter.empty?
          
          prgs = []
          prg = ''
          last_line = nil
          chapter.reverse_each do |line|
            s = line.to_s
            if last_line.nil?
              # new paragraph
              prg = s
              last_line = line
            else
              indent_value = line.indent_delta(last_line)
              if indent_value.abs < epsilon
                # same paragraph as last line
                prg = s + prg
              else
                # first line of paragraph
                s = indent + s if (indent && /\A[[:space:]]/ !~ s)
                prgs.unshift(s + prg)
                prg = ''
                last_line = nil
              end
            end
          end
          prgs.unshift(prg) unless prg.empty?
          acc.push(*prgs)
        end
        
        paragraphs.collect!{|line| line.gsub(/\A[[:space:]]+/, '')} unless indent
        paragraphs.collect(&:rstrip).join(newline)
      end
      #draw.draw(canvas)
      #IO.binwrite('tate-013.png', canvas.to_blob)
      
      strs.push(nans.collect(&:to_s).join(newline)) if nans
      strs = strs.compact.join(newline * 2)
      strs.gsub!(/[\x00-\x08\x0b\x0c\x0e-\x1f]+/, ' ') if replace_cntrl
      strs.rstrip
    end
    
    # create page image
    # This method does NOT render image like confermed PDF reader.
    # Just concat images.
    def to_image
      data = images.collect{|img|img.get_image}
      case data.size
      when 0 then nil
      when 1 then data[0]
      else
        data
        #raise NotImplementedError, 'multiple images'
        #s = self.stream
      end
    end
    
    private
    
    def ops
      # cache ops
      @ops ||= @op_parser.parse(self.stream)
    end
    
    def get_string_boxes
      fonts = self.resources[:Font]
      font = nil
      order = 0
      section = -1
      boxes = []
      ps = @op_parser
      ps.clear_handler
      ps.add_handler :BT, proc {|gs, ts, args|
        section += 1
        true
      }
      ps.add_handler :Tf, proc {|gs, ts, f, fs|
        font = fonts.fetch(f)
        font = font.data if font.kind_of?(Ref)
        [font, fs]
      }
      ps.add_handler :Tj, proc {|gs, ts, str|
        str = font.decode(str)
        boxes.push(StringBox.new(str, order, section, gs))
        order += 1
        false
      }
      ps.add_handler :TJ, proc {|gs, ts, array|
        array = array.collect{|item| item.kind_of?(String) ? font.decode(item) : item}
        boxes.push(StringBox.new(array, order, section, gs))
        order += 1
        false
      }
      ps.exec(ops)
      ps.clear_handler
      boxes
    end
    
    # 
    # Container which represents string and its bounding box.
    # 
    # A box is represented by affine matrix rather than homography matrix,
    # because PDF spec does not confirm such a transformation.
    # Shear (aka. skew) and non-isometric scaling are not considered now; 
    # i.e. scaling is considered as scalar value which is a coefficient of 
    # rotation matrix, and rotation is computed with atan2 of m00 (row/line) and m10.
    # 
    # If either shear or reflection is obserbed, this box is treated as "isolated"
    # from any other boxes (see codes of Page#text).
    # 
    # WARN: In this implementation, some superscripts and subscripts cause
    #       trespass on other lines.
    # 
    # - how to compute affine transformation:
    #   1. abnormal
    #     abs(m00) < epsilon && abs(m01) < epsilon
    #   2. shear
    #     epsilon < abs(m01 + m10)
    #   3. reflection
    #     sign(m00) != sign(m11)
    #     consider only x and y axis reflection
    #     (other axis reflection is detected as shear)
    #   4. rotation
    #     atan2(m10, m00)
    #   5. scaling
    #     a. if m00 < epsilon
    #       m10 / sin(rotation_angle)
    #     b. else
    #       m00 / cos(rotation_angle)
    # 
    # Note: According to the PDF spec, angle is *clockwise*.
    #       Then, rotation matrics is:
    #       [ [ cos   sin ]
    #         [ -sin  cos ] ]
    #
    class StringBox
      
      attr_reader :x, :y, :angle
      attr_reader :height, :section, :order
      cattr_accessor :epsilon, :margin_h, :margin_v, :line_height
      
      def initialize(str_or_array, order, section, gs)
        @array = if str_or_array.kind_of?(String)
        then str_or_array.chars
        else str_or_array.collect{|item| item.kind_of?(String) ? item.chars : item / 1000.0}.flatten
        end
        @order = order
        @section = section
        @gs = gs
        @tmp_mat = Utils::Mat3.new
        @product = gs.ts.tm * gs.ctm
        @vertical_font = @gs.ts.font.vertical?
        
        @x = @product.tx
        @y = @product.ty
        
        # compute @height; measured in accordance with a perpendicular of baseline
        a = precise_angle
        fs = @gs.ts.fs
        if a.nan?
          @angle = Float::NAN
          @height = fs
        elsif h?(a)
          @angle = 0
          @height = fs * @product.m00
        else
          cos, sin = Math.method(:cos), Math.method(:sin)
          vec2, mat2 = Utils::Vec2.method(:new), Utils::Mat2.method(:new)
          @angle = v?(a) && @vertical_font ? 0 : (a * 100).round
          rot = @rot_mat = mat2.(cos.(a), sin.(a), -sin.(a), cos.(a)) # see note in above comment
          if @vertical_font
            a2 = a - Math::PI / 2 # deny vertical modification of self#precise_angle
            c, s = cos.(a2), sin.(a2)
            rot = mat2.(c, s, -s, c)
          else
            c, s = cos.(a), sin.(a)
          end
          factor = zero?(@product.m00) ? @product.m10 / s : @product.m00 / c
          vec = vec2.(0, fs * factor)
          x1, y1 = (rot * vec).to_a
          @height = Math.sqrt(x1 * x1 + y1 * y1)
          @y -= height if @vertical_font
        end
        @space_width = @gs.ts.font.width(' ') * @height
        glyph_points
      end
      
      def x=(v); @x = v.to_f end
      def y=(v); @y = v.to_f end
      
      def intersect?(other)
        raise 'must not happen' if self.angle != other.angle
        sx0, sy0, sx1, sy1 = self.rectangle
        ox0, oy0, ox1, oy1 = other.rectangle
        sx0 <= ox1 && ox0 <= sx1 && sy0 <= oy1 && oy0 <= sy1
      end
      
      def join(other)
        raise 'must not happen' if self.angle != other.angle
        gp1 = self.glyph_points.dup
        gp2 = other.glyph_points.dup
        return self if gp2.empty?
        return other if gp1.empty?
        #points = prc.call(gp1 + gp2)#.sort_by{|pt| pt[1][0]}.sort_by.with_index{|pt, i| [pt[1][1], i]}
        points = (gp1 + gp2).sort{|a, b| pt1, pt2 = a[1], b[1]; dx = pt1[0] - pt2[0]; zero?(dx) ? pt2[1] <=> pt1[1] : pt1[0] <=> pt2[0]}
        obj = gp1.size < gp2.size ? other : self
        obj.glyph_points = points
        obj.order = [self.order, other.order].min
        obj.height = [self.height, other.height].max
        obj
      end
      
      def origin
        [@x, @y].collect(&:round)
      end
      
      # [ left_bottom_x, left_bottom_y, right_top_x, right_top_y ]
      def rectangle
        x0, y0 = @x, @y
        w, h = self.box_size
        if @rot_mat
          vec = @rot_mat * Utils::Vec2.new(w, h)
          w, h = vec.to_a
        end
        x1 = x0 + w
        y1 = y0 + h
        x0, x1 = [x0, x1].minmax
        y0, y1 = [y0, y1].minmax
        mw, mh = w * @@margin_h, h * @@margin_v
        x0 -= mw; x1 += mw
        y0 -= mh; y1 += mh
        [x0, y0, x1, y1]
      end
      
      def box_size
        return [@width, height] if @width
        points = glyph_points.dup
        last_point = points.pop
        @width = points.inject(0){|acc, array| acc += array[3]}
        @width += last_point[2] if last_point # glyph_points may be empty
        [@width, height]
      end
      
      def same_line?(other)
        return false if self.angle != other.angle
        a = precise_angle
        case
        when h?(a) then zero?(self.y - other.y)
        when v?(a) then zero?(self.x - other.x)
        else
          dx, dy = self.x - other.x, self.y - other.y
          h?(a - Math.atan2(dy, dx))
        end
      end
      
      def neighbor?(*boxes)
        boxes = boxes.flatten.select{|box| box.angle == self.angle}
        return false if boxes.empty?
        a = precise_angle
        case
        when h?(a)
          tmp = self.y
          dy = height * @@line_height
          ret = boxes.any? do |box|
            self.y = tmp - dy
            next true if intersect?(box)
            self.y = tmp + dy
            next true if intersect?(box)
          end
          self.y = tmp
          ret
        when v?(a)
          tmp = self.x
          dx = height * @@line_height
          ret = boxes.any? do |box|
            self.x = tmp - dx
            next true if intersect?(box)
            self.x = tmp + dx
            next true if intersect?(box)
          end
          self.x = tmp
          ret
        else
          tmp_x, tmp_y = self.x, self.y
          d = height * @@line_height
          ret = boxes.any? do |box|
            self.x = tmp_x - d
            self.y = tmp_y - d
            next true if intersected?(box)
            self.x = tmp_x + d
            self.y = tmp_y + d
            next true if intersected?(box)
          end
          self.x, self.y = tmp_x, tmp_y
          ret
        end
      end
      
      # If self is indented, return positive number.
      # Otherwise (i.e. unindented) return negative number.
      def indent_delta(other)
        raise 'must not happen' if self.angle != other.angle
        a = precise_angle
        case
        when h?(a) then self.x - other.x
        when v?(a) then other.y - self.y
        else
          dx, dy = self.x - other.x, self.y - other.y
          Math.sqrt(dx * dx, dy * dy)
        end
      end
      
      def to_s
        # any ceiling or flooring is heuristic
        w = @space_width.ceil
        w = (height / 3).floor if w.zero?
        return glyph_points.collect(&:first).join if w.zero?
        glyph_points.collect {|char, start, w0, w1|
          delta = (w1 - w0).ceil   # space to next character
          space_count = (delta / w).floor
          space_count -= 1 if char == ' '
          next char if space_count <= 0
          #spacer = space_count < 4 ? ' ' * space_count : "\t"
          spacer = space_count < 4 ? ' ' : "\t"
          next [char, spacer]
        }.flatten.join
      end
      
      alias :to_str :to_s
      
      def inspect
        '"' + to_s + '"'
      end
      
      def pretty_print(q)
        q.text(inspect)
      end
      
      def hash
        self.object_id
      end
      
      alias :eql? :equal?
      alias :== :equal?
      
      protected
      
      attr_writer :height, :order
      
      def glyph_points=(points)
        pts = points.dup
        detect_width!(pts)
        last_pt = pts.pop
        @width = pts.inject(0){|acc, array| acc += array[3]}
        @width += last_pt[2] if last_pt
        @x = points.first[1][0] unless points.empty?
        @glyph_points = points
      end
      
      # [ [ char, start_point, char_width, width ], ... ]
      def glyph_points
        return @glyph_points if @glyph_points
        
        ctm = @gs.ctm
        ts = @gs.ts
        tm = ts.tm# * @gs.ctm
        font = ts.font
        fs, c, w, h = ts.fs, ts.c, ts.w, ts.h
        j = 0.0
        trans = Utils::Mat3.new(fs * h, 0, 0, 0, fs, 0, 0, ts.rise, 1)
        points = @array.collect {|char|
          if char.kind_of?(Numeric)
            j = char
            if @vertical_font
              tx = 0.0
              ty = -j * fs
            else
              tx = -j * fs * h
              ty = 0.0
            end
            @tmp_mat.tx = tx
            @tmp_mat.ty = ty
            tm = @tmp_mat * tm
            next
          end
          #t = trans * tm * ctm
          #start = t.tx
          mat = tm * ctm
          trm = trans * mat
          start_x, start_y = trm.tx, trm.ty
          w0 = font.width(char)
          
          if @vertical_font
            tx_actual = tx = 0
            ty_actual = w0 * fs
            ty = w0 * fs + c + (char == ' ' ? w : 0)
          else
            tx_actual = w0 * fs * h   # actual width
            tx = (w0 * fs + c + (char == ' ' ? w : 0)) * h  # actual width + char/word space
            ty_actual = ty = 0
          end
          
          # actual glyph width
          @tmp_mat.tx = tx_actual; @tmp_mat.ty = ty_actual
          tm_actual = @tmp_mat * mat
          dx_actual = tm_actual.tx - start_x
          dy_actual = tm_actual.ty - start_y
          d_actual = Math.sqrt(dx_actual * dx_actual + dy_actual * dy_actual)
          
          # total width (actual width + char/word space)
          @tmp_mat.tx = tx; @tmp_mat.ty = ty
          mat2 = @tmp_mat * mat
          dx = mat2.tx - start_x
          dy = mat2.ty - start_y
          d = Math.sqrt(dx * dx + dy * dy)
          
          # update text matrics
          tm = @tmp_mat * tm
          [char, [start_x, start_y], d_actual, d]
        }.compact
        ts.tm = tm
        self.glyph_points = points
      end
      
      @@epsilon = 0.001
      @@margin_h = 0.01
      @@margin_v = 0.0
      @@line_height = 0.5
      
      
      private
      
      def h?(radian)
        radian = radian.abs
        radian -= Math::PI * 2 while 3 < radian
        radian.abs < @@epsilon
      end
      
      def v?(radian)
        radian = radian.abs
        radian -= Math::PI * 2 while 3 < radian
        (radian.abs - Math::PI / 2).abs < @@epsilon
      end
      
      def zero?(r)
        r.abs < @@epsilon
      end
      
      def precise_angle
        return Float::NAN if transformed?
        pd = @product
        Math.atan2(pd.m10, pd.m00) + (@vertical_font ? Math::PI / 2 : 0)
      end
      
      def detect_width!(points)
        a = precise_angle
        case
        when h?(a)
          # 0 degree
          points.each_cons(2){|array1, array2| array1[3] = array2[1][0] - array1[1][0]}
        when v?(a)
          # 90 degree
          points.each_cons(2){|array1, array2| array1[3] = array2[1][1] - array1[1][1]}
        else
          points.each_cons(2) do |array1, array2|
            dx = array1[1][0] - array2[1][0]
            dy = array1[1][1] - array2[1][1]
            array1[3] = Math.sqrt(dx * dx + dy * dy)
          end
        end
        points
      end
      
      # detect abnormal matrics, shear and reflection
      # see above comments
      def transformed?
        return @transformed if @transformed
        pd = @product
        m00, m01, m10, m11, = %i{m00 m01 m10 m11}.collect{|sym| pd.send(sym)}
        abnormal = zero?(m00) && zero?(m01)
        shear = !zero?(m01 + m10)
        refl = (0.0 <= m00) != (0.0 <= m11) # check wheather sign is different
        @transformed = abnormal || shear || refl
      end
      
    end
    
  end
  
end
