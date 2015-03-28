# coding: utf-8

require 'strscan'
require_relative 'ps.tab'
require_relative 'ps.lex'
require_relative 'misc/object'

module YARP::Parser
  
  class PostScriptParser
    include ParserBase
    
    # for currentfile operator, extend StringScanner to IO-like object
    class IOScanner < StringScanner
      
      attr_accessor :parent, :kids
      
      def initialize(*args)
        super
        @kids = []
      end
      
      alias :eof? :eos?
      
      def read(len=nil)
        # Skip first byte if it is a white-space (CRLF is processed as one character)
        scan(/\r\n|\s/)
        if len
          scan(/[\x00-\xff]{#{len}}/n)
          self[0]
        else rest
        end
      end
      
      def readline
        # Skip first byte if it is a white-space (CRLF is processed as one character)
        scan(/\r\n|\s/)
        scan(/.+?(\r\n|\n|\r|\z)/)
      end
      
      def to_string; '-file-' end
      
      def to_s; '--nostringval--' end
    end
    
    @@strict = false
    @@systemdict = nil
    @@resources = Hash.new {|h, key| h[key] = {}}
    
    # for some arithmetic operators
    @@random = Random.new(1)
    
    def initialize(str=nil)
      self.class.create_systemdict unless @@systemdict
      reset
      @scanners.push(IOScanner.new(str)) if str
      parse unless @scanners.empty?
    end
    
    def currentdict; @dicts.last end
    def systemdict; @@systemdict end
    def resources; @@resources end
    def operand_stack; @ops end
    def dictionary_stack; @dicts end
    def execution_stack; @scanners end
    def strict?; self.class.strict? end
    def strict=(bool); self.class.strict = !!bool end
    def scanner; @scanners.last end
    def binmode; @binmode = true end
    def binmode=(bool); @binmode = !!bool end
    def binmode?; @binmode end
    
    attr_accessor :loop_depth, :exit_flag
    
    def parse(str=nil)
      @scanners.push(IOScanner.new(str)) if str
      raise ArgumentError, 'nothing to parse' if @scanners.empty?
      begin
        until @scanners.empty?
          yyparse(self, :parse_stream)
          @scanners.pop
        end
      rescue QuitCalled
        reset
      rescue PostScriptError => e
        YARP.warn "PostScript Error: pos = #{scanner.pos}"
        YARP.warn e
        YARP.warn 'Operand Stack:'
        ops = @ops.collect {|op| op.respond_to?(:to_string) ? op.to_string : op.to_s }
        YARP.warn "    |- #{ops.join(' ')}"
        #YARP.warn '===================================='
        #YARP.warn @str
        #YARP.warn '===================================='
        raise
      end
    end
    
    def reset
      @scanners = []
      @ops = PsStack.new    # operand stack
      user_dict = PsDict.new
      user_dict.capacity = 200  # for gs comapibility
      @dicts = [user_dict]  # dictionary stack
      @proc_stack = []      # operand stack of inner { ... } block; each { ... } block creates an array and pushed to this
      @loop_depth = 0       # used by exit operator
      @exit_flag = false    # used by exit operator
      @binmode = false
    end
    
    private
    
    def load_name(name)
      @dicts.reverse_each {|dict| return dict[name] if dict.has_key?(name)}
      return @@systemdict[name] if @@systemdict.has_key?(name)
      if self.class.strict?
        puts name.to_s.bytes.collect{|x|'%02x'%x}.join(' ')
        raise Undefined, "Name \"#{name}\" is not defined"
      else
        YARP.warn "!!! WARN !!! Name \"#{name}\" is not defined; processed as Name"
        name
      end
    end
    
    def op_push(op)
      op = PsNull.new if op.nil?
      if @proc_stack.empty?
        @ops.push(op)
      else
        @proc_stack.last.push(op)
      end
    end
    
    def on_operation(op)
      if @proc_stack.empty?
        exec_op(op)
      else
        @proc_stack.last.push(op)
      end
    end
    
    def on_iename(op)
      load_name(op.intern)
    end
    
    def exec_op(op)
      op = load_name(op)
      case op
      when Proc, ExecArray
        op.call(self)
      else op_push(op)
      end
    end
    
    def exec_proc(exec_array)
      exec_array.each do |op|
        if op.kind_of?(Symbol)
          exec_op(op)
        else
          op_push(op)
        end
      end
    end
    
    def enter_proc
      @proc_stack.push([])
    end
    
    def exit_proc
      raise SyntaxError, 'unmatched }' if @proc_stack.empty?
      ops = @proc_stack.pop
      ExecArray.new(ops)
    end
    
    class << self
      attr_reader :systemdict, :resources
      
      def strict?; @@strict end
      
      def strict=(bool) @@strict = !!bool end
      
      def create_systemdict
        path = File.expand_path('../misc/operator.rb', __FILE__)
        @@systemdict = create_resource(path, PsDict.new)
        @@systemdict.capacity = @@systemdict.size
        @@systemdict.freeze
      end
      
      def find_resource(category, key)
        category = category.to_s.intern
        key = key.to_s.intern
        cat = @@resources[category]
        return cat[key] if cat.has_key?(key)
        
        path = File.expand_path("../misc/resources/#{category}/#{key}.rb", __FILE__)
        raise Undefined, 'resource not found' unless FileTest.file?(path)
        rc = PsDict.new
        create_resource(path, rc)
        rc.freeze
        cat[key] = rc
      end
      
      def create_resource(path, dict)
        @defop_dict = dict
        eval(File.read(path))
        @defop_dict = nil
        dict
      end
      
      def defop(op, argc, types, fn)
        operator = lambda do |parser|
          stack = parser.operand_stack
          args = nil
          begin
            if argc == MARK
              args = stack.pop_to_mark
              raise UnmatchedMark, "unmatched #{op}" unless args
            elsif stack.size < argc
              raise StackUnderFlow, "in #{op}; stack count expected #{argc}, but #{stack.size}"
            else
              args = stack.pop(argc)
            end
            args.zip(types).each do |arg, type|
              case type
              when Symbol
                raise TypeCheck, "in #{op}; #{type} method expected; but #{arg.class} given" unless arg.respond_to?(type)
              when Array
                str = type.collect{|t|t.to_s}.join('/')
                if type.all?{|t|t.kind_of?(Class)}
                  raise TypeCheck, "in #{op}; #{str} expected; but #{arg.class} given" if type.none?{|t|arg.kind_of?(t)}
                else
                  raise TypeCheck, "in #{op}; #{str} expected; but #{arg} given" unless type.include?(arg)
                end
              when Class
                raise TypeCheck, "in #{op}; #{type} expected; but #{arg.class} given" unless arg.kind_of?(type)
              when nil
                # pass through
              else raise "must not happen"
              end
            end
          rescue PostScriptError
            stack.push(*args) if args
            #mes = e.message.gsub(e.class.to_s, '')
            #raise e.class, "#{mes} --#{op}--", e.backtrace
            raise
          end
          begin
            fn.call(parser, args, stack)
          rescue PostScriptError => e
            stack.push(*args)
            e.op = operator.to_s
            raise
          end
        end
        operator.instance_eval {
          @op_name = op
          @executable = true
          def to_s; "--#{@op_name}--" end
          def inspect; to_s end
          def op_name; @op_name end
          def executable; @executable end
          def executable=(b); @executable = !!b end
        }
        @defop_dict[op.intern] = operator
      end
    end
    
  end
  
end


# test
=begin
ps = YARP::Parser::PostScriptParser.new
s0 = <<EOS
/fact {
1 dict begin
/n exch def
n 0 eq { 1 } {
n 1 ge { n n 1 sub fact mul }
{ (undefined) } ifelse } ifelse
end
} def
5 fact pp
EOS
s1 = <<EOS
/CIDInit/ProcSet findresource begin
12 dict begin
begincmap
/CIDSystemInfo<<
/Registry (Adobe)
/Ordering (UCS)
/Supplement 0
>> def
/CMapName/Adobe-Identity-UCS def
/CMapType 2 def
1 begincodespacerange
<00> <FF>
endcodespacerange
1 beginbfchar
<01> <3042>
endbfchar
endcmap
CMapName currentdict /CMap defineresource pop
end
end
EOS
s2 = <<EOS
/CIDInit/ProcSet findresource begin
12 dict begin
begincmap
/CIDSystemInfo<<
/Registry (Adobe)
/Ordering (UCS)
/Supplement 0
>> def
/CMapName/Adobe-Identity-UCS2 def
/CMapType 2 def
1 begincodespacerange
<00> <FF>
endcodespacerange
1 beginbfchar
<01> <3042>
endbfchar
endcmap
CMapName currentdict /CMap defineresource pop
end
end
EOS
ps.parse(s0)
ps.reset
ps.parse(s1)
ps.reset
ps.parse(s2)
p ps.resources

YARP.warning = true
ps = YARP::Parser::PostScriptParser.new
ps.parse(<<EOS)
/{(vvv)==}def
/ cvx exec
/a(abbc)def
a(ab)search pp
clear
a(bb)search pp
clear
a(bc)search pp
clear
a(B)search pp
clear
() =
a(ab)anchorsearch pp
clear
a(bb)anchorsearch pp
clear
a(bc)anchorsearch pp
clear
a(B)anchorsearch pp
clear
EOS
YARP.warning = true
ps = YARP::Parser::PostScriptParser.new
ps.parse(<<EOS)
/X{
    true
    {
        (aaa)show
        currentfile 80 string readline pop
        1 1 index length 1 sub getinterval show
    }
    {(bbb)show}
    count{exch}repeat ifelse
} def
/{
    (ccc)show
}def
/_{
    cvx exec
}def
X / _ / X < ddd
EOS
puts
p ps.operand_stack
p ps.currentdict

YARP.warning = true
ps = YARP::Parser::PostScriptParser.new
ps.strict = true
#ps.parse("/a cvx pp cvlit pp cvx pp cvx pp")
#ps.parse("/a load")
#ps.parse("({ 0 1 2 }) cvx exec pp")
#s="<</a 1 /b 2>> dup /a get == /a cvx get =="
require 'pp'
s=IO.binread("#{__dir__}/../../../embedded_scary.txt")
ps.parse(s)
#p ps.operand_stack
k,v=ps.resources[:Font].shift
p v.keys
pp v[:Private]
=end
