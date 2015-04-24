#! ruby

require 'pp'
require 'zlib'
require 'narray'
require_relative '../lib/yarp'
require_relative 'glyph/glyph'

raise 'released version of narray needed' if '0.7' <= NArray::NARRAY_VERSION

class NArray
  
  def _dump(limit)
    Marshal.dump(
      { :version => NArray::NARRAY_VERSION,
        :endian => NArray::ENDIAN,
        :typecode => self.typecode,
        :shape => self.shape,
        :data => self.to_s }
    )
  end
  
  def self._load(str)
    obj = Marshal.load(str)
    raise TypeError, 'narray version conflicted' if obj.fetch(:version) != NArray::NARRAY_VERSION
    na = NArray.to_na(obj.fetch(:data), obj.fetch(:typecode), *obj.fetch(:shape))
    obj.fetch(:endian) == NArray::ENDIAN ? na : na.swap_byte
  end
  
end

#pp open('arial.vec', 'rb:ASCII-8BIT'){|io| Marshal.load(io.read)}
#exit

if ARGV.empty?
  $stdout.sync = true
  arial = open('./vec/arial.vec', 'rb:ASCII-8BIT'){|io| Marshal.load(Zlib::Inflate.inflate(io.read))}
  io = open('arial2.txt', 'w:ASCII-8BIT')
  
  codes = [(0x20..0xd7ff), (0xf900..0xfffd)].collect(&:to_a).flatten
  #io.puts(['U+', *codes].join(','))
  arial.zip(codes).each do |vec1, u|
    puts u.to_s(16).rjust(4) if u % 0x1000 == 0
    
    #fields = Array.new(codes.size + 1, -1.0)
    fields = []
    #fields[0] = u
    
    if vec1[0,0,0].nan?
      #io.puts(fields.join(','))
      next
    end
    
    io.write([u].pack('U') + "(U+#{u.to_s(16).upcase.rjust(4,'0')})\t")
    
    arial.zip(codes).each do |vec2, i|
      next if vec2[0,0,0].nan?
      #if vec2[0,0,0].nan?
      #  fields.push('-')
      #  next
      #end
      
      d = vec1 - vec2
      fields.push([d.rms, i, [i].pack('U')])
    end
    
    #io.puts(fields.join(','))
    io.puts(fields.sort.take(10).collect{|rms, i, s| "#{i == u ? '*' : ' '}#{s}(#{rms.round(3).to_s.ljust(5,'0')})"}.join("\t"))
  end
  
  io.close
  exit
end

