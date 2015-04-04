module YARP::Utils::Font
class TrueType

class CommonTable < Table
  
  def read(io)
    io.seek(offset)
    @version = io.f
    scripts, features, lookups = io.read(6).unpack('n3') # offsets
    
    scripts = read_scripts(io, scripts)
    features = read_features(io, features)
    lookups = read_lookups(io, lookups)
    [scripts, features, read_subtables(io, lookups)]
  end
  
  private
  
  def read_subtables(io, lookups)
    raise 'must be overrided'
  end
  
  def read_scripts(io, off)
    origin = offset + off
    io.seek(origin)
    script_count = io.us
    scripts = script_count.times.collect { io.read(6).unpack('a4n') }
    
    # parse script tables
    scripts.collect do |script_tag, script_off|
      next if script_off == 0
      io.seek(origin + script_off)
      def_lang_off, lang_count = io.read(4).unpack('n2')
      langs = lang_count.times.collect { io.read(6).unpack('a4n') }
      
      # parse language system tables
      def_lang = def_lang_off == 0 ? nil : read_lang_table(io, :DFLT, origin + script_off + def_lang_off)
      langs = langs.collect {|lang_tag, lang_off| read_lang_table(io, lang_tag.intern, origin + script_off + lang_off)}
      langs.unshift(def_lang) if def_lang
      { :tag => script_tag.intern, :langs => langs }
    end.compact
  end
  
  def read_lang_table(io, tag, off)
    io.seek(off)
    _, req_count, other_count = io.read(6).unpack('n3')
    req_count = -1 if req_count == 0xffff
    indices = io.read(2 * other_count).unpack('n*')
    { :tag => tag, :req_features => req_count, :feature_indices => indices }
  end
  
  def read_features(io, off)
    origin = offset + off
    io.seek(origin)
    feature_count = io.us
    features = feature_count.times.collect { io.read(6).unpack('a4n') }
    
    # parse feature tables
    features.collect do |feature_tag, feature_off|
      next if feature_off == 0
      io.seek(origin + feature_off)
      _, lookup_count = io.read(4).unpack('n2')
      indices = io.read(2 * lookup_count).unpack('n*')
      { :tag => feature_tag.intern, :lookup_indices => indices }
    end.compact
  end
  
  def read_lookups(io, off)
    origin = offset + off
    io.seek(origin)
    lookup_count = io.us
    offsets = io.read(2 * lookup_count).unpack('n*')
    
    # parse lookup tables
    offsets.collect do |lookup_off|
      next if lookup_off == 0
      io.seek(origin + lookup_off)
      type, flag, table_count = io.read(6).unpack('n3')
      table_offsets = io.read(2 * table_count).unpack('n*').collect{|table_off| origin + lookup_off + table_off}
      mark_set = flag & 16 == 0 ? nil : io.read(2).unpack('n')[0]
      { :type => type, :flag => flag, :offsets => table_offsets, :mark_filtering_set => mark_set }
    end.compact
  end
  
  def read_coverages(io, off)
    io.seek(off)
    fmt, count = io.read(4).unpack('n2')
    case fmt
    when 1  # count is glyph count
      io.read(2 * count).unpack('n*')
    when 2  # count is range count
      io.read(6 * count).unpack('n*').each_slice(3).collect{|s, e, _| s.upto(e).to_a}.flatten
    else raise_invalid("invalid Coverage Table format #{fmt}; expected 1, 2")
    end
  end
  
  def read_class(io, off)
    io.seek(off)
    classes = {}
    case fmt = io.us
    when 1
      gid, count = io.read(4).unpack('n2')
      class_values = io.read(2 * count).unpack('n*')
      class_values.each_with_index {|v, i| classes[gid + i] = v}
    when 2
      count = io.us
      class_values = io.read(6 * count).unpack('n*')
      class_values.each_slice(3) {|s, e, v| s.upto(e){|gid| classes[gid] = v}}
    else raise_invalid("invalid Class Def Table format #{fmt}; expected 1, 2")
    end
    classes.freeze
  end
  
end

end
end

