#! ruby

require 'pp'
require 'narray'
require_relative '../lib/yarp'
require_relative 'glyph/glyph'


class Mat64 < Array
  
  VEC_SIZE = 8
  
  attr_reader :matrix
  
  def initialize(lazy=false)
    #super(64){ NVector.float(VEC_SIZE) }
    lazy ? super(64, nil) : super(64){ NArray.float(VEC_SIZE) }
    #super(64){ NArray.float(VEC_SIZE) }
    #super(64){ Array.new(VEC_SIZE, 0) }
    #64.times{|i| self[i][true] = Float::NAN}
  end
  
  #def *(other)
  #  raise TypeError unless other.kind_of?(self.class)
  #  mat = self.class.new
  #  #zero_vec = NVector.float(VEC_SIZE)
  #  #64.times {|i| mat[i] = self[i] * other[i]}
  #  64.times do |i|
  #    #mat[i] = self[i].zip(other[i]).collect{|a, b| a == 0.0 ? (-b * 0.01) : b == 0.0 ? (-a * 0.01) : a * b}.inject(&:+)
  #    mat[i] = self[i].zip(other[i]).collect{|a, b| a * b}.inject(&:+)
  #  end
  #  mat
  #end
  
  def dot(other, penalty)
    raise TypeError unless other.kind_of?(self.class)
    mat = self.class.new(true)
    if penalty.zero?
      64.times {|i| mat[i] = (self[i] * other[i]).sum}
    else
      64.times do |i|
        pen1 = self[i].eq(0.0) * other[i]
        pen2 = other[i].eq(0.0) * self[i]
        penalty_vector = (pen1 + pen2) * (-penalty)
        mat[i] = (self[i] * other[i] + penalty_vector).sum
        #mat[i] = self[i].zip(other[i]).collect{|a, b| a == 0.0 ? (-b * penalty) : b == 0.0 ? (-a * penalty) : a * b}.inject(&:+)
      end
    end
    mat
  end
  
  #GAUSIAN = NMatrix[
  #  [1.0/256,  4.0/256,  6.0/256,  4.0/256, 1.0/256],
  #  [4.0/256, 16.0/256, 24.0/256, 16.0/256, 4.0/256],
  #  [6.0/256, 24.0/256, 36.0/256, 24.0/256, 6.0/256],
  #  [4.0/256, 16.0/256, 24.0/256, 16.0/256, 4.0/256],
  #  [1.0/256,  4.0/256,  6.0/256,  4.0/256, 1.0/256],
  #]
  
  def gaussian!(sigma1=0.8, sigma2=0.5, size=3)
    size = size.to_i
    size -= 1 if size.odd?
    size /= 2
    ss = sigma1.to_f * sigma1
    ss2 = sigma2.to_f * sigma2
    cf = 1.0 / Math.sqrt(2 * Math::PI * ss)
    cf2 = 1.0 / (2 * Math::PI * ss2)
    g = {}; g2 = {}
    gauss = Proc.new{|d| g[d] ? g[d] : (g[d] = cf * Math.exp(-d * d/(2 * ss)))}
    gauss2 = Proc.new{|di, dj| g2[[di,dj]] ? g2[[di,dj]] : (g2[[di,dj]] = cf2 * Math.exp(-(di * di + dj * dj)/(2 * ss2)))}
    
    vectors = self.collect.with_index do |vec, i|
      #vec
      next vec if vec.eq(0.0).all?
      s0 = (vec * vec).sum
      vec0 = NArray.float(VEC_SIZE)
      (-size..size).each do |di| (-size..size).each do |dj|
        d0 = (i % 8) + di; d1 = i + dj * 8
        next if (d0 < 0 || 7 < d0)
        next if (d1 < 0 || 63 < d1)
        vec0 += self[i + di + dj * 8] * gauss2.call(di, dj)
      end end
      s1 = (vec0 * vec0).sum
      s1 == 0.0 ? vec0 : (vec0 / s1 * s0)
    end
    
    #63.times{|i|self[i] = vectors[i]}
    
    self.collect!.with_index do |_, i|
      vec = vectors[i]
      next vec if vec.eq(0.0).all?
      s0 = (vec * vec).sum
      vec0 = NArray.float(VEC_SIZE + size * 2)
      VEC_SIZE.times do |i|
        v = vec[i]
        next if v == 0.0
        (-size..size).each {|d| vec0[i + size + d] += v * gauss.call(d)}
        #vec0[i - 2] += v * 0.06
        #vec0[i - 1] += v * 0.24
        #vec0[i    ] += v * 0.4
        #vec0[i + 1] += v * 0.24
        #vec0[i + 2] += v * 0.06
      end
      vec0 = vec0[size..-size-1]
      s1 = (vec0 * vec0).sum
      s1 == 0.0 ? vec0 : (vec0 / s1 * s0)
    end
  end
  
  def self.create_gaussian_kernel(sigma=1.0, size=5)
    raise TypeError, 'size must be odd integer' unless (size.kind_of?(Fixnum) && size.odd?)
    g = NMatrix.float(size, size)
    sigma = sigma.to_f
    ss = sigma * sigma
    center = (size - 1) / 2
    cf = 1.0 / (2 * Math::PI * ss)
    sum = 0.0
    size.times do |i| size.times do |j|
      x = i - center; y = j - center
      sum += g[i,j] = cf * Math.exp(-(x * x + y * y) / (2 * ss))
    end end
    g / sum
  end
  
  def marshal_dump
    self.collect{|vec| vec.to_a}
  end
  
  def marshal_load(obj)
    #64.times {|i| self[i] = NVector.to_na(obj.fetch(i))}
    64.times {|i| self[i] = NArray.to_na(obj.fetch(i))}
    #64.times {|i| self[i] = obj.fetch(i))}
  end
  
