module YARP::Utils::Font
class TrueType
  
  class Table
    attr_reader :tag, :checksum, :offset, :length
    alias :pos :offset
    alias :size :length
    
    def initialize(tag, checksum, offset, length)
      @tag, @checksum, @offset, @length = tag.intern, checksum, offset, length
    end
    
    def dump(io)
      io.seek(offset)
      io.read(length)
    end
    
    def to_s; "#{@tag}##{'%08x'%@offset}/#{'%08x'%@length}" end
    
    def inspect
      s = super
      s.sub(/@(checksum|offset|length)=(\d+)/) {"@#{$1}=#{'%08x'%$2}"}
    end
    
    private
    
    def warn(*args)
      YARP.warn(*args)
    end
    
    def raise_invalid(str='')
      raise InvalidFontFormat, "#{tag} table: #{str}", caller
    end
    
    class << self
      alias :new_old :new
      def new(tag, *args)
        tag = tag.intern
        klass = case tag
        when :cmap then Cmap
        when :name then Name
        when :hhea then Hhea
        when :vhea then Vhea
        when :GSUB then Gsub
        when :GPOS then Gpos
        #when :BASE then Base
        when :VORG then Vorg
        else Table
        end
        klass.new_old(tag, *args)
      end
    end
  end
  
end
end

require_relative 'constants'
require_relative 'cmap'
require_relative 'name'
require_relative 'hhea'
require_relative 'commontable'
require_relative 'gsub'
require_relative 'gpos'
#require_relative 'base'
require_relative 'vorg'
