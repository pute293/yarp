module YARP::Utils::Font
  
  class TrueType < FontBase
    
    def get_cmaps
      return @cmaps if @cmaps
      cmap = @tables[:cmap]
      if cmap && cmap.size != 0
        @cmaps = code2gids = cmap.read_tables(@io)#.select{|table| table.unicode_keyed?}.reject{|table| table.encoding_id == :Variation}.collect{|table| table.code2gid}
        #cmaps.each{|subtable| p [subtable.platform_id, subtable.encoding_id]}
      else
        [].freeze
      end
    end
    
    def gid2name(*gids)
      gids.flatten.collect{|gid| @gid2name[gid]}
    end
    
    def name2gid(*names)
      names.flatten.collect{|name| @name2gid[name.intern]}
    end
    
    def glyph_data(gid_or_name)
      if gid_or_name.kind_of?(Numeric)
        gid = gid_or_name.to_i
        raise ArgumentError, "GID #{gid} is out of the range; expected (0..#{glyphcount-1})" unless (0...glyphcount).include?(gid)
        glyph = @glyphs.fetch(gid)
        return nil if glyph[:length] == 0
        @io.seek(glyph[:offset])
        @io.read(glyph[:length])
      else
        glyph_name = gid_or_name.intern
        gid, = name2gid(glyph_name)
        raise ArgumentError, "glyph name #{glyph_name} is not found" unless gid
        glyph_data(gid)
      end
    end
    
    def search_gid(glyph_data)
      size = glyph_data.bytesize
      glyph = @glyphs.find do |g|
        next if g[:length] != size
        data = self.glyph_data(g[:gid])
        data == glyph_data
      end
      glyph ? glyph[:gid] : nil
    end
    
    def replace_gid(*gids_array)
      return nil unless @tables.has_key?(:GSUB)
      gsub_table = @tables[:GSUB]
      array = @gsub_array ||= gsub_table.lookup(@io)
      result = gids_array.collect do |gids|
        array.select{|cov, subst| cov == gids || subst == gids}.collect{|cov, subst| cov == gids ? subst : cov}
      end
      gids_array.size <= 1 ? result.first : result
    end
    
    # return { :aw => advance_width, :lsb => left_side_bearing }
    def get_hmetrics(gid)
      return nil if glyphcount <= gid
      @hhea ||= self[:hhea]
      hmtx = self[:hmtx]
      return nil if (@hhea.nil? || hmtx.nil?)
      num_hmtx = @hhea[:num_hmtx]
      if gid < num_hmtx
        off = gid * 4
        aw, lsb = hmtx[off, 4].unpack('n2').pack('ns').unpack('ns')
      else
        aw, = hmtx[(num_hmtx - 1) * 4, 2].unpack('n')
        lsb, = hmtx[(num_hmtx * 4) + (gid - num_hmtx) * 2, 2].unpack('n').pack('s').unpack('s')
      end
      { :aw => aw, :lsb => lsb }
    end
    
    # return { :ah => advance_height, :tsb => top_side_bearing }
    def get_vmetrics(gid)
      return nil if glyphcount <= gid
      @vhea ||= self[:vhea]
      vmtx = self[:vmtx]
      return nil if (@vhea.nil? || vmtx.nil?)
      num_vmtx = @vhea[:num_vmtx]
      if gid < num_vmtx
        off = gid * 4
        ah, tsb = vmtx[off, 4].unpack('n2').pack('ns').unpack('ns')
      else
        ah, = vmtx[(num_vmtx - 1) * 4, 2].unpack('n')
        tsb, = vmtx[(num_vmtx * 4) + (gid - num_vmtx) * 2, 2].unpack('n').pack('s').unpack('s')
      end
      { :ah => ah, :tsb => tsb }
    end
    
    def [](name)
      table = @tables[name.intern]
      if table.nil?
        nil
      elsif table.respond_to?(:read)
        table.read(@io)
      else
        table.dump(@io)
      end
    end
    
    def initialize(*args)
      super
      @type = :TrueType
      io = @io
      
      @version = io.f
      table_count = io.us
      search_range = io.us
      entry_selector = io.us
      range_shift = io.us
      @tables = Hash[*table_count.times.collect{table = Table.new(io.tag, io.ul, io.ul, io.ul);[table.tag, table]}.flatten]
      
      raise InvalidFontFormat, '"head" table not found' unless @tables.has_key?(:head)
      raise InvalidFontFormat, '"maxp" table not found' unless @tables.has_key?(:maxp)
      #raise InvalidFontFormat, '"name" table not found' unless @tables.has_key?(:name)
      #raise InvalidFontFormat, '"post" table not found' unless @tables.has_key?(:post)
      # ^ some embedded font does not have "name" and "post" table
      
      head = @tables.fetch(:head)
      maxp = @tables.fetch(:maxp)
      name_ = @tables[:name]  # maybe nil
      
      io.seek(maxp.offset + 4)
      @glyphcount = io.us
      names = name_ ? name_.read_names(io) : []
      @familyname = names.select{|hash|%i{FamilyName FamilyName2}.include?(hash[:nameid])}.collect{|hash|hash[:data].sub!(/^\w{6}\+/,'');hash}.collect{|hash|
        lcid = hash[:lcid]
        data = hash[:data]
        if hash[:pid] == :Windows && ![0, 0x0409, 0x0809].include?(lcid) && LcidToCodepage.has_key?(lcid)
          cp = LcidToCodepage[lcid]
          enc = Encoding.find("CP#{cp}") rescue nil
          enc ? [data, data.encode(enc)] : data
        else data
        end
      }.flatten.uniq
      @fullname = names.select{|hash|%i{FullName PsName PsName2}.include?(hash[:nameid])}.collect{|hash|hash[:data].sub(/^\w{6}\+/,'');hash}.collect{|hash|
        lcid = hash[:lcid]
        data = hash[:data]
        if hash[:pid] == :Windows && ![0, 0x0409, 0x0809].include?(lcid) && LcidToCodepage.has_key?(lcid)
          cp = LcidToCodepage[lcid]
          enc = Encoding.find("CP#{cp}") rescue nil
          enc ? [data, data.encode(enc)] : data
        else data
        end
      }.flatten.uniq
      
      io.seek(head.offset + 36)
      @xmin, @ymin, @xmax, @ymax = io.read(8).unpack('n4').pack('s4').unpack('s4')
      io.seek(head.offset + 50)
      @loca_fmt = io.us
      unless [0, 1].include?(@loca_fmt)
        str = "'indexToLocFormat' entry in \"head\" table has invalid value #{@loca_fmt}; expected 0 or 1"
        raise InvalidFontFormat, str
      end
      
      @glyphs = init_glyphs(io)
      @gid2name = init_glyph_names(io).freeze
      @name2gid = Hash[@gid2name.each_with_index.to_a].freeze
    end
    
    private
    
    def init_glyphs(io)
      loca = @tables[:loca]
      glyf = @tables[:glyf]
      raise InvalidFontFormat, '"loca" table not found' unless (loca && glyf)
      origin = glyf.offset
      io.seek(loca.offset)
      fmt = @loca_fmt == 0 ? [2, 'n*'] : [4, 'N*']
      data = io.read(fmt[0] * (glyphcount + 1)).unpack(fmt[1])
      if @loca_fmt == 0
        data.each_cons(2).with_index.collect{|xy, i| x, y = xy; {:gid => i, :offset => origin + x * 2, :length => (y - x) * 2}}
      else
        data.each_cons(2).with_index.collect{|xy, i| x, y = xy; {:gid => i, :offset => origin + x, :length => y - x}}
      end
    end
    
    def init_glyph_names(io)
      post = @tables[:post]
      return [] unless post
      io.seek(post.offset)
      post_v = io.ul
      case post_v
      when 0x00010000
        Mac_Glyph_Names
      when 0x00020000
        io.seek(post.offset + 32)
        num_glyphs = io.us
        raise InvalidFontFormat, 'value conflict: number of glyphs; "maxp" table vs. "post" table' if num_glyphs != glyphcount
        indices = num_glyphs.times.collect{io.us}
        sorted_tables = @tables.values.sort{|t1,t2|t1.offset <=> t2.offset}
        next_offset = post == sorted_tables.last ? FileTest.size(io) : sorted_tables[sorted_tables.index(post) + 1].offset
        extend_glyph_names = []; extend_glyph_names.push(io.pascal) while io.pos < next_offset
        indices.collect{|idx| idx < 258 ? Mac_Glyph_Names[idx] : extend_glyph_names[idx - 258].intern}
      when 0x00025000
        raise NotImplementedError, '"post" table version 2.5'
        []
      when 0x00030000
        []
      else raise InvalidFontFormat, "'version' entry in \"post\" table has invalid value #{post_v}"
      end
    end
    
  end
  
end

require_relative 'truetypetable/table'
