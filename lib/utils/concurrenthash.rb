require 'monitor'

module PDF::Utils
  
  class ConcurrentHash < Object
    def initialize(*ifnone)
      @data = if block_given?
        raise ::ArgumentError, "wrong number of arguments (1 for 0)" unless ifnone.empty?
        Hash.new{|hash, key| hash.synchronize{proc.call(hash, key)}}
      else
        Hash.new(*ifnone)
      end
      @data.extend(::MonitorMixin)
    end
    
    def to_hash
      @data
    end
    
    alias :to_h :to_hash
    
    def method_missing(name, *args)
      @data.synchronize {
        @data.__send__(name, *args)
      }
    end
  end
  
  #a = ConcurrentHash.new{|hash,key| hash[key] = 1}
  #p a[1]
  #a = ConcurrentHash.new
  #p a[1]
end