if ARGV.empty?
  arial = open('arial.vec', 'rb:ASCII-8BIT') {|io| Marshal.load(io.read)}.collect{|m| m.matrix.gaussian!; m}.sort_by{|m| m.unicode}
  tahoma = open('tahoma.vec', 'rb:ASCII-8BIT') {|io| Marshal.load(io.read)}.collect{|m| m.matrix.gaussian!; m}.sort_by{|m| m.unicode}
  #tahoma = open('sourcecodepro-regular.vec', 'rb:ASCII-8BIT') {|io| Marshal.load(io.read)}.collect{|m| m.matrix.gaussian!; m}.sort_by{|m| m.unicode}
  #arial = open('arial.vec', 'rb:ASCII-8BIT') {|io| Marshal.load(io.read)}.sort_by{|m| m.unicode}
  #tahoma = open('tahoma.vec', 'rb:ASCII-8BIT') {|io| Marshal.load(io.read)}.sort_by{|m| m.unicode}
  raise "a" if arial.zip(tahoma).any?{|a, t| a.unicode.nil? || a.unicode != t.unicode}
  
  $stdout.sync = $stderr.sync = true
  
  puts 'start learning...'
  penalty = 1.0
  sigma1 = 0.8
  sigma2 = 0.5
  dp = 0.1
  ds = sigma2 / 10
  while 0 <= penalty
    ranks = arial.collect do |a|
      am = a.matrix
      [a.unicode, tahoma.collect{|t| [t.unicode, am.dot(t.matrix, penalty)]}.collect{|uni, mat| [uni, mat.inject(&:+)]}.sort_by{|uni, ft| -ft}.collect{|uni, ft| uni}]
    end
    puts '-' * 80
    puts "| penalty: #{penalty}"
    puts "| sigma1: #{sigma1}"
    puts "| sigma2: #{sigma2}"
    puts "| success(10/5): #{ranks.count{|ary|ary[1].take(10).include?(ary[0])}}/#{ranks.count{|ary|ary[1].take(5).include?(ary[0])}}"
    puts "| average rank: #{ranks.inject(0){|acc,ary|acc+ary[1].index(ary[0])+1} / ranks.size.to_f}"
    ranks = ranks.collect{|ary| [ary[1].index(ary[0]) + 1, ary[0]]}
    ranks = ranks.group_by{|r|r[0]}
    puts "| ranks:"
    ranks.keys.sort.each do |key|
      puts "|> #{key} : #{ranks[key].collect{|_,n| n.chr}.join(' ')}"
    end
    penalty -= dp
  end
  
  #while 0 < sigma2
  #  arial = open('arial.vec', 'rb:ASCII-8BIT') {|io| Marshal.load(io.read)}.collect{|m| m.matrix.gaussian!(sigma1, sigma2, 5); m}.sort_by{|m| m.unicode}
  #  tahoma = open('tahoma.vec', 'rb:ASCII-8BIT') {|io| Marshal.load(io.read)}.collect{|m| m.matrix.gaussian!(sigma1, sigma2, 5); m}.sort_by{|m| m.unicode}
  #  
  #  ranks = arial.collect do |a|
  #    am = a.matrix
  #    [a.unicode, tahoma.collect{|t| [t.unicode, am.dot(t.matrix, penalty)]}.collect{|uni, mat| [uni, mat.inject(&:+)]}.sort_by{|uni, ft| -ft}.collect{|uni, ft| uni}]
  #  end
  #  puts '-' * 80
  #  puts "| penalty: #{penalty}"
  #  puts "| sigma1: #{sigma1}"
  #  puts "| sigma2: #{sigma2}"
  #  puts "| success(10/5): #{ranks.count{|ary|ary[1].take(10).include?(ary[0])}}/#{ranks.count{|ary|ary[1].take(5).include?(ary[0])}}"
  #  puts "| average rank: #{ranks.inject(0){|acc,ary|acc+ary[1].index(ary[0])+1} / ranks.size.to_f}"
  #  ranks = ranks.collect{|ary| [ary[1].index(ary[0]) + 1, ary[0]]}
  #  ranks = ranks.group_by{|r|r[0]}
  #  puts "| ranks:"
  #  ranks.keys.sort.each do |key|
  #    puts "|> #{key} : #{ranks[key].collect{|_,n| n.chr}.join(' ')}"
  #  end
  #  sigma2 -= ds
  #end
  
  puts 'end learning...'
  #puts penalty
  exit
end

PI = Math::PI
F = YARP::Utils::Font
CODES = [(0x20..0xd7ff), (0xf900..0xfffd)].collect(&:to_a).flatten.collect{|n| [n].pack('n')}

TYPE = NArray::SFLOAT
SHAPE = [8, 8, 8] # vec, x, y

