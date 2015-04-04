module YARP::Utils::Font
class TrueType

class Hhea < Table
  
  def read(io)
    io.seek(offset)
    version = io.f
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
  
end

class Vhea < Table
  
  def read(io)
    io.seek(offset)
    version = io.f
    fmt = 's15n'
    items = io.read(32).unpack('n16').pack(fmt).unpack(fmt)
    {
      :version => version,
      :ascender => items[0],
      :descender => items[1],
      :linegap => items[2],
      :max_ah => items[3],
      :min_tsb => items[4],
      :min_bsb => items[5],
      :ymax_extent => items[6],
      :caret_slope_rise => items[7],
      :caret_slope_run => items[8],
      :caret_offset => items[9],
      :reserved1 => items[10],
      :reserved2 => items[11],
      :reserved3 => items[12],
      :reserved4 => items[13],
      :metric_fmt => items[14],
      :num_vmtx => items[15]
    }
  end
  
end

end
end
