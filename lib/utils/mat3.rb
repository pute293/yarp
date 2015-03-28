module PDF::Utils

if PDF::NARRAY
  
  module Vec2
    def self.new(*args)
      if args.empty?
        ::NVector.float(2)
      else
        args = args.flatten[0,2].collect(&:to_f)
        args.push(0.0) while args.size < 2
        ::NVector[*args]
      end
    end
  end
  
  module Vec3
    def self.new(*args)
      if args.empty?
        ::NVector.float(3)
      else
        args = args.flatten[0,3].collect(&:to_f)
        args.push(0.0) while args.size < 3
        ::NVector[*args]
      end
    end
  end
  
  module Mat2
    def self.new(*args)
      if args.empty?
        ::NMatrix.float(2, 2).identity
      else
        args = args.flatten[0,4].collect(&:to_f)
        args.push(0.0) while args.size < 4
        ::NMatrix[*args.each_slice(2)]
      end
    end
  end
  
  module Mat3
    def self.new(*args)
      if args.empty?
        ::NMatrix.float(3, 3).identity
      else
        args = args.flatten[0,9].collect(&:to_f)
        args.push(0.0) while args.size < 9
        ::NMatrix[*args.each_slice(3)]
      end
    end
  end
  
  class ::NMatrix
    def m00; self[0,0] end
    def m01; self[1,0] end
    def m02; self[2,0] end
    def m10; self[0,1] end
    def m11; self[1,1] end
    def m12; self[2,1] end
    def m20; self[0,2] end
    def m21; self[1,2] end
    def m22; self[2,2] end
    def m00=(v); self[0,0] = v.to_f end
    def m01=(v); self[1,0] = v.to_f end
    def m02=(v); self[2,0] = v.to_f end
    def m10=(v); self[0,1] = v.to_f end
    def m11=(v); self[1,1] = v.to_f end
    def m12=(v); self[2,1] = v.to_f end
    def m20=(v); self[0,2] = v.to_f end
    def m21=(v); self[1,2] = v.to_f end
    def m22=(v); self[2,2] = v.to_f end
    alias :tx :m20
    alias :ty :m21
    alias :tx= :m20=
    alias :ty= :m21=
    def identity!
      self[true,true] = 0
      self.identity
    end
  end
  
else
  
  require 'matrix'
  
  module Vec2
    def self.new(*args)
      if args.empty?
        ::Vector[0.0, 0.0]
      else
        args = args.flatten[0,2].collect(&:to_f)
        args.push(0.0) while args.size < 2
        ::Vector[*args]
      end
    end
  end
  
  module Vec3
    def self.new(*args)
      if args.empty?
        ::Vector[0.0, 0.0, 0.0]
      else
        args = args.flatten[0,3].collect(&:to_f)
        args.push(0.0) while args.size < 3
        ::Vector[*args]
      end
    end
  end
  
  module Mat2
    def self.new(*args)
      if args.empty?
        ::Matrix[[1.0, 0.0], [0.0, 1.0]]
      else
        args = args.flatten[0,4].collect(&:to_f)
        args.push(0.0) while args.size < 4
        ::Matrix[*args.each_slice(2)]
      end
    end
  end
  
  module Mat3
    def self.new(*args)
      if args.empty?
        ::Matrix[[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]
      else
        args = args.flatten[0,9].collect(&:to_f)
        args.push(0.0) while args.size < 9
        ::Matrix[*args.each_slice(3)]
      end
    end
  end
    
  class ::Matrix
    def m00; self[0,0] end
    def m01; self[0,1] end
    def m02; self[0,2] end
    def m10; self[1,0] end
    def m11; self[1,1] end
    def m12; self[1,2] end
    def m20; self[2,0] end
    def m21; self[2,1] end
    def m22; self[2,2] end
    def m00=(v); self[0,0] = v.to_f end
    def m01=(v); self[0,1] = v.to_f end
    def m02=(v); self[0,2] = v.to_f end
    def m10=(v); self[1,0] = v.to_f end
    def m11=(v); self[1,1] = v.to_f end
    def m12=(v); self[1,2] = v.to_f end
    def m20=(v); self[2,0] = v.to_f end
    def m21=(v); self[2,1] = v.to_f end
    def m22=(v); self[2,2] = v.to_f end
    alias :tx :m20
    alias :ty :m21
    alias :tx= :m20=
    alias :ty= :m21=
    alias dup clone
    def identity!
      row_size.times{|i| column_size.times{|j| self[i,j] = i == j ? 1.0 : 0.0}}
      self
    end
  end
  
end

end
