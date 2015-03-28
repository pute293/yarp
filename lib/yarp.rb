#! ruby
# coding: utf-8

# TODO
# 1. 各オブジェクトがパーサを保持しているのをどうにかできないか？
# 2. Adobe の Unicode 私用領域に対応する
# 
# Not Tested:
#   LZWDecoder
#   TIFFDecoder (bpp 1,2,4,16)
#   


raise LoadError, 'ruby version must be 2.0.0 or greater.' if RUBY_VERSION < '2.0.0'

module YARP
  
  class InvalidPdfError < StandardError; end
  
  def self.Config
    @@config
  end
  
  def self.update_font
    Utils::Font::FontCache.update
  end
  
  def self.warn(*args)
    super if warning?
  end
  
  @@warning = $DEBUG ? true : false
  
  def self.warning; @@warning end
  
  def self.warning?; @@warning end
  
  def self.warning=(bool)
    @@warning = !!bool
  end
  
end

require_relative 'yarp/yarp'
require_relative 'utils/utils'
require_relative 'parser/parser'
require_relative 'filter/filter'
require_relative 'decrypt/decrypt'
require_relative 'object/object'
require_relative 'document'
require_relative 'yarp/cleanup'

if $0 ==  __FILE__
  require_relative 'yarp/repl'
end
