# coding: utf-8

module YARP::Parser
  
  class PostScriptParser
    
    class PostScriptError < RuntimeError
      attr_accessor :op
      
      def initialize(*args)
        super
        @op = nil
      end
      
      def to_s
        klass = self.class.to_s.split('::').last
        from = op ? " in #{op}" : ''
        mes = super.sub(self.class.to_s, '')
        mes = ': ' + mes unless mes.empty?
        "/#{klass.downcase}#{from}#{mes}"
      end
    end
    class QuitCalled < PostScriptError; end
    class SyntaxError < PostScriptError; end
    class StackUnderFlow < PostScriptError; end
    class UnmatchedMark < PostScriptError; end
    class RangeCheck < PostScriptError; end
    class Undefined < PostScriptError; end
    class TypeCheck < PostScriptError; end
    class DictStackUnderflow < PostScriptError; end
    class InvalidAccess < PostScriptError; end
    class InvalidExit < PostScriptError; end
    
    
    class PsStack < Array
      def mark_index
        self.rindex(MARK)
      end
      
      def pop_to_mark
        idx = self.rindex(MARK)
        return nil unless idx
        self.pop(self.size - idx)[1..-1]  # remove MARK
      end
      
      def to_s
        contents = self.collect{|item|item.to_s}.join(' ')
        "[#{contents}]"
      end
    end
    
    module PsObject
      attr_accessor :executable
      
      def initialize(*args)
        super
        @executable = false
        #@readable = true
        #@writable = true
      end
      
      #def readonly!
      #end
      #
      #def executeonly!
      #end
      #
      #def readable?
      #end
      #
      #def excutable?
      #end
    end
    
    class PsNull
      include PsObject
      def initialize; super end
      def to_string; 'null' end
      def to_s; '--notstringval--' end
    end
    
    # For some copy operators in PostScript
    class PsSequence
      include PsObject
      
      def initialize(array, idx=nil, len=nil)
        super()
        @buffer = array
        unless idx
          # root object
          raise TypeError, "expected Array, but #{array.class} given" unless array.kind_of?(Array)
          @idx, @len = 0, array.size
        else
          # array is parent's buffer
          max_len = array.size
          raise RangeCheck if (idx < 0 || max_len < idx)
          raise RangeCheck if (len < 0 || max_len < idx + len)
          @idx = idx
          @len = max_len < len + idx ? max_len : len
        end
      end
      
      def size; @len end
      
      include Enumerable
      def each
        block_given? ? @buffer.each(&proc) : @buffer.each
      end
      
      def put(idx, val)
        raise RangeCheck unless (0...size).include?(idx)
        @buffer[idx + @idx] = val
      end
      
      def get(idx)
        raise RangeCheck unless (0...size).include?(idx)
        @buffer[idx + @idx]
      end
      
      alias []  get
      alias []= put
      
      def put_interval(idx, val)
        raise RangeCheck if idx < 0
        raise RangeCheck if size < idx + val.size
        @buffer[idx + @idx, val.size] = val
      end
      
      def get_interval(idx, len)
        self.class.new(@buffer, idx, len)
      end
      
      # called from copy operator (except for integer argument)
      def copy
        raise NotImplementedError, "must be overrided"
      end
      
      # called from ==/pstack operator
      def to_string
        raise NotImplementedError, "must be overrided"
      end
      
      # called from =/stack/print(for string) operator
      def to_s
        '--nostringval--'
      end
      
    end
    
    # string as byte buffer
    # any slicing method returns an instabce holding same buffer with diffrence start/end position
    class PsString < PsSequence
      def initialize(str, idx=nil, len=nil)
        unless idx
          # from string
          super(str.bytes)
        else
          # str is parent's buffer
          super
        end
      end
      
      def empty?; @len == 0 end
      
      include Comparable
      def <=>(other)
        self.to_s <=> other.to_s
      end
      
      def put(idx, val)
        raise RangeCheck unless (0..255).include?(val)
        super
      end
      
      def put_interval(idx, val)
        val = val.bytes if val.kind_of?(self.class)
        super(idx, val)
      end
      
      def copy
        self.class.new(to_s)
      end
      
      # in ghost script, interpreter returns
      # whole length of string as pritable chars
      # or octal numbers; for example
      # <42420000> == % => (BB\000\000)
      # in this implementation, however,
      # return value is pritable chars
      # and *hexadecimal* numbers
      def to_string
        "(#{to_s.inspect[1..-2]})"
      end
      
      def bytes
        @buffer[@idx,@len]
      end
      
      def succ
        buf = @buffer[@idx,@len]
        carry = true
        buf = buf.reverse.collect {|i|
          i += 1 if carry
          if 255 < i
            carry = true
            i % 256
          else
            carry = false
            i
          end
        }.reverse
        self.class.new(buf.collect(&:chr).join)
      end
      
      def to_s
        @buffer[@idx,@len].collect(&:chr).join
      end
      
      def inspect
        s = self.to_s.encode('us-ascii', :invalid => :replace, :undef => :replace, :replace => '')
        "(#{s})"
      end
      
      def to_integer(bigendian=true)
        b = bytes
        n = 0
        if bigendian
          b.each {|x| n = (n << 8) | x }
        else
          b.reverse_each {|x| n = (n << 8) | x }
        end
        n
      end
      
    end
    
    class PsArray < PsSequence
      def copy
        self.class.new(@buffer.dup, @idx, @len)
      end
      
      def to_string
        "[#{concat}]"
      end
      
      def to_execarray
        ExecArray.new(@buffer, @idx, @len)
      end
      
      def inspect
        to_string
      end
      
      private
      def concat
        @buffer[@idx,@len].collect {|item|
          case item
          when nil    then 'null'
          when Symbol then item.inspect
          else
            item.respond_to?(:to_string) ? item.to_string : item.to_s
          end
        }.join(' ')
      end
    end
    
    class ExecArray < PsArray
      def initialize(ops, *args)
        super(ops, *args)
        @executable = true
      end
      
      def get_interval(idx, len)
        self.class.new(@parser, @buffer, idx, len)
      end
      
      def copy
        self.class.new(@parser, @buffer.dup, @idx, @len)
      end
      
      def to_string
        "{#{concat}}"
      end
      
      def call(parser)
        parser.send(:exec_proc, self)
      end
      
      def to_psarray
        PsArray.new(@buffer, @idx, @len)
      end
      
      def to_execarray
        self
      end
      
    end
    
    class PsDict < Hash
      include PsObject
      
      def self.[](*key_and_values)
        ref = super
        dict = self.new
        ref.each do |k, v|
          k = k.intern if k.kind_of?(LiteralName)
          dict[k] = v
        end
        dict
      end
      
      def initialize
        super
        default_proc = Proc.new {|hash, key| key = key.intern if key.kind_of?(LiteralName); hash[key]}
      end
      
      def has_key?(key)
        key.kind_of?(LiteralName) ? super(key.intern) : super
      end
      
      alias :include? :has_key?
      alias :key? :has_key?
      alias :member? :has_key?
      
      def capacity
        case @capacity <=> self.size
        when -1, nil
          @capacity = self.size
        when 0, 1
          # do nothing
        end
        @capacity
      end
      
      def capacity=(n)
        @capacity = n
      end
      
      def to_string
        '-dict-'
      end
      
      def to_s
        '--notstringval--'
      end
    end
    
    class Mark_
      def to_string; '-mark-' end
      def to_s; '--notstringval--' end
      def inspect; to_string end
    end
    
    class LiteralName
      include PsObject
      
      attr_reader :name
      
      def initialize(symbol)
        super()
        @name = symbol.intern
      end
      
      def to_string; "/#{@name}" end
      
      def to_s; @name.to_s end
      
      def intern; @name end
      
      def inspect
        to_string
      end
      
      def hash; @name.hash end
      
      def eql?(other)
        case other
        when Symbol then @name == other
        when LiteralName then @name == other.name
        else false
        end
      end
      
      alias == eql?
      
    end
    
    class IEName
      def initialize(symbol)
        @name = symbol.intern
      end
      def to_s; "//#{@name}" end
      def inspect; to_s end
      def intern; @name end
    end
    
    MARK = Mark_.new
    
  end
  
end

