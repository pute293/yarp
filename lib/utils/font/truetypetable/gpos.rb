module YARP::Utils::Font
class TrueType

class Gpos < CommonTable
  
  #def read(io)
  #  scripts, features, lookups = super
  #  lookups2 = read_subtables(io, lookups)
  #  [scripts, features, lookups, lookups2]
  #end
  
  private
  
  def read_subtables(io, lookups)
    lookups.collect {|lookup|
      type = lookup[:type]
      next unless (1..9).include?(type)
      
      if type == 9
        # Extension Positioning
        ex_lookup = lookup[:offsets].collect do |off|
          io.seek(off)
          fmt, lk_type, ex_off = io.read(8).unpack('nnN')
          raise_invalid("invalid Extension Positioning Table format #{fmt}; expected 1") if fmt != 1
          [lk_type, off + ex_off]
        end
        raise_invalid("invalid Extension Positioning Table format; all lookup types must be same") if ex_lookup.collect(&:first).uniq.size != 1
        type = lookup[:type] = ex_lookup[0][0]
        lookup[:offsets] = ex_lookup.collect(&:last)
      end
      
      self.send("type#{type}".intern, io, lookup).collect{|hash| if hash; hash[:type] = :GPOS end; hash}.compact
    }.compact
  end
  
  # Single Adjustment Positioning
  def type1(io, lookup)
    lookup[:offsets].collect do |off|
      io.seek(off)
      fmt, coverage_off, valfmt = io.read(6).unpack('n3')
      val = case fmt
      when 1
        read_value_record(io, valfmt)
      when 2
        val_count = io.us
        val_count.times.collect{ read_value_record(io, valfmt) }
      else raise_invalid("invalid Single Adjustment Positioning Table format #{fmt}; expected 1, 2")
      end
      coverages = read_coverages(io, off + coverage_off)
      { :subtype => :single_adjust, :coverages => coverages, :values => val }
    end
  end
  
  # Pair Positioning Adjustment
  def type2(io, lookup)
    lookup[:offsets].collect do |off|
      io.seek(off)
      fmt, coverage_off, valfmt1, valfmt2 = io.read(8).unpack('n4')
      case fmt
      when 1
        pair_count = io.us
        pair_offs = io.read(2 * pair_count).unpack('n*')
        val = pair_offs.collect do |pair_off|
          io.seek(off + pair_off)
          val_count = io.us
          val_count.times.collect do
            gid = io.us
            [gid, read_value_record(io, valfmt1), read_value_record(io, valfmt2)]
          end
        end
        coverages = read_coverages(io, off + coverage_off)
        { :subtype => :anchor, :coverages => coverages, :values => val }
      when 2
        class1_off, class2_off, class1_count, class2_count = io.read(8).unpack('n4')
        matrix = [[] * class2_count] * class1_count
        class1_count.times do |i|
          class2_count.times do |j|
            matrix[i][j] = [read_value_record(io, valfmt1), read_value_record(io, valfmt2)]
          end
        end
        
        class1 = read_class(io, off + class1_off)
        class2 = read_class(io, off + class2_off)
        coverages = read_coverages(io, off + coverage_off)
        val = coverages.collect do |gid|
          c1 = class1[gid] || 0
          class2.collect {|gid2, c2| [gid2, *matrix.fetch(c1).fetch(c2)]}
        end
        { :subtype => :pair_adjust, :coverages => coverages, :values => val }
      else raise_invalid("invalid Pair Positioning Adjustment Table format #{fmt}; expected 1, 2")
      end
    end
  end
  
  # Cursive Attachment Positioning
  def type3(io, lookup)
    lookup[:offsets].collect do |off|
      io.seek(off)
      fmt, coverage_off, count = io.read(6).unpack('n3')
      raise_invalid("invalid Cursive Attachment Positioning Table format #{fmt}; expected 1") if fmt != 1
      
      anchor_offsets = io.read(4 * count).unpack('n*').each_slice(2)
      anchors = anchor_offsets.collect do |ent, exi|
        ent = ent == 0 ? nil : read_anchor(io, ent + off)
        exi = exi == 0 ? nil : read_anchor(io, exi + off)
        { :entry => ent, :exit => exi }
      end
      
      coverages = read_coverages(io, off + coverage_off)
      { :subtype => :cursive, :coverages => coverages, :values => anchors }
    end
  end
  
  # MarkToBase Attachment Positioning
  def type4(io, lookup)
    #lookup[:offsets].each_with_object([]) do |off, lookups|
    lookup[:offsets].collect do |off|
      io.seek(off)
      fmt, mark_off, base_off, class_count, mark_array_off, base_array_off = io.read(12).unpack('n6')
      raise_invalid("invalid MarkToBase Attachment Positioning Table format #{fmt}; expected 1") if fmt != 1
      
      mark_cov = read_coverages(io, off + mark_off)
      base_cov = read_coverages(io, off + base_off)
      
      io.seek(off + mark_array_off)
      mark_count = io.us
      mark_anchor_offs = io.read(4 * class_count).unpack('n*').each_slice(2).collect{|klass, mark_offset| [klass, off + mark_array_off + mark_offset]}
      mark_anchors = mark_anchor_offs.collect{|klass, off| [klass, read_anchor(io, off)]}
      
      io.seek(off + base_array_off)
      base_count = io.us
      base_anchor_offs = io.read(2 * class_count).unpack('n*').collect{|base_offset| off + base_array_off + base_offset}
      base_anchors = base_anchor_offs.collect{|off| read_anchor(io, off)}
      base_anchors = base_anchors.product(mark_anchors).collect{|pt1, (klass, pt2)| [klass, pt1]}
      
      #lookups.push({ :subtype => :base, :coverages => base_cov, :values => base_anchors }, { :subtype => :mark, :coverages => mark_cov, :values => mark_anchors })
      { :subtype => :base, :coverages => base_cov, :values => base_anchors, :marks => mark_cov, :mark_anchors => mark_anchors }
    end
  end
  
  # MarkToLigature Attachment Positioning
  def type5(io, lookup)
    #lookup[:offsets].each_with_object([]) do |off, lookups|
    lookup[:offsets].collect do |off|
      io.seek(off)
      fmt, mark_off, lig_off, class_count, mark_array_off, lig_array_off = io.read(12).unpack('n6')
      raise_invalid("invalid MarkToLigature Attachment Positioning Table format #{fmt}; expected 1") if fmt != 1
      
      mark_cov = read_coverages(io, off + mark_off)
      lig_cov = read_coverages(io, off + lig_off)
      
      io.seek(off + mark_array_off)
      mark_count = io.us
      mark_anchor_offs = io.read(4 * class_count).unpack('n*').each_slice(2).collect{|klass, mark_offset| [klass, off + mark_array_off + mark_offset]}
      mark_anchors = mark_anchor_offs.collect{|klass, off| [klass, read_anchor(io, off)]}
      
      io.seek(off + lig_array_off)
      lig_count = io.us
      lig_attach_offs = io.read(2 * lig_count).unpack('n*').collect{|attach_offset| off + lig_array_off + attach_offset}
      lig_anchor_offs = lig_attach_offs.collect do |off|
        io.seek(off)
        components = io.us
        io.read(2 * components * class_count).unpack('n*').collect{|o| off + o}
      end
      klasses = mark_anchors.collect(&:first).uniq
      lig_anchors = lig_anchor_offs.collect{|offs| offs.collect{|off| read_anchor(io, off)}.each_slice(class_count).to_a.product(klasses)\
        .collect{|pts, klass| pts.collect{|pt1| [klass, pt1]}}}
      
      #lookups.push({ :subtype => :ligature, :coverages => lig_cov, :values => lig_anchors }, { :subtype => :mark, :coverages => mark_cov, :values => nil })
      { :subtype => :ligature, :coverages => lig_cov, :values => lig_anchors, :marks => mark_cov, :mark_anchors => mark_anchors }
    end
  end
  
  # MarkToMark Attachment Positioning
  def type6(io, lookup)
    lookup[:offsets].collect do |off|
      io.seek(off)
      fmt, mark1_off, mark2_off, class_count, mark1_array_off, mark2_array_off = io.read(12).unpack('n6')
      raise_invalid("invalid MarkToMark Attachment Positioning Table format #{fmt}; expected 1") if fmt != 1
      
      mark1_cov = read_coverages(io, off + mark1_off)
      mark2_cov = read_coverages(io, off + mark2_off)
      
      io.seek(off + mark1_array_off)
      mark_count = io.us
      mark1_anchor_offs = io.read(4 * class_count).unpack('n*').each_slice(2).collect{|klass, mark_offset| [klass, off + mark1_array_off + mark_offset]}
      mark1_anchors = mark1_anchor_offs.collect{|klass, off| [klass, read_anchor(io, off)]}
      
      io.seek(off + mark2_array_off)
      mark_count = io.us
      mark2_anchor_offs = io.read(2 * mark_count * class_count).unpack('n*').collect{|base_offset| off + mark2_array_off + base_offset}
      mark2_anchors = mark2_anchor_offs.collect{|off| read_anchor(io, off)}
      mark2_anchors = mark2_anchors.each_slice(class_count).to_a.product(mark1_anchors).collect{|pts, (klass, pt2)| pts.collect{|pt1| [klass, pt1]}}.flatten(1)
      
      { :subtype => :mark, :coverages => mark1_cov, :values => mark1_anchors, :marks => mark2_cov, :mark_anchors => mark2_anchors }
    end
  end
  
  # Contextual Positioning
  def type7(io, lookup)
    raise NotImplementedError, 'GPOS Contextual Positioning table'
    #lookup[:offsets].collect do |off|
    #  io.seek(off)
    #  fmt = io.us
    #  raise_invalid("invalid Contextual Positioning Table format #{fmt}; expected 1..3") unless (1..3).include?(fmt)
    #  case fmt
    #  when 1
    #    coverage_off, ruleset_count = io.read(4).unpack('n2')
    #    ruleset_offs = io.read(2 * ruleset_count).unpack('n*')
    #    ruleset_offs.collect do |ruleset_off|
    #      io.seek(off + ruleset_off)
    #      rule_count = io.us
    #      rules_offs = io.read(2 * rule_count).unpack('n*')
    #      rules_offs.collect do |rule_off|
    #        io.seek(off + ruleset_off + rule_off)
    #        glyph_count, pos_count = io.read(4).unpack('n2')
    #        inputs = io.read(2 * (glyph_count - 1)).unpack('n*')
    #        
    #      end
    #    end
    #  when 2
    #  when 3
    #  end
    #end
  end
  
  # Chaining Contextual Positioning
  def type8(io, lookup)
    lookup[:offsets].collect do |off|
      io.seek(off)
      fmt = io.us
      raise_invalid("invalid Contextual Positioning Table format #{fmt}; expected 1..3") unless (1..3).include?(fmt)
      case fmt
      when 1
        coverage_off, ruleset_count = io.read(4).unpack('n2')
        ruleset_offs = io.read(2 * ruleset_count).unpack('n*')
        ruleset_offs.collect do |ruleset_off|
          io.seek(off + ruleset_off)
          rule_count = io.us
          rules_offs = io.read(2 * rule_count).unpack('n*')
          rules_offs.collect do |rule_off|
            io.seek(off + ruleset_off + rule_off)
            glyph_count1 = io.us
            gids1 = io.read(2 * glyph_count1).unpack('n*')
            glyph_count2 = io.us
            gids2 = io.read(2 * glyph_count2).unpack('n*')
            glyph_count3 = io.us
            gids3 = io.read(2 * glyph_count3).unpack('n*')
            pos_count = io.us
            raise_invalid
          end
        end
      when 2
        raise_invalid
      when 3
        glyph_count1 = io.us
        coverage_offs1 = io.read(2 * glyph_count1).unpack('n*')
        glyph_count2 = io.us
        coverage_offs2 = io.read(2 * glyph_count2).unpack('n*')
        glyph_count3 = io.us
        coverage_offs3 = io.read(2 * glyph_count3).unpack('n*')
        pos_count = io.us
        entries = io.read(4 * pos_count).unpack('n*').each_slice(2)
        
        back_covs = coverage_offs1.collect{|o| read_coverages(io, off + o)}.flatten
        input_covs = coverage_offs2.collect{|o| read_coverages(io, off + o)}.flatten
        ahead_covs = coverage_offs3.collect{|o| read_coverages(io, off + o)}.flatten
        
        #puts "back:"
        #pp back_covs
        #puts "input:"
        #pp input_covs
        #puts "ahead:"
        #pp ahead_covs
        #puts "entries:"
        #pp entries.to_a
        #
        #raise_invalid
        { :subtype => :context, :coverages => input_covs, :values => entries.to_a, :backtrack => back_covs, :lookahead => ahead_covs }
      end
    end
  end
  
  def read_value_record(io, flag)
    ret = {}
    ret[:x] = io.s if flag[0] == 1
    ret[:y] = io.s if flag[1] == 1
    ret[:x_advance] = io.s if flag[2] == 1
    ret[:y_advance] = io.s if flag[3] == 1
    ret[:x_device] = io.us if flag[4] == 1
    ret[:y_device] = io.us if flag[5] == 1
    ret[:x_advance_device] = io.us if flag[6] == 1
    ret[:y_advance_device] = io.us if flag[7] == 1
    ret.freeze
  end
  
  def read_anchor(io, off)
    io.seek(off)
    fmt, x, y = io.read(6).unpack('n3').pack('ns2').unpack('ns2')
    case fmt
    when 1 then [x, y]
    when 2 then io.read(2); [x, y]
    when 3 then io.read(4); [x, y]
    else raise_invalid("invalid Anchor Table format #{fmt}; expected 1, 2 or 3")
    end
  end
  
  def read_pos_lookup(io, off)
    io.seek(off)
    io.read(4).unpack('n2')
  end
  
end


end
end

