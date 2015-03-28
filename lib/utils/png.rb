# coding: utf-8

require 'zlib'

module PDF::Utils
  # create png image
  class Png
  
  # not implemented features:
  #   tRNS
  #   sBIT
  #   bKGD
  #   hIST
  #   pHYs
  #   sPLT
  #   tIME
    
    module ColorType
      GrayScale      = 0
      TrueColor      = 2
      IndexColor     = 3
      GrayScaleAlpha = 4
      TrueColorAlpha = 6
      
      # abbr
      G              = 0
      T              = 2
      I              = 3
      GA             = 4
      TA             = 6
    end
    
    module Intent
      Perceptual = 0
      Relative   = 1
      Saturation = 2
      Absolute   = 3
    end
    
    module DefaultValue
      Gamma = 45455
      CHRM = [
        31270, 32900, 64000, 33000,
        30000, 60000, 15000,  6000
      ]
    end
    
    attr_accessor :width, :height, :bitdepth, :colortype  # IHDR
    attr_accessor :intent
    
    def initialize
      # IHDR
      @width = 1
      @height = 1
      @bitdepth = 8
      @colortype = ColorType::TrueColor
      @palette = nil  # PLTE
      @data = []      # IDAT
      @chrm = nil     # cHRM
      @gamma = nil    # gAMA
      @icc = nil      # iCCP
      @intent = nil   # sRGB
      @texts = {}     # zTxt
    end
    
    def bits_per_pixel
      @bitdepth * colors_per_pixel
    end
    
    def colors_per_pixel
      case @colortype
      when ColorType::G   then 1
      when ColorType::T   then 3
      when ColorType::I   then 1
      when ColorType::GA  then 2
      when ColorType::TA  then 4
      else
        raise ArgumentError, "invalid color type #{@colortype}"
      end
    end
    
    def get_image
      # Note:
      #   a. sRGB and iCCP should not coexist.
      #   b. When sRGB exists, gAMA and cHRM should be written with default value. (their values are defiend above)
      #   c. Plural tEXt, zTxt and iTxt entries are allowed.
      
      # check data exist
      raise ArgumentError, 'IDAT chunk does not exist' if @data.empty?
      
      # check bitdepth and colortype
      case @colortype
      when ColorType::GrayScale
        raise ArgumentError, "invalid bit depth #{@bitdepth}" unless [1, 2, 4, 8, 16].include?(@bitdepth)
      when ColorType::TrueColor
        raise ArgumentError, "invalid bit depth #{@bitdepth}" unless [8, 16].include?(@bitdepth)
      when ColorType::IndexColor
        raise ArgumentError, "invalid bit depth #{@bitdepth}" unless [1, 2, 4, 8].include?(@bitdepth)
        raise ArgumentError, "palette is not setten" if @palette.nil?
      when ColorType::GrayScaleAlpha
        raise ArgumentError, "invalid bit depth #{@bitdepth}" unless [8, 16].include?(@bitdepth)
      when ColorType::TrueColorAlpha
        raise ArgumentError, "invalid bit depth #{@bitdepth}" unless [8, 16].include?(@bitdepth)
      else
        raise ArgumentError, "invalid color type #{@colortype}"
      end
      
      buf = [137, 80, 78, 71, 13, 10, 26, 10].pack('C*')  # header
      buf << create_chunk('IHDR', [width, height, bitdepth, colortype, 0, 0, 0].pack('N2C5'))
      if @icc
        icc_prof = "ICC Profile\x00\x00"
        icc_prof << Zlib::Deflate.deflate(@icc, Zlib::BEST_COMPRESSION)
        buf << create_chunk('iCCP', icc_prof)
      elsif @intent
        buf << create_chunk('sRGB', [@intent].pack('C'))
        buf << create_chunk('gAMA', [DefaultValue::Gamma].pack('N'))
        buf << create_chunk('cHRM', DefaultValue::CHRM.pack('N8'))
      else
        buf << create_chunk('gAMA', [@gamma].pack('N')) if @gamma
        buf << create_chunk('cHRM', @chrm.pack('N8')) if @chrm
      end
      buf << create_chunk('PLTE', @palette.pack('C*')) if @palette
      
      bpp = bits_per_pixel
      @data.each do |data, compressed|
        if compressed
          buf << create_chunk('IDAT', data)
        else
          scanline_bits = @width * bpp
          scanline = scanline_bits / 8
          scanline += 1 if scanline_bits % 8 != 0
          pixels = scanline * @height
          s = data.bytesize
          raise ArgumentError, "invalid pixel count #{s}; expected #{pixels}" if s != pixels
          buf << create_chunk('IDAT', compress(data, scanline, @height))
        end
      end
      
      @texts.each do |key, val|
        key = key.gsub(/[^\x20-\x7e\xa1-\xff]/n, '')[0, 79]
        key = ' ' if key.empty?
        key << "\x00"
        key << Zlib::Deflate.deflate(val, Zlib::BEST_COMPRESSION)
        buf << create_chunk('zTXt', key)
      end
      buf << [0, 0x49454e44, 0xae426082].pack('N3') # IEND
      buf
    end
    
    def palette; @palette end
    def palette=(pal)
      case pal
      when nil
        @palette = nil
      when String
        pal = pal.unpack('C*')
        raise ArgumentError, "invalid palette size; multiple of 3 was expected, but given #{pal.size}" if pal.size % 3 != 0
        @palette = pal
      when Array
        pal = pal.dup.flatten
        raise ArgumentError, "invalid palette size; multiple of 3 was expected, but given #{pal.size}" if pal.size % 3 != 0
        @palette = pal
      else
        raise ArgumentError, "expected string or array; given #{pal.class}"
      end
    end
    
    def add_data(data, compressed = false)
      @data << [data, compressed]
    end
    
    def cHRM; @chrm end
    def cHRM=(array)
      raise ArgumentError, "expected 8 item array" if array.size != 8
      @chrm = array.collect{|i|i.to_i}
    end
    
    def gamma; @gamma end
    def gamma=(g)
      # check wheather g is float
      g *= 100000 if g < 1
      @gamma = g.to_i
    end
    
    def icc=(profile); @icc = profile end
    
    def add_text(keyword, text)
      key = keyword.to_s.b
      @texts[key] = text
    end
    
    
    private
    
    def create_chunk(chunk_name, chunk_data)
      size = [chunk_data.bytesize].pack('N')
      data = chunk_name + chunk_data
      crc = Zlib.crc32(data)
      buf = size + data
      buf << [crc].pack('N')
      buf
    end
    
    def compress(data, row_bytes, height)
      lines = []
      height.times do |y|
        lines.push("\x00" + data[y * row_bytes, row_bytes])
      end
      Zlib::Deflate.deflate(lines.join, Zlib::BEST_COMPRESSION)
      #Zlib::Deflate.deflate(lines.join, Zlib::NO_COMPRESSION)
    end
    
  end
end
