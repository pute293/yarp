module YARP
  
  class XObject < Stream
    def initialize(*args)
      super
      self[:Type] = :XObject
      # sometimes /Type field is omitted
    end
  end
  
  class Form < XObject
  end
  
  class PostScript < XObject
  end
  
  class Group < XObject
  end
  
  class Reference < XObject
  end
  
end
