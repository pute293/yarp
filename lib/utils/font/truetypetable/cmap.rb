module PDF::Utils::Font
  
  class TrueType
    
    class Cmap < Table
      def read_tables(io)
        io.seek(offset)
        v, num_subtables = io.read(4).unpack('nn')
        entries = num_subtables.times.collect do
          pid, eid, table_offset = io.read(8).unpack('nnN')
          {:pid => pid, :eid => eid, :offset => table_offset}
        end
        # get character code to gid mappings
        subtables = entries.collect do |hash|
          pid, eid, table_offset = hash.values_at(:pid, :eid, :offset)
          CmapTable.new(io, pid, eid, offset + table_offset)
        end
        # (*1) see blow
        unicodes = subtables.select(&:unicode_keyed?).select{|table| table.format != 14}
        uvs = subtables.select{|table| table.format == 14}
        uvs.each do |table|
          c2g = table.code2gid
          c2g.each do |str, v|
            next if v
            default_unicode = str.unpack('N*')[0]
            uni1 = [default_unicode].pack('N')
            uni2 = default_unicode < 0x1_0000 ? [default_unicode].pack('n') : uni1
            t = unicodes.find {|u_table|
              u = u_table.code2gid[uni1] || u_table.code2gid[uni2]
              u && u != 0
            }
            raise InvalidFontFormat, "Failed to map unicode value U+#{'%04X' % uni1.unpack('N')[0]} to glyph ID" unless t
            c2g[str] = t.code2gid[uni1] || t.code2gid[uni2]
          end
          c2g.freeze
        end
        subtables
      end
      
      class CmapTable
        
        attr_reader :platform_id, :encoding_id, :format, :bytes, :code2gid
        attr_reader :size
        alias :length :size
        alias :pid :platform_id
        alias :eid :encoding_id
        
        def unicode_keyed?
          !!(/unicode|ucs/i =~ (@platform_id.to_s + @encoding_id.to_s))
        end
        
        def [](code); @code2gid[code] end
        
        def initialize(io, pid, eid, offset)
          @platform_id = PlatformIds.fetch(pid)
          @encoding_id = @platform_id == :Custom ? eid : EncodingIds.fetch(@platform_id).fetch(eid)
          io.seek(offset)
          @format = io.us
          @code2gid = case @format
          when 0
            # byte => glyph
            @bytes = 1
            len, lang = io.read(4).unpack('nn')
            Hash[*io.read(256).unpack('C256').each_with_index.collect{|gid, code|[code.chr, gid]}.flatten].freeze
          when 2
            # 1 or 2 byte => glyph
            @bytes = -1
            len, lang = io.read(4).unpack('nn')
            header_keys = io.read(512).unpack('n*').collect{|x| x >> 3}
            num_header = header_keys.uniq.size
            headers = io.read(8 * num_header).unpack('n*').each_slice(4).collect do |a,b,c,d|
              {:lowbyte => a & 0xFF, :entry_count => b, :delta => c[15] == 0 ? c : (~c+1), :ro => d}
            end
            headers.each_with_index do |header, idx|
              to_glyph_array = (num_header - idx) * 8   # offset from beginning of header to glypharray[0]; 8 is sizeof(header)
              ro = header[:ro] + 6    # offset from beginning of header to concerned glyph
              ro -= to_glyph_array    # offset from glypharray[0] to concerned glyph
              header[:x] = ro / 2 # 2 is sizeof(ushort)
            end
            array_count = headers.collect{|h|h[:entry_count]}.inject(&:+)
            glyph_array = io.read(2 * array_count).unpack('n*')
            first_header = headers[0]
            code2gid = Hash.new(0)
            header_keys.each_with_index do |val, idx|
              if val == 0
                # 1 byte char => glyph
                char = first_header[:lowbyte]
                glyph = glyph_array.fetch(first_header[:x]) + first_header[:delta]
                code2gid[char.chr] = glyph % 0x10000
                first_header[:lowbyte] += 1
                first_header[:x] += 1
                first_header[:entry_count] -= 1
              else
                # 2 byte char => glyph
                header = headers.fetch(val)
                low = header[:lowbyte]
                count = header[:entry_count]
                count.times do
                  glyph = glyph_array.fetch(header[:x]) + header[:delta]
                  code2gid[idx.chr + low.chr] = glyph % 0x10000
                  low += 1
                  header[:x] += 1
                end
              end
            end
            # clean-up
            while 0 < first_header[:entry_count]
              char = first_header[:lowbyte]
              glyph = glyph_array.fetch(first_header[:x]) + first_header[:delta]
              code2gid[char.chr] = glyph % 0x10000
              first_header[:lowbyte] += 1
              first_header[:x] += 1
              first_header[:entry_count] -= 1
            end
            code2gid
          when 4
            # ushort => glyph
            @bytes = 2
            len, lang = io.read(4).unpack('nn')
            num_segment = io.us / 2
            sr, es, rs = io.read(6).unpack('nnn')
            ends = io.read(num_segment * 2).unpack('n*')
            pad = io.read(2)
            starts = io.read(num_segment * 2).unpack('n*')
            deltas = io.read(num_segment * 2).unpack('n*').pack('s*').unpack('s*')
            ro_origin = io.pos
            range_offsets = io.read(num_segment * 2).unpack('n*')
            segments = starts.zip(ends, deltas, range_offsets)
            code2gid = Hash.new(0)
            segments.each_with_index do |segment, idx|
              s, e, d, ro = segment
              if ro == 0
                s.upto(e) {|code| code2, = [code].pack('n'); code2gid[code2] = (code + d) % 0x10000}
              else
                io.seek(ro_origin + idx * 2 + ro)
                s.upto(e) {|code| code, = [code].pack('n'); code2gid[code] = io.us}
              end
            end
            code2gid.freeze
          when 6
            # ushort => glyph
            @bytes = 2
            len, lang = io.read(4).unpack('nn')
            fst, count = io.read(4).unpack('nn')
            code2gid = Hash.new(0)
            count.times.collect{|i| code = [fst + i].pack('n'); code2gid[code] = io.us}
            code2gid.freeze
          when 8
            # 2 or 4 byte => glyph
            @bytes = -1
            zero, len, lang = io.read(10).unpack('nNN')
            raise NotImplementedError, '"cmap" table format 8.0'
          when 10
            # uint => glyph
            @bytes = 4
            zero, len, lang = io.read(10).unpack('nNN')
            raise NotImplementedError, '"cmap" table format 10.0'
          when 12
            # uint => glyph
            @bytes = 4
            zero, len, lang = io.read(10).unpack('nNN')
            num_segment = io.ul
            code2gid = Hash.new(0)
            io.read(num_segment * 12).unpack('N*').each_slice(3) do |fst, lst, glyph_idx|
              fst.upto(lst) {|code| code2gid[[code].pack('N')] = glyph_idx; glyph_idx += 1}
            end
            code2gid.freeze
          when 13
            # uint => glyph
            @bytes = 4
            raise NotImplementedError, '"cmap" table format 13.0'
          when 14
            # unichars => glyph
            @bytes = -1
            origin = io.pos - 2
            len, num_segments = io.read(8).unpack('NN')
            segments = num_segments.times.collect do
              selector = io.uint24
              offset0, offset1 = io.read(8).unpack('NN')
              { :var_selector => selector, :default_offset => offset0, :nondefault_offset => offset1 }
            end
            code2gid = Hash.new(0)
            segments.each do |hash|
              sel, pos0, pos1 = hash.values_at(:var_selector, :default_offset, :nondefault_offset)
              default_entries = nil
              non_default_maps = nil
              if pos0 != 0
                # "default" Unicode Variation Sequence
                # Given unicode values followed by variation selector
                # are contained in UCS-4
                io.seek(origin + pos0)
                entry_count = io.ul
                entries = io.read(4 * entry_count).bytes.each_slice(4).collect{|a,b,c,d| [(a<<16)|(b<<8)|c, d]}
                entries.each do |uni, d|
                  (uni..(uni+d)).each{|u| code2gid[[u,sel].pack('N2')] = nil} # Do this later (*1)
                end
              end
              if pos1 != 0
                # "non-default" Unicode Variation Sequence
                # Given unicode values followed by variation selector
                # are NOT contained in UCS-4
                io.seek(origin + pos1)
                entry_count = io.ul
                entries = io.read(5 * entry_count).bytes.each_slice(5).collect{|a,b,c,d,e| [(a<<16)|(b<<8)|c, (d<<8)|e]}
                entries.each do |uni, gid|
                  code = [uni, sel].pack('N2')
                  code2gid[code] = gid
                end
              end
            end
            code2gid
          else raise InvalidFontFormat, "unknown cmap format #{fmt}; expected 0, 2, 4, 6, 8, 10, 12, 13 or 14"
          end
          @size = @code2gid.size
        end # CmapTable#initialize
      end # CmapTable
      
    end # Cmap
  end
end
