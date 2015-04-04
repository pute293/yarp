module YARP::Utils::Font
  
  class OpenType < TrueType
    include CFF
    
    def glyph_data(gid_or_name)
      if gid_or_name.kind_of?(Numeric)
        gid = gid_or_name.to_i
        raise ArgumentError, "GID #{gid} is out of the range (0..#{glyphcount-1})" unless (0...glyphcount).include?(gid)
        @glyphs.fetch(gid)
      else
        glyph_name = gid_or_name.intern
        gid, = name2gid(glyph_name)
        raise ArgumentError, "glyph name #{glyph_name} is not found" unless gid
        glyph_data(gid)
      end
    end
    
    def search_gid(glyph_data)
      size = glyph_data.bytesize
      @glyphs.index do |glyph|
        next if glyph.bytesize != size
        glyph == glyph_data
      end
    end
    
    def cid_keyed?
      @cid_keyed
    end
    
    def cid2gid(*cids)
      super unless cid_keyed?
      @cid2gid ||= Hash[@gid2name.each_with_index.collect{|sym, gid| /\.(\d+)$/ =~ sym.to_s; [$1.to_i, gid]}]
      cids.flatten.collect{|cid| @cid2gid[cid]}
    end
    
    def get_vmetrics(gid)
      ret = super
      return ret if ret
      @vorg ||= self[:VORG]
      return nil unless @vorg
      { :origin => @vorg[gid] }
    end
    
    def subr(n, cid=-1)
      raise KeyError, 'no local subr defined' unless @subr
      subr = if self.cid_keyed?
        raise ArgumentError, "CID #{cid} is out of range (0..#{glyphcount-1})" unless (0...glyphcount).include?(cid)
        fd_idx = @cff_dict.fetch(:FDSelect)[cid]
        raise ArgumentError, "FontDict of CID #{cid} is not defined" unless fd_idx
        @cff_dict.fetch(:FDArray).fetch(fd_idx).fetch(:Private).fetch(:Subrs)
      else @subr
      end
      s = subr.size
      bias = s < 1240 ? 107 : s < 33900 ? 1131 : 32768
      subr.fetch(bias + n)
    end
    
    def gsubr(n)
      raise KeyError, 'no global subr defined' unless @gsubr
      s = @gsubr.size
      bias = s < 1240 ? 107 : s < 33900 ? 1131 : 32768
      @gsubr.fetch(bias + n)
    end
    
    def initialize(*args)
      super
      @type = :OpenType
    end
    
    private
    
    def init_glyphs(io)
      cff = @tables[:'CFF ']
      raise InvalidFontFormat, '"CFF " table not found' unless cff
      fonts = parse_cff(cff.dump(io))
      sid = fonts.delete(:SID)
      @gsubr = fonts.delete(:Gsubr)
      raise InvalidFontFormat, 'empty CFF Font' if fonts.empty?
      raise InvalidFontFormat, 'CFF Font Collection' if fonts.size != 1
      font, dict = fonts.shift
      familyname = dict[:FamilyName]
      fullname = dict[:FullName]
      @familyname.push((familyname ? sid[familyname] : font).to_s.sub(/^\w{6}\+/,''))
      @fullname.push((fullname ? sid[fullname] : font).to_s.sub(/^\w{6}\+/,''))
      @familyname.uniq!
      @fullname.uniq!
      @cff_dict = dict
      @cid_keyed = dict.has_key?(:ROS)
      if dict.has_key?(:ROS)
        @cid_keyed = true
        @subr = dict.has_key?(:FDArray) && dict.has_key?(:FDSelect)
      else
        @cid_keyed = false
        @subr = dict.has_key?(:Private) && dict[:Private].has_key?(:Subrs) ? dict[:Private][:Subrs] : nil
      end
      
      dict.fetch(:CharStrings)
    end
    
    def init_glyph_names(io)
      gid2name = super
      charsets = @cff_dict.fetch(:Charsets)
      charsets.each_with_index{|sym, i| gid2name[i] ||= sym}
      gid2name
    end
    
  end
  
end
