module PDF
  
  class InvalidImageError < InvalidPdfError; end
  
  class Image < XObject
    def initialize(*args)
      super
      @colors = nil
      @color_type = nil
      @palette = nil
      @palette_count = nil
      @bpc = self[:BitsPerComponent] || 8
      @bpc = 1 if mask?
      @icc = nil  # icc profile stream object
      @intent = self[:Intent]
      
      cs = self[:ColorSpace]
      cs = cs[0] if (cs.kind_of?(Array) && cs.size == 1)
      case cs
      when :DeviceGray
        @colors = 1
        @color_type = :grayscale
      when :DeviceRGB
        @colors = 3
        @color_type = :rgb
      when :DeviceCMYK
        @colors = 4
        @color_type = :cmyk
      when Array#, PdfArray
        case cs[0]
        when :Indexed
          # spec p.156
          # [/Indexed base hival lookup]
          # base  : color space definition
          # hival : maximum valid index
          # lookup: palette entries
          @color_type = :palette
          base, hival, pal = cs[1..3]
          @palette = pal  # r g b r g b ... string/stream
          @palette_count = hival + 1
          @colors = case base
            when :DeviceGray then 1
            when :DeviceRGB  then 3
            when :DeviceCMYK then 4
            when Array
              # [/ICCBased stream]
              icc, icc_prof = base
              raise InvalidImageError, "invalid icc color type; #{icc_prof.inspect}" if icc != :ICCBased
              @icc = icc_prof
              icc_prof.fetch(:N)
            else nil
            end
        when :ICCBased
          # spec p.149-
          # [/ICCBased stream]
          @icc = cs[1]
          @colors = @icc.fetch(:N)
          @color_type = case @colors
            when 1 then :grayscale
            when 3 then :rgb
            when 4 then :cmyk
            else raise InvalidImageError, "invalid icc color type; #{@icc}"
            end
        else
          raise InvalidImageError, "unsupported color space #{cs.inspect}"
        end
      else
        raise InvalidImageError, "unsupported color space #{cs.inspect}"
      end
    end
    
    def width; self[:Width] end
    def height; self[:Height] end
    def bpp; @colors * @bpc end
    def colors; @colors end
    def color_type; @color_type end
    def mask?
      b = self[:ImageMask]
      b.nil? ? false : b
    end
    
    def get_image
      if @colors.nil? || @color_type.nil?
        raise InvalidImageError, 'num of colors or color type undefined'
      elsif @color_type == :palette && @palette.nil?
        raise InvalidImageError, 'palette entries not found'
      end
      
      # return jpeg image
      case @filters.last
      when :JBIG2Decode
        return 'jbig', decode_stream
      when :DCTDecode
        return 'jpg', decode_stream
      when :JPXDecode
        return 'jp2', decode_stream
      end
      
      # return png image
      return 'png', get_image_png
    end
    
    
    private
    
    def get_image_png
      png = Utils::Png.new
      png.width = width
      png.height = height
      png.bitdepth = @bpc
      ct = Utils::Png::ColorType
      png.colortype = case @color_type
        when :grayscale then ct::GrayScale
        when :rgb       then ct::TrueColor
        when :palette   then ct::IndexColor
        else
          ArgumentError.new("invalid color type #{@color_type}")
        end
      png.icc = @icc.decode_stream if @icc
      it = Utils::Png::Intent
      intent = case @intent
        when nil then nil
        when :AbsoluteColorimetric then it::Absolute
        when :RelativeColorimetric then it::Relative
        when :Saturation           then it::Saturation
        when :Perceptual           then it::Perceptual
        else
          ArgumentError.new("invalid intent #{@intent}")
        end
      png.intent = intent if intent
      png.palette = case @palette
        when String then @palette
        when Stream then @palette.decode_stream
        else nil
        end
      if @filters.last == :FlateDecode
        param = @decode_params.last
        pred = param ? param[:Predictor] : nil
        if param.nil?
          png.add_data(decode_stream)
        else
          flate = @filters.pop
          lp = @decode_params.pop
          if pred == 2
            # faster (3x) than png.add_data(decode_stream, false)
            png.add_data(Filter::Tiff.to_png_sub(decode_stream, width * @bpc * @colors / 8), true)
          else
            png.add_data(decode_stream, true)
          end
          @filters.push(flate)
          @decode_params.push(lp)
        end
      else
        png.add_data(decode_stream, false)
      end
      return png.get_image
    end
    
  end

end
