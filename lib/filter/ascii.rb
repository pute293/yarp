# coding: utf-8

module YARP::Filter
  module AsciiHex
    def self.decode(raw_bytes, *args)
      eod_idx = raw_bytes.include?(?>) ? raw_bytes.index(?>) : raw_bytes.bytesize
      data = raw_bytes[0..eod_idx-1].delete("\x00\x09\x0A\x0C\x0D\x20") # eliminate white-space
      data << '0' if data.size.odd?
      /\A[[:xdigit:]]+\z/ =~ data
      unless $&
        bytes = data.bytesize < 16 ? data : "#{data[0,8]} ... #{data[-8..-1]}"
        raise FilterError, "invalid bytes: #{bytes} (#{data.bytesize} bytes)"
      end
      data.scan(/../).collect{|x|x.to_i(16).chr}.join
    end
  end
  
  module Ascii85
    def self.decode(raw_bytes, *args)
      data = raw_bytes.delete("\x00\x09\x0A\x0C\x0D\x20") # eliminate white-space
      
      /\A(?:<~)?([\x21-\x75\x7a]+)(?:~>)?\z/n =~ data     # '!'..'u', 'z'
      unless $&
        bytes = data.bytesize < 16 ? data : "#{data[0,8]} ... #{data[-8..-1]}"
        raise FilterError, "invalid bytes: #{bytes} (#{data.bytesize} bytes)"
      end
      data = $1
      # v this code is faster than above (2x), without error checking
      #s = data.start_with?('<~') ? 2 : 0
      #e = data.end_with?('~>') ? -3 : -1
      #data = data[s..e] if (s == 2 || e == -3)
      pad = 5 - data.size % 5
      pad = 0 if pad == 5
      decode_impl(data)
    end
    
    
    private
    
    if YARP::NARRAY
    
      NUMS = NArray[[
        85 * 85 * 85 * 85,
        85 * 85 * 85,
        85 * 85,
        85,
        1
      ]]
      
      def self.decode_impl(data)
        data = data.gsub('z', '!!!!!')
        pad = 5 - data.size % 5
        pad = 0 if pad == 5
        data << 'u' * pad
        v = NArray.to_na(data, 'byte') - 0x21
        v = v.reshape(5, true) * NUMS
        v.sum(0).to_a.pack('N*')[0..-pad-1]
      end
    
    else
    
      NUMS = [
        85 * 85 * 85 * 85,
        85 * 85 * 85,
        85 * 85,
        85,
        1
      ]
      
      def self.decode_impl(data)
        pad = 0
        data.scan(/[\x21-\x75]{1,5}|\x7a/n).collect {|field|
          if field == 'z'
            0
          else
            if field.bytesize < 5
              pad = 5 - field.bytesize
              field << 'u' * pad
            end
            field.bytes.collect.with_index{|x,i|(x - 0x21) * NUMS[i]}.inject(&:+)
          end
        }.pack('N*')[0..-pad-1]
      end
    
    end
  end

end
