module YARP
  
  # ========================================================================== #
  #                                                                            #
  # Accessor Extension                                                         #
  #                                                                            #
  # ========================================================================== #
  
  # from ActiveSupport
  # see rails/activesupport/lib/active_support/core_ext/module/attribute_accessors.rb
  
  class ::Module
    
    unless self.instance_methods.include?(:mattr_reader)
      def mattr_reader(*syms)
        syms.each do |sym|
          class_eval(<<-EOS, __FILE__, __LINE__ + 1)
            @@#{sym} = nil unless defined? @@#{sym}
            def self.#{sym}; @@#{sym} end
          EOS
        end
      end
    end
    
    unless self.instance_methods.include?(:mattr_writer)
      def mattr_writer(*syms)
        syms.each do |sym|
          class_eval(<<-EOS, __FILE__, __LINE__ + 1)
            def self.#{sym}=(v); @@#{sym} = v end
          EOS
        end
      end
    end
    
    unless self.instance_methods.include?(:mattr_accessor)
      def mattr_accessor(*syms)
        mattr_reader(*syms)
        mattr_writer(*syms)
      end
    end
    
    alias :cattr_reader :mattr_reader unless self.instance_methods.include?(:cattr_reader)
    alias :cattr_writer :mattr_writer unless self.instance_methods.include?(:cattr_writer)
    alias :cattr_accessor :mattr_accessor unless self.instance_methods.include?(:cattr_accessor)
    
  end
  
  
  # ========================================================================== #
  #                                                                            #
  # String Extension                                                           #
  #                                                                            #
  # ========================================================================== #
  
  unless ''.respond_to?(:b)
    # for ruby-1.9 compatibility
    class ::String
      def b; self.dup.force_encoding('ASCII-8BIT') end
    end
  end
  
  # MacJapanese to another Encoding
  class ::String
    autoload :MacJapaneseTable, "#{__dir__}/../utils/encoding/mac_japanese.rb"
    autoload :MacKoreanTable,   "#{__dir__}/../utils/encoding/mac_korean.rb"
    autoload :MacChinSimpTable, "#{__dir__}/../utils/encoding/mac_chinsimp.rb"
    
    alias :force_encoding_old :force_encoding
    alias :encode_old :encode
    
    def force_encoding(enc)
      if /^mac(.)/ =~ enc.to_s.downcase
        @actual_encoding = case $1.intern
        when :j then 'mac-japanese'
        when :k then 'mac-korean'
        when :c then 'mac-chinese-simplified'
        else
          return force_encoding_old(enc)
        end
        force_encoding_old('ASCII-8BIT')
      else
        force_encoding_old(enc)
      end
    end
    
    def encode(*args)
      return encode_old(*args) unless @actual_encoding
      /^mac-(.)/ =~ @actual_encoding
      table, enc = case $1.intern
      when :j then [MacJapaneseTable, 'MacJapanese']
      when :k then [MacKoreanTable, 'MacKorean']
      when :c then [MacChinSimpTable, 'MacChineseSimplified']
      else
        return encode_old(*args)
      end
      unichar = ''
      hold = nil
      self.bytes.each do |byte|
        if hold
          char = hold.chr + byte.chr
          u_char = table[char]
          raise Encoding::InvalidByteSequenceError, "\"\\x#{'%02x'%hold}\" followed by \"\\x#{'%02x'%byte}\" on #{enc}", caller(2) unless u_char
          unichar << u_char
          hold = nil
        else
          u_char = table[byte.chr]
          if u_char then unichar << u_char
          else hold = byte
          end
        end
      end
      raise Encoding::InvalidByteSequenceError, "isolated high byte \"\\x#{'%02x'%hold}\" on #{enc}" if hold
      unichar.encode_old(*args)
    end
  end
  
end
