require 'stringio'
require 'set'

module YARP
  
  class InvalidEncoding < InvalidPdfError; end
  class InvalidFontFormat < InvalidPdfError; end
  
  class Font < PdfObject
    class << self
      alias new_old new
      def new(parser, num, gen, data, enc, inst)
        args = [parser, num, gen, data, enc, inst]
        klass = case data[:Subtype]
          when :Type0 then Font0
          when :Type1, :MMType1, :TrueType
            Font1
          when :Type3
            #raise NotImplementedError, 'Type 3 font'
            Font3
          when :CIDFontType0, :CIDFontType2
            CIDFont
          else raise InvalidFontFormat, "unknown font type \"#{data[:Subtype]}\""
        end
        klass.new_old(*args)
      end
    end
    
    # control characters (except for white-spece)
    UnicodeCL = (0..0x1f).reject{|n| /[[:space:]]/ =~ n.chr}
    
    attr_reader :name
    
    def initialize(*args)
      super
      @cache_needed = true
      descend = descendant
      @descriptor = descriptor
      if @descriptor
        @name = @descriptor.fetch(:FontName).to_s.sub(/^\w{6}\+/, '')
        emb = @descriptor.find {|key, val| key.to_s.start_with?('FontFile')}
        @embedded = emb.nil? ? nil : emb[1].kind_of?(Ref) ? emb[1].data : emb[1]
      else
        raise InvalidFontFormat, 'FontDescriptor is not found.' unless @descriptor
        @name = (self[:BaseFont] || self[:Name]).to_s
        @embedded = nil
        warn 'Required entry /FontDescriptor was not found.'
      end
      
      enc = self[:Encoding]
      case enc
      when Stream
        # on type0
        # do this later
        @encoding = enc
        @diff = {}.freeze
      when PdfObject, Hash
        # on type1, mmtype1, truetype, type3
        base_enc = enc[:BaseEncoding]; base_enc = base_enc.data if base_enc.kind_of?(Ref)
        @encoding = base_enc || :StandardEncoding
        @diff = create_diff(enc[:Differences]).freeze
      when nil
        # on any type
        @encoding = :'Identity-H'
        @diff = {}.freeze
      else
        # on any type
        @encoding = enc.intern
        @diff = {}.freeze
      end
      
      @encoding = case @name
      when /Symbol/       then :SymbolEncoding
      when /ZapfDingbats/ then :ZapfDingbatsEncoding
      else @encoding
      end
      
      # @encoding           : (Symbol)  encoding name
      # @diff               : (Hash)    bytes => unicode; map bytes to unicode codepoints
      @umaps = []           # ([Hash])  bytes => unicode codepoint
      @width = Hash.new(0.0)# (Hash)    cid => int; width of each cid keyed glyph
      @default_width = 1.0  # (num)     default glyph width
      @embedded_font = nil  # (Utils::Font) embedded font object
      @installed_font = nil # (Utils::Font) installed font object
      @warned = {}          # (Symbol => bool) suppress warning if true
      
      # create umap array
      @umaps.push(create_umap(self[:ToUnicode].decode_stream)) if self[:ToUnicode]
      @umaps.push(@diff) if (@diff && !@diff.empty?)
      case @encoding
      when :StandardEncoding, :MacRomanEncoding, :WinAnsiEncoding, :PDFDocEncoding, :MacExpertEncoding, :SymbolEncoding, :ZapfDingbatsEncoding
        # predefined encoding
        @umaps.push(Utils::Encoding.const_get(@encoding))
      end
    end
    
    # convert raw bytes (given from Tj/TJ operator) to utf-8 encoded string
    def decode(bytes)
      unicodes = bytes_to_unicodes(bytes, @umaps)
      remove_surrogate(unicodes.compact).pack('U*')
    end
    
    # compute width of given strings
    def width(unichars)
      unichars.encode('UTF-8').chars.inject(0){|w, uni| w += @width[uni]}
    end
    
    def vertical?
      @encoding.to_s.end_with?('V')
    end
    
    def embedded?
      !!@embedded
    end
    
    private
    
    def warn(str)
      super("\"#{name}\": #{str}")
    end
    
    def warn_once(str, id)
      warn @warned[id] = str if (YARP.warning? && @warned[id].nil?)
    end
    
    def remove_surrogate(enum)
      enum.inject([]) do |acc, uni|
        hi = acc.last
        if (0xD800..0xDBFF).include?(hi) && (0xDC00..0xDFFF).include?(uni)
          acc.pop
          uni = 0x10000 + (hi - 0xD800) * 0x400 + (uni - 0xDC00)
        end
        acc << uni
      end
    end
    
    def extractable?
      !(@umaps.empty? || @umaps.all?{|map|map.empty?})
    end
    
    def descendant
      descend = self[:DescendantFonts]
      descend.kind_of?(Enumerable) ? descend.first : descend  # may be not array (it is bad manner)
    end
    
    def descriptor
      self[:FontDescriptor] || (descendant ? descendant[:FontDescriptor] : nil)
    end
    
    # convert encoded bytes (String) to unicode codepoint array
    def bytes_to_unicodes(bytes, umaps)
      raise NotImplementedError, 'must be overrided'
    end
    
    # convert array of cid to array of unicode codepoint
    #def cids_to_unichars(umap, *cids)
    #  cids.flatten.collect{|cid|umap[cid]}
    #end
    
    # convert array of unicode codepoint to array of cid
    # (inverse transformation of cids_to_unichars)
    #def unichars_to_cids(umap, unichars)
    #  codepoints = unichars.unpack('U*')
    #  codepoints.collect{|cp|umap.index[cp] || 0}
    #end
    
    # create embedded font object and corresponding installed font object
    def realize_embedded_font
      if embedded?
        @embedded_font ||= Utils::Font.new(@embedded.stream)
        @installed_font ||= Utils::Font.search(@embedded_font.fullname)
        @embedded_font.embedded = true
        [@embedded_font, @installed_font]
      else
        [nil, nil]
      end
    end
    
    def create_diff(array)
      hash = {}
      return hash if array.nil?
      diff = array.inject([]){|acc, cur| if cur.kind_of?(Integer) then acc << [cur] else acc.last << cur; acc end}
      names = Utils::Encoding::NameToUnicode
      diff.each do |array|
        idx = array.shift
        array.each_with_index do |sym,i|
          c = names[sym]
          if c.nil?
            c = 0xfffd
            if embedded?
              @embedded_font ||= Utils::Font.new(@embedded.stream)
              c = @embedded_font.name2gid(sym).first || c
            end
            warn "unknown glyph name \"#{sym}\" found, it will be replaced to U+#{'%04X'%c}"
          end
          hash[(idx+i).chr] = c
          # (idx+i).chr is safe because this method will be called from only initialization of simple font
        end
      end
      hash
    end
    
    def create_umap(stream)
      ps = Parser::PostScriptParser.new
      ps.resources[:CMap].clear
      ps.parse(stream)
      umap = ps.resources.fetch(:CMap)
      (umap.values.last[:'.unicodemap'] || {}).freeze
    end
    
    def create_cmap(stream)
      ps = Parser::PostScriptParser.new
      ps.resources[:CMap].clear
      ps.parse(stream)
      umap = ps.resources.fetch(:CMap)
      (umap.values.last[:'.cidmap'] || {}).freeze
    end
    
    # str --cmaps--> [any]
    def convert_with_cmap(str, cmaps, max_bytes: 4)
      r = StringIO.new(str, 'rb:ASCII-8BIT')
      cids = []
      code = ''
      until r.eof?
        code << r.read(1)
        raise InvalidEncoding, "\"#{name} (#{self.class})\": invalid bytes sequence #{code.bytes.collect{|x|'%02x' % x}.join(' ')}" if max_bytes < code.bytesize
        cid = cmaps.find{|cmap| tmp_cid = cmap[code]; tmp_cid ? (break tmp_cid) : false}
        next unless cid
        cids << cid
        code = ''
      end
      if code.bytesize == 1
        # /Width entry of embedded font dictionary may contains undefined GID in that font.
        cids << code[0].ord
      elsif !code.empty?
        raise InvalidEncoding, "\"#{name} (#{self.class})\": invalid bytes sequence #{code.bytes.collect{|x|'%02x' % x}.join(' ')}"
      end
      cids.flatten
    end
    
    # convert GIDs of embedded font to unicode codepoints
    def gids_to_unicode(embedded_gids, gidmap, truetype)
      cmaps = truetype.get_cmaps.select{|cmap| cmap.unicode_keyed?}
      # get GID assigned to space
      space_gid = cmaps.find do |cmap|
        fmt = case cmap.bytes
        when 1 then 'C'
        when 2 then 'n'
        when 4 then 'N'
        else next
        end
        gid = cmap.code2gid[[0x20].pack(fmt)]
        gid ? (break gid) : false
      end
      space_gid ||= 0
      
      # map GID to unicode value(s)
      tried_gid = Set.new
      to_unicode = lambda do |gid1|
        gid2 = gidmap[gid1]
        return 0x20 if gid2 == space_gid
        gid = gid2 || gid1
        code, num_bytes = cmaps.find {|cmap| key = cmap.code2gid.key(gid); key ? (break [key, cmap.bytes]) : false}
        if code
          fmt = case num_bytes
          when -1 then 'N*' # UVS
          when 1  then 'C'
          when 2  then 'n'
          when 4  then 'N'
          else raise 'must not happen'
          end
          # update gidmap
          gidmap[gid1] = gid1 unless gid2
          code.unpack(fmt)
        else
          # Glyph of corresponding GID is not included in Unicode Character Set.
          # If installed font is either TrueType or OpenType and has "GSUB" table,
          # the GID may be replaced to another GID which corresponding glyph is included in UCS.
          # If installed font is neither TrueType or OpenType, or does not have
          # "GSUB" table, return GIDs as unicode codepoint.
          return nil if tried_gid.include?(gid)
          tried_gid << gid
          replaced_gids = truetype.replace_gid(gid)
          replaced_gid, uni = replaced_gids.find{|rep_gid| u = to_unicode.call(rep_gid); u ? (break [rep_gid, u]) : false}
          if uni
            warn "GID #{gid} is not assigned to Unicode. It will be replaced to GID #{replaced_gid} (U+#{'%04X'%uni}) according to GSUB table."
            # update gidmap
            gidmap[gid1] = replaced_gid
            uni
          else
            # "GSUB" table dose not exist, or a glyph of gid1 does not included in given font.
            # The latter pattern means that PDF writing app have generated, moved or removed the glyph from original font.
            gid
          end
        end
      end
      embedded_gids.collect(&to_unicode).flatten
    end
    
  end
  
  
  # ========================================================================== #
  #                                                                            #
  # Composite Font                                                             #
  #                                                                            #
  # ========================================================================== #
  class Font0 < Font
    def initialize(*args)
      super
      descend = descendant
      info = descend.fetch(:CIDSystemInfo)
      ros = "#{info[:Registry]}-#{info[:Ordering]}"
      umap_file = YARP::Utils::Encoding.cid2unicode(ros)
      umap = create_umap(umap_file) if umap_file
      umap = nil if (umap.nil? || umap.empty?)
      @umaps.push(umap) if umap
      
      # create cmap
      @cmap = case @encoding
      when :StandardEncoding, :MacRomanEncoding, :WinAnsiEncoding, :MacExpertEncoding, :PDFDocEncoding, :SymbolEncoding
        # predifined encoding
        # must not happen
        nil
      when :'Identity-H', :'Identity-V'
        Hash.new {|hash, key| key.bytesize == 2 ? key : nil}
      when Stream 
        enc, @encoding = @encoding, :Custom
        create_cmap(enc.stream)
      else create_cmap(YARP::Utils::Encoding.code2cid(@encoding))
      end
      
      # create width array
      # each group (item) of /Width array is one in two formats below:
      # 1. n [ w0 w1 ... w_m ]  => n:w0, n+1:w1, ..., n+m:w_m
      # 2. n1 n2 w              => n1:w, n1+1:w, ... n2:w
      tmp_warn, YARP.warning = YARP.warning, false
      dw = descend[:DW]
      @width.default = dw ? dw / 1000.0 : 1.0
      cid2uni = case
      when /^Identity-[HV]$/ =~ @encoding.to_s then Proc.new{|cid| decode([cid].pack('n')) rescue nil}
      when @cmap                               then Proc.new{|cid| key = @cmap.key([cid].pack('n')); key ? (decode(key) rescue nil) : nil}
      else                                          Proc.new{|cid| decode([cid].pack('C'))}
      end
      w = descend[:W] || []
      n1, n2 = nil, nil
      w.each do |x|
        if n1.nil?
          n1 = x
        elsif x.kind_of?(Numeric)
          if n2.nil?
            n2 = x
          else
            # format 2.
            n1.upto(n2) {|i| @width[cid2uni.call(i)] = x / 1000.0}
            n1 = n2 = nil
          end
        elsif x.kind_of?(Array)
          # format 1.
          x.each_with_index {|v, i| @width[cid2uni.call(n1 + i)] = v / 1000.0}
          n1 = nil
        else raise 'must not happen'
        end
      end
      YARP.warning = tmp_warn
    end
    
    private
    
    def bytes_to_unicodes(bytes, umaps)
      if extractable?
        # 1. map byte array to cid array
        cid_array = if @cmap
          convert_with_cmap(bytes, [@cmap])
        else
          # predefined 1byte/char cmap
          bytes.b.chars
        end
        
        # 2. map cid array to unicode codepoint array
        unicodes = []
        cid_array.collect do |cid|
          uni = nil
          hold = nil
          umaps.each do |umap|
            tmp_uni = umap[cid]
            next unless tmp_uni
            tmp_uni = [tmp_uni] unless tmp_uni.kind_of?(Array)
            unless (tmp_uni & UnicodeCL).empty?
              # retry because tmp_uni includes control character(s)
              hold ||= tmp_uni
              next
            end
            uni = tmp_uni
            break
          end
          uni ||= hold
          unless uni
            cid = cid.bytes.inject(0){|a,c|(a<<8)|c}
            raise InvalidEncoding, "\"#{name}\" (#{self.class}): invalid CID 0x#{cid.to_s(16)} (#{cid})"
          end
          unicodes << uni
        end
        unicodes.flatten
      elsif embedded?
        # ROS is unusual (e.g. Adobe-Identity-0) and does not have /ToUnicode entry,
        # or broken font (unextractable on usual way).
        # Each 2 bytes means GID of embedded font.
        # If embedded font is not installed in this machine,
        # return GID as UTF-16BE codepoint.
        emb_font, inst_font = realize_embedded_font
        if inst_font.nil?
          warn_once 'This embedded font is not installed in this machine. Extracted text may be broken.', :inst_font
          return bytes.unpack('n*')
        elsif not inst_font.kind_of?(Utils::Font::TrueType)
          warn_once 'Processing of installed PostScript Font is not implemented yet. Extracted text may be broken.', :inst_font
          return bytes.unpack('n*')
        end
        
        # 1. Get GID and corresponding glyph data from embedded_umap.
        #    If embedded font is CID-keyed font, "GID" is actually CID.
        gids = if emb_font.cid_keyed?
          # GID is actually CID
          if @cmap; emb_font.cid2gid(convert_with_cmap(bytes, [@cmap]).join.unpack('n*'))
          else emb_font.cid2gid(bytes.unpack('n*'))
          end
        elsif self[:CIDToGIDMap] && self[:CIDToGIDMap].kind_of?(Stream)
          map = self[:CIDToGIDMap].stream.unpack('n*')
          bytes.unpack('n*').collect{|x| map.fetch(x)}
        else bytes.unpack('n*')
        end
        emb_glyphs = @embedded_glyphs ||= {} # embedded GID to glyph data
        glyphs = gids.collect do |gid|
          if emb_glyphs.has_key?(gid)
            emb_glyphs[gid]
          else
            # update @emb_glyphs
            glyph = emb_font.glyph_data(gid) 
            warn "GID #{gid} has no glyph data in embedded font. Installed font's character of this GID will be used instead." unless glyph
            emb_glyphs[gid] = glyph
          end
        end
        
        # 2. get GID of corresponding glyph data (taken from 1.) from installed font
        gidmap = @gidmap ||= {} # embedded GID to installed GID
        gids.zip(glyphs).each do |gid1, glyph|
          # update @glyph_map
          unless gidmap.has_key?(gid1)
            gid2 = glyph ? inst_font.search_gid(glyph) : nil
            warn "Glyph data of GID #{gid1} in embedded font does not matched any glyphs in installed font. It will be replaced to another char." unless gid2
            gidmap[gid1] = gid2
          end
        end
        
        # 3. get unicode codepoint from installed font and its gid
        gids_to_unicode(gids, gidmap, inst_font)
      else
        #raise InvalidFontFormat, "unextractable font\n#{self}"
        warn_once 'Unextractable font. Extracted text may be broken.', :unextractable
        (bytes.bytesize.odd? ? (bytes + "\x00") : bytes).unpack('n*')
      end
      
    end
  end
  
  
  # ========================================================================== #
  #                                                                            #
  # Simple Font                                                                #
  #                                                                            #
  # ========================================================================== #
  class Font1 < Font
    def initialize(*args)
      super
      
      # create width array
      # /Width array maps each "code" to width of corresponding character
      f = self[:FirstChar]
      l = self[:LastChar]
      w = self[:Widths]
      base_font = self[:BaseFont]
      dw = descriptor[:MissingWidth]
      @width.default = dw ? dw / 1000.0 : 0
      if [f,l,w].any?(&:nil?) && std_font?(base_font)
        metrics = get_font_metrics(base_font) # { :name => width }
        names = Utils::Encoding::NameToUnicode
        metrics.each do |k,v|
          key = names[k]
          raise InvalidFontFormat, "invalid afm file #{base_font}" if key.nil?
          #next if key.size != 1
          @width[key.pack('U*')] = v / 1000.0
        end
        @umaps.push(Utils::Encoding.const_get(:StandardEncoding)) unless extractable?
      elsif w.nil?
        # do nothing
      else
        f ||= 0
        l ||= w.size - 1
        l = 255 if 255 < l
        w ||= Hash.new(500)
        tmp_warn, YARP.warning = YARP.warning, false
        f.upto(l) do |i|
          uni = decode(i.chr) rescue nil
          @width[uni] = (w[i - f] || 0) / 1000.0
        end
        YARP.warning = tmp_warn
      end
    end
    
    private
    
    def descriptor
      desc = super
      if desc.nil? #&& std_font?(self[:BaseFont])
        { :Type => :FontDescriptor, :FontName => self[:BaseFont] }
      else
        desc
      end
    end
    
    def bytes_to_unicodes(bytes, umaps)
      if extractable?
        unicodes = convert_with_cmap(bytes, umaps)
        unicodes.flatten
      elsif embedded?
        emb_font, inst_font = realize_embedded_font
        if self.subtype == :Type1
          # embedded font includes complete cmaps which map bytes to unicode
          cmaps = emb_font.get_cmaps
          return convert_with_cmap(bytes, cmaps) if cmaps && ! cmaps.empty?
        end
        
        if inst_font.nil?
          warn_once 'This embedded font is not installed in this machine. Extracted text will be broken.', :inst_font
          return bytes.bytes
        elsif not inst_font.kind_of?(Utils::Font::TrueType)
          warn_once 'Processing of installed PostScript Font is not implemented yet. Extracted text will be broken.', :inst_font
          return bytes.bytes
        elsif subtype == :Type1 && inst_font.type == :OpenType
          warn_once 'This embedded font is converted by PDF writer from OpenType to Type1. Extracted text will be broken because glyph data is not compatibile with each other.', :inst_font
        end
        
        # each 1 bytes means GID of embedded font
        gids = bytes.bytes
        
        # 1. get GID and corresponding glyph data from embedded_umap.
        emb_glyphs = @embedded_glyphs ||= {} # GID to glyph data (embedded)
        glyphs = gids.collect do |gid|
          if emb_glyphs.has_key?(gid)
            emb_glyphs[gid]
          else
            # update @emb_glyphs
            glyph = emb_font.glyph_data(gid) 
            warn "GID #{gid} has no glyph data in embedded font. Installed font's character of this GID will be used instead." unless glyph
            emb_glyphs[gid] = glyph
          end
        end
        
        # 2. get GID of corresponding glyph data (taken from 1.) from installed font
        gidmap = @gidmap ||= {} # embedded GID to installed GID
        gids.zip(glyphs).each do |gid1, glyph|
          # update @glyph_map
          unless gidmap.has_key?(gid1)
            gid2 = glyph ? inst_font.search_gid(glyph) : nil
            warn "Glyph data of GID #{gid1} in embedded font does not matched any glyphs in installed font. It will be replaced to another char." unless gid2
            gidmap[gid1] = gid2
          end
        end
        
        # 3. get unicode codepoint from installed font and its gid
        gids_to_unicode(gids, gidmap, inst_font)
      else
        #raise 'must not happen'
        bytes.unpack('C*')
      end
    end
    
    def std_font?(fontname)
      %i{ Times-Roman Helvetica Courier Symbol Times-Bold Helvetica-Bold
          Courier-Bold ZapfDingbats Times-Italic Helvetica-Oblique Courier-Oblique
          Times-BoldItalic Helvetica-BoldOblique Courier-BoldOblique }.include?(fontname)
    end
    
    def get_font_metrics(name)
      path = File.expand_path("../../utils/font/afm/#{name}.afm", __FILE__)
      raise InvalidFontFormat, "#{name}.afm not found" unless FileTest.file?(path)
      content = File.read(path).lines
      start_idx = content.index{|item| /\AStartCharMetrics/ =~ item} + 1
      end_idx = content.index{|item| /\AEndCharMetrics/ =~ item} - 1
      content = content[start_idx..end_idx]
      content = content.collect{|item| /WX\s+(\d+)[\s;]+N\s+(\w+)/ =~ item; "WX #{$1}, :#{$2}\n"}.join
      m = FontMetrics.new
      m.instance_eval(content)
      m.metrics
    end
    
    class FontMetrics
      attr_reader :metrics
      #def StartFontMetrics(v); end
      #def FontName(name); @metrics[:fontname] = name end
      #def FullName(name); @metrics[:fullname] = name end
      #def FamilyName(name); @metrics[:familyname] = name end
      #def Weight(v); @metrics[:wight] = v end
      def WX(num, sym); @metrics[sym] = num end
      def initialize; @metrics = {} end
    end
  end
  
  class Font3 < Font
    def initialize(*args)
      super
      warn 'This is Type3 font. Extracted text will be broken.'
    end
    
    private
    
    def bytes_to_unicodes(bytes, umaps)
      bytes.bytes
    end
    
    def descriptor
      super || { :Type => :FontDescriptor, :FontName => self[:Name] ? self[:Name].to_s : '(Anonymous-font)' }
    end
    
  end
  
  class CIDFont < Font
    def initialize(*args)
      super
    end
  end
  
end
