# coding: utf-8
require 'zlib'

module YARP::Filter
  module Tiff
    
    # TIFF(v6) deferential algorithm
    # Reference: https://partners.adobe.com/public/developer/en/tiff/TIFF6.pdf
    def self.decode(raw_bytes, params)
      pred    = params[:Predictor]
      raise FilterError, "invalid predicator: #{pred}; exptected 2" if pred != 2
      colors  = params[:Colors]     || 1        # num of colors in a sample
      bpc     = params[:BitsPerComponent] || 8  # bit length of a color
      col     = params[:Columns]    || 1        # num of samples in a row
      
      case bpc
      when 1, 2, 4
        raise NotImplementedError, "TIFF image with bit depth per color #{bpc}"
        decode_bits(raw_bytes, colors, col, bpc)
      when 8
        decode_bytes(raw_bytes, colors, col, bpc)
      when 16
        raise NotImplementedError, "TIFF image with bit depth per color 16"
      else
        raise FilterError, "invalid BitPerComponent: #{bpc}; exptected 1, 2, 4, 8 or 16"
      end
    end
    
    # To inflated bytes add \x01 to head of each line
    # and deflate
    def self.to_png_sub(z, bytes_per_line)
      # v slower code (1.2x); because of String#scan
      #lines = Zlib::Inflate.inflate(z).scan(/[\x00-\xff]{#{bytes_per_line}}/n)
      #lines = lines.collect{|line|"\x01"+line}.join
      #Zlib::Deflate.deflate(lines)
      z = Zlib::Inflate.inflate(z)
      lines = [nil] * bytes_per_line
      height = z.bytesize / bytes_per_line
      height.times {|i| lines[i] = "\x01" + z[i*bytes_per_line, bytes_per_line]}
      Zlib::Deflate.deflate(lines.join)
    end
    
    
    private
    
    # bits tiff decoder
    def self.decode_bits(raw_bytes, colors, col, bpc)
      # broken?
      # bpc is 1, 2 or 4
      bits_per_sample = colors * bpc
      bits_per_row = bits_per_sample * col
      bpr = bits_per_row / 8      # bytes per row
      bpr += 1 if bits_per_row % 8 != 0 # last one byte includes padding
      mask = (1 << bpc) - 1
      
      lines = raw_bytes.scan(/[\x00-\xff]{#{bpr}}/n)
      prev_sample = [0] * colors
      lines.collect {|line|
        row_bits = line.unpack('B*')[0][0, bits_per_row].scan(/[01]{#{bits_per_sample}}/)
        row_bits.collect! do |samples|
          sample = samples.scan(/[01]{#{bpc}}/).collect{|b|b.to_i(2)}
          sample = sample.zip(prev_sample).collect{|cur, prev| (cur + prev) & mask}
          prev_sample = sample
          sample.pack('C*')
        end
        row_bits.join
      }.join
    end
    
    
    if YARP::NARRAY
    
      # bytes tiff decoder
      def self.decode_bytes(raw_bytes, colors, width, bpc)
        # bpc is 8 or 16
        # endianness ???
        bytes_per_color = bpc / 8
        bytes_per_sample = bytes_per_color * colors
        bytes_per_line = bytes_per_sample * width
        height = raw_bytes.bytesize / bytes_per_line
        type = bpc == 8 ? 'byte' : 'sint'
        
        v = NArray.to_na(raw_bytes, type, bytes_per_sample, width, height)  # [ [ [ ... colors ...] ... samples ... ] ... lines ... ]
        
        # faster way (transpose, diff, transpose)
        v = v.transpose(2, 1, 0)    # [ [ [ ... color_component_in_column ... ] ... columns ... ] ... ]
        bytes_per_sample.times do |c|
          1.upto(width-1) do |x|
            v[true, x, c] += v[true, x - 1, c]
          end
        end
        v = v.transpose(2, 1, 0)
        
        # v slower way (1.1x); because NArray#[true, x, true] is not so fast
        #1.upto(width - 1) do |x|
        #  v[true, x, true] += v[true, x - 1, true]
        #end
        
        # slower way; to_s is faster than flatten.to_a.pack('C*')
        # but 16 bpc ???
        #type = bpc == 8 ? 'C*' : 'v*'
        #v.flatten.to_a.pack(type)
        
        v.to_s
      end
    
    else
    
      # bytes tiff decoder
      def self.decode_bytes(raw_bytes, colors, width, bpc)
        # bpc is 8 or 16
        # endianness ???
        bytes_per_color = bpc / 8
        bytes_per_sample = bytes_per_color * colors
        bytes_per_line = bytes_per_sample * width
        mask = bpc == 8 ? 0xff : 0xffff
        type = bpc == 8 ? 'C*' : 'v*'
        
        lines = raw_bytes.scan(/[\x00-\xff]{#{bytes_per_line}}/n)
        lines.collect {|line|
          line = line.unpack(type)
          size = line.size
          line.unshift(*([0] * bytes_per_sample))
          size.times do |i|
            j = i + bytes_per_sample
            line[j] = (line[j] + line[i]) & mask
          end
          line.shift(bytes_per_sample)
          line.pack(type)
        }.join
      end
    
    end
    
  end
end
