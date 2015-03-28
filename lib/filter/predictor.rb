# coding: utf-8

require_relative 'tiff'

module PDF::Filter
  module Predictor
    # PNG / TIFF Predictor
    # Note: PNG Filtering algorithm is done for each byte, regardless bit depth (BitsPerComponent).
    #       However in Sub, Average and Paeth algorithms use byte-per-pixel(bpp),
    #       and if bpp is less than 1 (eg. grayscale image) bpp is rounded up to 1.
    # Reference: http://www.w3.org/TR/PNG-Filters.html
    def self.decode(raw_bytes, params)
      pred    = params[:Predictor]  || 1
      return raw_bytes if pred == 1
      raise FilterError, "invalid predicator: #{pred}; expected 1, 2 or 10..15" unless [1, 2, 10, 11, 12, 13, 14, 15].include?(pred)
      colors  = params[:Colors]     || 1        # num of colors in a sample
      bpc     = params[:BitsPerComponent] || 8  # bit length of a color
      col     = params[:Columns]    || 1        # num of samples in a row
      
      bits_per_sample = colors * bpc
      bits_per_row = bits_per_sample * col
      bpp = bits_per_sample / 8   # bytes per sample
      bpp = 1 if bpp == 0
      bpr = bits_per_row / 8      # bytes per row
      bpr += 1 if bits_per_row % 8 != 0 # last one byte includes padding
      
      case pred
      when 2
        PDF::Filter::Tiff.decode(raw_bytes, params)
      when 10..15
        lines = raw_bytes.scan(/([\x00-\xff])([\x00-\xff]{#{bpr}})/n)
        above_line = [0] * bpr
        lines.collect{|pred, line|
          case pred.ord
          when 0
            # PNG None
            line
          when 1
            # PNG Sub
            line = line.unpack('c*')
            size = line.size
            line.unshift(*([0] * bpp))  # insert dummy
            size.times do |i|
              i += bpp  # access to real line position
              line[i] = (line[i] + line[i - bpp]) & 0xff
            end
            line.shift(bpp)   # remove dummy
            above_line = line
            line.pack('C*')
          when 2
            # PNG Up
            line = line.unpack('c*').zip(above_line).collect{|a,b|(a+b) & 0xff}
            above_line = line
            line.pack('C*')
          when 3
            # PNG Average
            line = line.unpack('c*')
            size = line.size
            line.unshift(*([0] * bpp))
            size.times do |i|
              i += bpp  # skip dummy sample
              left = line[i - bpp]
              above = above_line[i]
              av = (left + above) / 2   # floor((left + above) div 2)
              line[i] = (line[i] + av) & 0xff
            end
            line.shift(bpp)
            above_line = line
            line.pack('C*')
          when 4
            # PNG Paeth
            line = line.unpack('c*')
            size = line.size
            line.unshift(*([0] * bpp))
            size.times do |i|
              i += bpp
              left = line[i - bpp]
              above = above_line[i]
              left_above = above_line[i - bpp]
              pr = paeth(left, above, left_above)
              line[i] = (line[i] + pr) & 0xff
            end
            line.shift(bpp)
            above_line = line
            line.pack('C*')
          end
        }.join
      end
    end
    
    
    private
    
    def self.paeth(a, b, c)
      # a: left, b: above, c: upper-left
      p = a + b - c
      pa = (p - a).abs
      pb = (p - b).abs
      pc = (p - c).abs
      if pa <= pb && pa <= pc
        a
      elsif pb <= pc
        b
      else
        c
      end
    end
  end
end
