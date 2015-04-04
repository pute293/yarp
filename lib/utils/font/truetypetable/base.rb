module YARP::Utils::Font
class TrueType

class Base < Table
  
  def read(io)
    io.seek(offset)
    version = io.f
    h_off, v_off = io.read(4).unpack('n2')
    if h_off
      io.seek(
      
      
    end
    if v_off
    end
    
    fmt = 's3ns11n'
    items = io.read(32).unpack('n16').pack(fmt).unpack(fmt)
    {
      :version => version,
      :ascender => items[0],
      :descender => items[1],
      :linegap => items[2],
      :max_aw => items[3],
      :min_lsb => items[4],
      :min_rsb => items[5],
      :xmax_extent => items[6],
      :caret_slope_rise => items[7],
      :caret_slope_run => items[8],
      :caret_offset => items[9],
      :reserved1 => items[10],
      :reserved2 => items[11],
      :reserved3 => items[12],
      :reserved4 => items[13],
      :metric_fmt => items[14],
      :num_hmtx => items[15]
    }
  end
  
  private
  
  def read_axis_table(io, off)
    return nil if off == 0
    io.seek(offset + off)
    tag_off, script_off = io.read(4).unpack('n2')
    
    tags = []
    if tag_off != 0
      # read tag list
      io.seek(offset + off + tag_off)
      n, = io.read(2).unpack('n')
      n.times{ tags.push(io.read(4)) }
    end
    
    # read script list
    io.seek(offset + off + script_off)
    n, = io.read(2).unpack('n')
    records = n.times.collect do
      tag, off = io.read('a4n')
      
    end
    io.read(6 * n)
    
    
  end
  
end

end
end
