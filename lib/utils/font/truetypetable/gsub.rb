module PDF::Utils::Font
  
  class TrueType
    
    # In this program, this table is used for just converting non-unicode string to unicode string.
    class Gsub < Table
      
      def lookup(io)
        return @lookup_tables if @lookup_tables
        
        origin = offset
        io.seek(origin)
        version = io.f
        script, feature, lookup = io.read(6).unpack('n3') # offsets
        
        origin += lookup
        io.seek(origin)
        lookup_count = io.us
        offsets = io.read(2 * lookup_count).unpack('n*')
        @lookup_tables = offsets.collect {|off|
          io.seek(origin + off)
          type, flag, subtable_count = io.read(6).unpack('n3')
          subtable_offsets = io.read(2 * subtable_count).unpack('n*')
          { :type => type, :offsets => subtable_offsets.collect{|o| o + origin + off} }
        }.collect{|hash| read_subtables(io, hash)}.compact.flatten(1).reject(&:empty?).freeze
      end
      
      private
      
      def read_subtables(io, hash)
        offsets = hash[:offsets]
        meth = case hash[:type]
        when 1 then :read_single
        when 2 then :read_multiple
        when 3 then :read_alternate
        when 4 then :read_ligature
        when 5 then :read_context
        when 6 then :read_chain
        when 7 then :read_extension
        when 8 then :read_reverse_chain
        else
          warn "GSUB table: invalid LookupType #{hash[:type]}; expected (1..8)"
          return nil
        end
        offsets.collect {|off|
          io.seek(off)
          self.send(meth, io)
        }.flatten(1)
      end
      
      # return GID to be replaced
      def read_coverages(io)
        fmt, count = io.read(4).unpack('n2')
        case fmt
        when 1
          # count is glyph count
          io.read(2 * count).unpack('n*')
        when 2
          # count is range count
          io.read(6 * count).unpack('n*').each_slice(3).collect{|s, e, _| s.upto(e).to_a}.flatten
        else
          warn "GSUB table: invalid Coverage Table format #{fmt}; expected 1, 2"
          []
        end
      end
      
      def read_single(io)
        origin = io.pos
        fmt, coverage_offset = io.read(4).unpack('n2')
        case fmt
        when 1
          delta = io.us
          io.seek(origin + coverage_offset)
          coverages = read_coverages(io)
          coverages.collect{|gid| [gid, (gid + delta) & 0xFFFF]}
        when 2
          count = io.us
          gids = io.read(2 * count).unpack('n*')
          io.seek(origin + coverage_offset)
          coverages = read_coverages(io)
          coverages.zip(gids)
        else
          warn "GSUB table: invalid Single Substitution format #{fmt}; expected 1, 2"
          []
        end
        
      end
      
      def read_multiple(io)
        origin = io.pos
        fmt, coverage_offset, count = io.read(6).unpack('n3')
        if fmt != 1
          warn "GSUB table: invalid Multiple Substitution format #{fmt}; expected 1"
          return []
        end
        offsets = io.read(2 * count).unpack('n*')
        io.seek(origin + coverage_offset)
        coverages = read_coverages(io)
        gids = offsets.collect{|off| io.seek(origin + off); io.read(2 * io.us).unpack('n*')}
        coverages.zip(gids).to_a
      end
      
      def read_alternate(io)
        []
      end
      
      def read_ligature(io)
        origin = io.pos
        fmt, coverage_offset, count = io.read(6).unpack('n3')
        if fmt != 1
          warn "GSUB table: invalid Ligature Substitution format #{fmt}; expected 1"
          return []
        end
        offsets = io.read(2 * count).unpack('n*')
        io.seek(origin + coverage_offset)
        coverages = read_coverages(io)
        lig_offsets = offsets.collect{|off| org = origin + off; io.seek(org); io.read(2 * io.us).unpack('n*').collect{|o| o + org}}
        result = []
        lig_offsets.zip(coverages).collect do |offs, fst|
          offs.collect do |off|
            io.seek(off)
            lig_gid, count = io.read(4).unpack('n2')
            components = io.read(2 * (count - 1)).unpack('n*')
            components.unshift(fst)
            result << [components, lig_gid]
          end
        end
        result
      end
      
      def read_context(io)
        []
      end
      
      def read_chain(io)
        []
      end
      
      def read_extension(io)
        origin = io.pos
        fmt, type, off = io.read(8).unpack('nnN')
        if fmt != 1
          warn "GSUB table: invalid Extension Substitution format #{fmt}; expected 1"
          return []
        elsif type == 7
          warn "GSUB table: invalid Extension Substitution type #{type}"
          return []
        end
        read_subtables(io, { :type => type, :offsets => [(origin + off) & 0xFFFF_FFFF] })
      end
      
      def read_reverse_chain(io)
        []
      end
      
    end
    
  end
end
