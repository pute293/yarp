module YARP::Utils::Font
class TrueType
  
class Vorg < Table
  
  def read(io)
    io.seek(offset)
    version, default_y, num = io.read(8).unpack('Nn2')
    default_y = default_y[15] == 1 ? -((default_y ^ 0xffff) + 1) : default_y
    y_origins = Hash[io.read(num * 4).unpack('n*').each_slice(2).collect{|gid, y| [gid, y[15] == 1 ? -((y ^ 0xffff) + 1) : y]}]
    y_origins.default = default_y
    y_origins
  end
  
end
  
end
end