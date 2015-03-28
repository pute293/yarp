# coding: utf-8

require 'strscan'
require_relative 'ops.tab'
require_relative 'ops.lex'
require_relative 'graphicstate'

module PDF::Parser
  class OperationParser
    
    include PDF::Utils
    
    def self.parse(str)
      ps = self.new
      ps.parse(str)
    end
    
    def self.try_parse(str)
      return nil unless str.kind_of?(String)
      ps = self.new
      ps.try_parse(str)
    end
    
    def initialize
      #@yydebug = true
      @bx = false
      @scanner = nil
      @gs_stack = [PDF::GraphicState.new]
      @op_handler = {}
    end
    
    def parse(str)
      @scanner = StringScanner.new(str)
      yyparse(self, :parse_stream)
    end
    
    def try_parse(str)
      return nil unless str.kind_of?(String)
      begin
        parse(str)
      rescue ParseError
        nil
      end
    end
    
    def exec(ops)
      ops = ops.dup
      stack = @gs_stack
      gs = stack.last
      ts = gs.ts
      until ops.empty?
        h = ops.shift
        op, args = h[:op], h[:args]
        op = op.intern
        
        if @op_handler.has_key?(op)
          args = @op_handler[op].call(gs, ts, *args)
          next unless args
        end
        
        case op
        when :q
          stack.push(gs)
          gs = gs.dup
          ts = gs.ts
        when :Q
          raise ParseError, 'unmatched Q operator' if stack.size == 1
          gs = stack.pop
          ts = gs.ts
        when :BT then ts.tm.identity!
        when :cm
          mat = Mat3.new(args[0], args[1], 0, args[2], args[3], 0, args[4], args[5], 1)
          gs.ctm *= mat
        when :Td
          mat = Mat3.new
          mat.tx, mat.ty = args[0].to_f, args[1].to_f
          ts.tm = ts.tlm = mat * ts.tlm
        when :TD
          args = args.collect(&:to_f)
          ops.unshift({:op => :TL, :args => [-args[1]]}, {:op => :Td, :args => args})
        when :Tm
          mat = Mat3.new(args[0], args[1], 0, args[2], args[3], 0, args[4], args[5], 1)
          ts.tm = ts.tlm = mat
        when :'T*'
          ops.unshift({:op => :Td, :args => [0, -ts.l]})
        when :Tc then ts.c = args[0].to_f
        when :Tw then ts.w = args[0].to_f
        when :Tz then ts.h = args[0] / 100.0
        when :TL then ts.l = args[0].to_f
        when :Tf then ts.font, ts.fs = *args
        when :Tr then ts.mode = args[0].to_i
        when :Ts then ts.rise = args[0].to_f
        when :"'"
          ops.unshift({:op => :'T*', :args => []}, {:op => :Tj, :args => args})
        when :'"'
          ts.w, ts.c = args[0].to_f, args[1].to_f
          ops.unshift({:op => :'T*', :args => []}, {:op => :Tj, :args => [args[2]]})
        end
      end
      raise ParseError, 'unmatched q/Q operator' if stack.size != 1
    end
    
    def add_handler(op, fn)
      @op_handler[op.intern] = fn
    end
    
    def remove_handler(op)
      @op_handler.remove(op.intern)
    end
    
    def clear_handler
      @op_handler = {}
    end
    
    include ParserBase
    
  end
end
