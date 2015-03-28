module PDF::Utils::Font
  
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

