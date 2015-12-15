#! /usr/bin/env ruby

class Histgram
  
  def initialize(low, high, scale=10)
    @scale = scale = scale.to_i
    low = low.to_i
    high = high.to_i
    @lo = low
    @hi = high
    @low = low - low % scale
    @high = high + (high % scale == 0 ? 0 : (scale - high % scale))
    @data = Hash.new{|hash,key|hash[key.object_id] = [key, 0]}
  end
  
  def add(f, n=1)
    v = @data[f.to_f]
    v[1] += n if (@lo...@hi).include?(f)
  end
  
  def []=(f, n)
    v = @data[f.to_f]
    v[1] += n.to_i if (@lo...@hi).include?(f)
  end
  
  def to_s
    mgn = (Math.log10(@high) + 1).to_i
    s = @scale
    buf = '-' * 80
    buf << "\n"
    @low.step(@high, s) do |i|
      lo = i
      hi = i + s
      buf << i.to_s.rjust(mgn) + "-|\n"
      break if @high <= i
      num = 0
      @data.each do |k, v|
        f, n = v
        num += n if (lo...hi).include?(f)
      end
      buf << ' '.rjust(mgn) + ' +'
      if num == 0
        buf << " 0\n"
        next
      end
      buf << 1.upto(num).collect{|n| n % 5 == 0 ? '+' : '-'}.join
      buf << " #{num}\n"
    end
    buf << '-' * 80
    buf
  end
  
end