def create_matrices(font)
  cmap = font.get_cmaps.find{|cmap| cmap.format == 4}
  raise ArgumentError, 'cmap (format 4) not found' unless cmap
  
  theta0 = case font
  when F::PsFont then raise 'PsFont'
  when F::OpenType then -PI / 2
  when F::TrueType then PI / 2
  else raise 'must not happen'
  end
  
  hhea = font[:hhea]
  ascender, descender = hhea[:ascender], hhea[:descender]
  w = h = (ascender - descender).to_f
  
  invalid_mat = NArray.new(TYPE, *SHAPE).fill(Float::NAN)
  gids = CODES.collect{|code| cmap.code2gid[code]}
  gids.collect do |gid|
    
    # mat:
    #   |y----------------------|
    #   |38 39 3a 3b 3c 3d 3e 3f|
    #   |30 31 32 33 34 35 36 37|
    #   |28 29 2a 2b 2c 2d 2e 2f|
    #   |20 21 22 23 24 25 26 27|
    #   |18 19 1a 1b 1c 1d 1e 1f|
    #   |10 11 12 13 14 15 16 17|
    #   | 8  9  a  b  c  d  e  f|
    #  x| 0  1  2  3  4  5  6  7|
    #   |-----------------------|
    # Each element is 8-dims normal vector of coutours.
    # The direction of normal vector is in-to-out, i.e. right side of contour in PostScript font,
    # and left hand side of contour in TrueType font.
    # The norm of normal vector is the length of the line in the box.
    
    next invalid_mat if (gid.nil? || gid == 0)
    
    glyph = Glyph.new(font, gid)
    next invalid_mat unless glyph.valid?
    
    mat = NArray.new(TYPE, *SHAPE)
    vec_size = mat.shape.first
    
    xmin, ymin = glyph.xmin, glyph.ymin
    xmax, ymax = glyph.xmax, glyph.ymax
    points = glyph.coordinates.collect{|x1, y1, _| [x1.to_f, y1.to_f]}
    
    # normalize scale
    points.collect!{|x1, y1| [x1 - xmin, y1]} if xmin < 0
    points.collect!{|x1, y1| [x1, y1 - descender]}
    ymin = points.collect(&:last).min
    points.collect!{|x1, y1| [x1, y1 - ymin]} if ymin < 0
    x_norm, y_norm = [w, *points.collect(&:first)].max, [h, *points.collect(&:last)].max
    points.collect!{|x1, y1| [x1 / x_norm * 8.0, y1 / y_norm * 8.0]}
    unless points.all?{|x1, y1| (0..8).include?(x1) && (0..8).include?(y1)}
      p gid
      puts
      p %i{xmin ymin xmax ymax}.collect{|s|glyph.send(s)}
      puts
      pp glyph.coordinates
      puts
      pp points
      raise "a"
    end
    
    # create closed path
    idx0 = 0
    contours = glyph.eoc.collect{|idx| contour = points[idx0..idx] << points[idx0]; idx0 = idx + 1; contour}
    
    contours.each do |contour|
      contour.each_cons(2) do |pt0, pt1|
        x0, y0, x1, y1 = *pt0, *pt1
        theta = Math.atan2(y1 - y0, x1 - x0) + theta0
        if theta < 0
          theta += PI * 2
        elsif PI * 2 <= theta
          theta -= PI * 2
        end
        vec_idx = (theta / (PI * 2) * vec_size).round % vec_size
        
        x0, x1, y0, y1 = *[x0, x1].minmax, *[y0, y1].minmax
        dx0 = x1 - x0
        dy0 = y1 - y0
        norm = Math.sqrt(dx0 * dx0 + dy0 * dy0)
        
        grad = dx0 < 1e-5 ? nil : dy0 / dx0
        nords = case grad <=> 1e-5
        when nil  # grad == nil
          # vertical line
          (0..8).collect{|y| [x0, y.to_f]}
        when -1   # grad ≈ 0
          # horizontal line
          (0..8).collect{|x| [x.to_f, y0]}
        else
          y_inter = y0 - grad * x0
          (0..8).collect(&:to_f).each_with_object([]) do |r, acc|
            # intersection with horizontal line (x = r)
            acc << [r, grad * r + y_inter]
            # intersection with vertical line (y = r)
            acc << [(r - y_inter) / grad, r]
          end
        end
        
        nords = nords.select{|x, y| x0 <= x && x <= x1 && y0 <= y && y <= y1}
        nords.unshift(pt0); nords.push(pt1)
        nords.uniq.sort_by{|pt|pt[1]}.sort_by.with_index{|pt,i|[pt[0],i]}.each_cons(2) do |p0, p1|
          dx, dy = p0[0] - p1[0], p0[1] - p1[1]
          x, y = p0[0].floor, p0[1].floor
          x = 7 if x == 8
          y = 7 if y == 8
          norm = Math.hypot(dx, dy)
          begin
            mat[vec_idx, x, y] += norm / 8.0
          rescue IndexError
            p [vec_idx, x, y, p0, p1, gid]
            raise
          end
        end
      end
    end
    
    next mat
  end
end

until ARGV.empty?
  $stdout.sync = true
  font_path = ARGV.shift
  font_name = File.basename(font_path).sub(/\.[^\.]+$/, '')
  next unless /\.(ttf|otf|ttc)$/ =~ font_path
  
  font = YARP::Utils::Font.new(font_path)
  if font.kind_of?(Array)
    # ttc
    font.each.with_index(1) do |fnt, i|
      output_path = "./vec/#{font_name}_#{i}.vec"
      next if File.exist?(output_path)
      print "#{font_path} => #{output_path} ... "
      mats = create_matrices(fnt)
      size, zipsize = -1, -1
      open(output_path, 'wb:ASCII-8BIT') do |io|
        str = Marshal.dump(mats)
        size = str.bytesize
        zipsize = io.write(Zlib::Deflate.deflate(str))
      end
      puts "done (#{size/1024} KB / #{zipsize/1024} KB)"
    end
  else
    output_path = "./vec/#{font_name}.vec"
    next if File.exist?(output_path)
    print "#{font_path} => #{output_path} ... "
    mats = create_matrices(font)
    size, zipsize = -1, -1
    open(output_path, 'wb:ASCII-8BIT') do |io|
      str = Marshal.dump(mats)
      size = str.bytesize
      zipsize = io.write(Zlib::Deflate.deflate(str))
    end
    puts "done (#{size/1024} KB / #{zipsize/1024} KB)"
  end
  
end
