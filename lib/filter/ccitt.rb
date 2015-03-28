# coding: utf-8

module PDF::Filter
  module Ccitt
    def self.decode(raw_bytes, params)
      k = params.nil? ? 0 : params[:K]
      k = 0 if k.nil?
      if k < 0
        decode_g4(raw_bytes, params)
      elsif 0 < k
        decode_g3_2d(raw_bytes, params)
      else
        decode_g3_1d(raw_bytes, params)
      end
    end
    
    
    private
    
    def self.decode_g3_1d(raw_bytes, params)
      NotImplementedError.new
    end
    
    def self.decode_g3_2d(raw_bytes, params)
      NotImplementedError.new
    end
    
    def self.decode_g4(raw_bytes, params)
      NotImplementedError.new
    end
    
  end
end
