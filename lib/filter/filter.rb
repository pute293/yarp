# coding: utf-8

# introduce YARP::Filter::* modules
# They have method :decode

module YARP
  module Filter
    class FilterError < InvalidPdfError; end
  end
end

require_relative 'ascii'
require_relative 'lzw'
require_relative 'flate'
require_relative 'runlen'
require_relative 'ccitt'
require_relative 'jpeg'

# 1,2,4,16bpp-tiff and ccitt decoder are not implemented yet
