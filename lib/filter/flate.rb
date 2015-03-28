# coding: utf-8

require 'zlib'
require_relative 'predictor'

module PDF::Filter
  module Flate
    
    # zlib decoder with predictor
    def self.decode(raw_bytes, params)
      z = Zlib::Inflate.inflate(raw_bytes)
      if params.nil?
        z
      else
        Predictor.decode(z, params)
      end
    end
    
  end
end
