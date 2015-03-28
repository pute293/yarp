module YARP::Utils::Font
  
  class PsFont < FontBase
    
    def get_cmaps
      raise NotImplementedError, 'must be overrided'
    end
    
    def gid2name(*gids)
      gids.flatten.collect{|gid| h = @glyphs.find{|hash|hash[:gid] == gid}; h ? h[:name] : nil}
    end
    
    def name2gid(*names)
      names.flatten.collect{|name| name=name.intern; h = @glyphs.find{|hash|hash[:name] == name}; h ? h[:gid] : nil}
    end
    
    def glyph_data(gid_or_name)
      if gid_or_name.kind_of?(Numeric)
        gid = gid_or_name.to_i
        raise ArgumentError, "GID #{gid} is out of the range; expected (0..#{glyphcount-1})" unless (0...glyphcount).include?(gid)
        @glyphs.find{|hash|hash[:gid] == gid}[:data]
      else
        glyph_name = gid_or_name.intern
        glyph = @glyphs.find{|hash| hash[:name] == glyph_name}
        raise ArgumentError, "glyph name #{glyph_name} is not found" unless glyph
        glyph[:data]
      end
    end
    
    def search_gid(glyph_data)
      raise NotImplementedError, 'must be overrided'
    end
    
    def initialize(io, fontdict, *args)
      super
      fontname = fontdict[:FontName] || ''
      info = fontdict[:FontInfo] || {}
      @familyname = [(info[:FamilyName] || fontname).to_s]
      @fullname = [(info[:FullName] || @familyname).to_s]
      #@encoding = fontdict.fetch(:Encoding)
      
      # Dictionary object of PostScript is sorted???
      @glyphs = fontdict.fetch(:CharStrings).each_with_index.collect{|kv, i| { :gid => i, :name => kv[0].intern, :data => kv[1].to_s.b }}
      @glyphcount = @glyphs.size
    end
    
  end
  
  class Type1 < PsFont
    def initialize(*args)
      super
      @type = :Type1
    end
  end
  
  class Type2 < FontBase
    include CFF
    
    def get_cmaps
      [@cmap]
    end
    
    def gid2name(*gids)
      gids.flatten.collect{|gid| @gid2name[gid]}
    end
    
    def name2gid(*names)
      names.flatten.collect{|name| @gid2name.index(name)}
    end
    
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
    
    def actual; self end
    
    def initialize(*args)
      super
      @type = :Type2
      fonts = parse_cff(@io.read)
      sid = fonts.delete(:SID)
      raise InvalidFontFormat, 'empty CFF Font' if fonts.empty?
      raise InvalidFontFormat, 'CFF Font Collection' if fonts.size != 1
      font, dict = fonts.shift
      familyname = dict[:FamilyName]
      fullname = dict[:FullName]
      @familyname = (familyname ? [sid[familyname]] : [font]).collect{|s|s.to_s.sub(/^\w{6}\+/,'')}
      @fullname = (fullname ? [sid[fullname]] : [font]).collect{|s|s.to_s.sub(/^\w{6}\+/,'')}
      
      @glyphcount = dict.fetch(:nGlyphs)
      @gid2name = dict.fetch(:Charsets)
      @glyphs = dict.fetch(:CharStrings)
      @cid_keyed = dict.has_key?(:ROS)
      gid2code = dict[:Encoding]
      @cmap = if gid2code && !gid2code.empty?
        code2name = gid2code.each_with_index.reject{|code, gid|code.nil?}.collect{|code, gid| [code.chr, @gid2name[gid]]}.reject{|code, name| name.nil?}
        table = YARP::Utils::Encoding::NameToUnicode
        code2name = code2name.collect{|code, name| [code, table[name]]}.reject{|code, uni| uni.nil?}
        Hash[*code2name.flatten(1)]
      else nil
      end
      offset_fdselect = dict[:FDSelect]
      offset_fdarray = dict[:FDArray]
      #@cid2gid = if (@cid_keyed && offset_fdselect && offset_fdarray)
      #  io = @io
      #  io.seek(offset_fdselect)
      #  fmt = io.read(1).ord
      #  fdselect = case fmt # gid => index of font dict
      #  when 0
      #    Hash[*io.read(@glyphcount).unpack('C*').each_with_index.collect{|fd_idx, gid| [gid, fd_idx]}.flatten]
      #  when 3
      #    num_ranges, = io.read(2).unpack('n')
      #    ranges = io.read(3 * num_ranges).unpack('nC' * num_ranges)
      #    sentinel, = io.read(2).unpack('n')
      #    ranges.push(sentinel, -1)
      #    hash = {}
      #    ranges.each_slice(2).each_cons(2) do |r1, r2|
      #      fst = r1[0]
      #      fd_idx = r1[1]
      #      fst.upto(r2[0] - 1) {|gid| hash[gid] = fd_idx}
      #    end
      #    hash
      #  else raise InvalidFontFormat, "invalid FDSelect format #{fmt}; expected 0, 3"
      #  end
      #  io.seek(offset_fdarray)
      #  fdarray = read_index(io).collect{|str| read_dict(str)}
      #  p fdselect
      #  p fdarray
      #end
    end
  end
  
  class MMType1 < PsFont
    def initialize(*args)
      raise NotImplementedError, 'MMType1'
      super
      @type = :MMType1
    end
  end
  
  class Type3 < PsFont
    def initialize(*args)
      raise NotImplementedError, 'Type3'
      super
      @type = :Type3
    end
  end
  
  class Type42 < PsFont
    def initialize(*args)
      raise NotImplementedError, 'Type42'
      super
      @type = :Type42
    end
  end
  
end