end

#class Learner
#  
#  def self.create_matrix_ft_vector(mat1, mat2)
#    
#    
#    
#  end
#  
#end

class GlyphMetrics
  
  attr_reader :fontname, :unicode, :gid, :matrix
  
  def initialize(fontname, unicode, gid, matrix)
    @fontname = fontname
    @unicode = unicode
    @gid = gid
    @matrix = matrix
  end
  
  #def confidence(other)
  #  raise TypeError unless other.kind_of?(self.class)
  #  
  #  # 1. extract vector(s)/vector(s) features (e.g. dot production)
  #  Learner
  #  
  #  # 2. extract matrix/matrix features (e.g. sum of elements)
  #  
  #  
  #end
  
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

F = YARP::Utils::Font
VEC_SIZE = Mat64::VEC_SIZE
until ARGV.empty?
  font_path = ARGV.shift
  font_name = File.basename(font_path).sub(/\.[^\.]+$/, '')
  
  font = YARP::Utils::Font.new(font_path)
  cmap = font.get_cmaps.find{|cmap| cmap.format == 4}
  raise ArgumentError, 'cmap (format 4) not found' unless cmap
  theta0 = case font
  when F::CFF, F::OpenType, F::PsFont then -Math::PI / 2
  when F::TrueType then Math::PI / 2
  else raise 'must not happen'
  end
  
  codes = [0x21..0x7e, 0xa1..0xff].collect{|xs| xs.collect{|x| [x].pack('n')}}.flatten
  hhea = font[:hhea]
  ascender, descender = hhea[:ascender], hhea[:descender]
  w = h = (ascender - descender).to_f
  
  matrices = cmap.code2gid.values_at(*codes).collect do |gid|
    glyph = Glyph.new(font, gid)
    next unless glyph.valid?
    xmin, ymin = glyph.xmin, glyph.ymin
    xmax, ymax = glyph.xmax, glyph.ymax
    points = glyph.coordinates.collect{|x1, y1, _| [x1.to_f, y1.to_f]}
    
    # normalize scale
    points.collect!{|x1, y1| [x1 - xmin, y1]} if xmin < 0
    points.collect!{|x1, y1| [x1, y1 - (ymin - descender)]} if ymin < descender
    x_norm, y_norm = [w, xmax - xmin].max, [h, ymax - ymin].max
    points.collect!{|x1, y1| [x1 / x_norm * 8, y1 / y_norm * 8]}
    idx0 = 0
    contours = glyph.eoc.collect{|idx| contour = points[idx0..idx] << points[idx0]; idx0 = idx + 1; contour}
    
    # mat64:
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
    #mat64 = Array.new(64){ NVector.float(16) }
    mat64 = Mat64.new
    
    contours.each do |contour|
      contour.each_cons(2) do |pt0, pt1|
        x0, y0, x1, y1 = *pt0, *pt1
        theta = Math.atan2(y1 - y0, x1 - x0) + theta0
        if theta < 0
          theta += Math::PI * 2
        elsif Math::PI * 2 <= theta
          theta -= Math::PI * 2
        end
        vec_idx = (theta / (Math::PI * 2) * VEC_SIZE).round % VEC_SIZE
        
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
          norm = Math.sqrt(dx * dx + dy * dy)
          raise [norm, dx, dy, p0, p1].to_s if 8 < norm
          x, y = p0[0].floor, p0[1].floor
          x = 7 if x == 8
          y = 7 if y == 8
          mat64[x + y * 8][vec_idx] += norm / 8
        end
      end
    end
    
    [gid, mat64]
  end
  
  glyphs = codes.zip(matrices).collect{|code, (gid, mat)| GlyphMetrics.new(font_name, code.unpack('n')[0], gid, mat)}
  output_path = "#{font_name}.vec"
  puts "#{font_path} => ./#{output_path}"
  open(output_path, 'wb:ASCII-8BIT') {|io| io.write(Marshal.dump(glyphs))}
  
end
