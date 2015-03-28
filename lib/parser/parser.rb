# coding: utf-8

module PDF
  module Parser
    module ParserBase
      
      private
      
      def d(s)
        out = @racc_debug_out
        out.print(s) unless out.nil?
      end
      
      def warn(s)
        out = @racc_debug_out
        out.puts(s) unless out.nil?
      end
      
      def on_error(*args)
        if 0 < args.size && args[0].class == String
          raise ParseError, args[0]
        else
          super
        end
      end
      
    end
  end
end

require_relative 'constants'
require_relative 'pdf/parser'
require_relative 'ops/parser'
require_relative 'postscript/parser'
