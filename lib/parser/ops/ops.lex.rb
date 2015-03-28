# coding: utf-8

module YARP::Parser
  class OperationParser
    
    RE_OPS    = /\A[^#{PDF_WORD_BREAK}]+/n
    RE_OP_EI  = /(?<=[#{PDF_WORD_BREAK}])EI#{PDF_WB}/n
    
    # operator, num_of_operands (nil means variable parameters)
    OPS_TABLE = [
      # table 32, compatibility ops
      ['BX', 0],
      ['EX', 0],
      # table 57, graphic state ops
      ['q', 0],
      ['Q', 0],
      ['cm', 6],
      ['w', 1],
      ['J', 1],
      ['j', 1],
      ['M', 1],
      ['d', 2],
      ['ri', 1],
      ['i', 1],
      ['gs', 1],
      # table 59, path construction ops
      ['m', 2],
      ['l', 2],
      ['c', 6],
      ['v', 4],
      ['y', 4],
      ['h', 0],
      ['re', 4],
      # table 60, path painting ops
      ['S', 0],
      ['s', 0],
      ['f', 0],
      ['F', 0],
      ['f*', 0],
      ['B', 0],
      ['B*', 0],
      ['b', 0],
      ['b*', 0],
      ['n', 0],
      # table 61, clipping path ops
      ['W', 0],
      ['W*', 0],
      # table 74, colour ops
      ['CS', 1],
      ['cs', 1],
      ['SC', nil],
      ['SCN', nil],
      ['sc', nil],
      ['scn', nil],
      ['G', 1],
      ['g', 1],
      ['RG', 3],
      ['rg', 3],
      ['K', 4],
      ['k', 4],
      # table 77, shading ops
      ['sh', 1],
      # table 87, xobject ops
      ['Do', 1],
      # table 92, inline image ops
      ['BI', 0],
      ['ID', 0],
      ['EI', 0],
      # table 105, text state ops
      ['Tc', 1],
      ['Tw', 1],
      ['Tz', 1],
      ['TL', 1],
      ['Tf', 2],
      ['Tr', 1],
      ['Ts', 1],
      # table 107, text object ops
      ['BT', 0],
      ['ET', 0],
      # table 108, text-positioning ops
      ['Td', 2],
      ['TD', 2],
      ['Tm', 6],
      ['T*', 0],
      # table 109, text-showing ops
      ['Tj', 1],
      ["'", 1],
      ['"', 3],
      ['TJ', 1],
      # table 113, type 3 font ops
      ['d0', 2],
      ['d1', 6],
      # table 320, marked-content ops
      ['MP', 1],
      ['DP', 2],
      ['BMC', 1],
      ['BDC', 2],
      ['EMC', 0]
    ]
    
    # define regexp of ops
    OPS = OPS_TABLE.collect {|op, n|
      re_op = Regexp.quote(op)
      re = /\A#{re_op}#{PDF_WB}/
      [op.intern, n, re]
    }.sort{|a,b|b[0].size <=> a[0].size}
    
    def parse_stream
      s = @scanner
      until s.eos?
        case
        when s.scan(RE_PDF_WS)
        when s.scan(RE_PDF_COMMENT)
          #warn "$ comment: #{$&}"
        when s.scan(RE_PDF_TRUE)
          yield [:PDF_TRUE, true]
        when s.scan(RE_PDF_FALSE)
          yield [:PDF_FALSE, false]
        when s.scan(RE_PDF_NULL)
          yield [:PDF_NULL, nil]
        when s.scan(RE_PDF_REAL1), s.scan(RE_PDF_REAL2)
          yield [:PDF_NUM_REAL, s[0].to_f]
        when s.scan(RE_PDF_INT)
          yield [:PDF_NUM_INT, s[0].to_i]
        when s.scan(RE_PDF_NAME)
          n = s[0][1..-1].gsub(/#([[:xdigit:]][[:xdigit:]])/) {|n| $1.to_i(16).chr}
          yield [:PDF_NAME, n.intern]
        when s.scan(RE_PDF_D1)
          yield [:PDF_DICT_L, nil]
        when s.scan(RE_PDF_D2)
          yield [:PDF_DICT_R, nil]
        when s.scan(RE_PDF_A1)
          yield [:PDF_ARRAY_L, nil]
        when s.scan(RE_PDF_A2)
          yield [:PDF_ARRAY_R, nil]
        when s.scan(RE_PDF_SL)
          # parse string
          str = s[0][1..-2].gsub(/\r\n?/, "\n").gsub(/\\\n/, '') # normalize line feeds
          str.gsub!(/(?<!\\)\\\d{1,3}/) {|m| m[1..-1].to_i(8).chr}   # \ddd => char
          str.gsub!(/\\([\x00-\xff])/n) {                     # escape sequence
            case $1
            when 'n' then "\n"
            when 'r' then "\r"
            when 't' then "\t"
            when 'b' then "\b"
            when 'f' then "\f"
            when '(' then '('
            when ')' then ')'
            when "\\" then "\x5c"
            else $1   # ignore REVERSE SOLIDUS 
            end
          }
          yield [:PDF_STRL_L, nil]
          yield [:PDF_STR_ASCII, str]
          yield [:PDF_STRL_R, nil]
        when s.scan(RE_PDF_SH)
          str = s[0][1..-2].delete(PDF_WHITE_SPACE)
          str += '0' if str.size.odd?
          str = str.scan(/../).collect{|x|x.to_i(16).chr}.join
          yield [:PDF_STRH_L, nil]
          yield [:PDF_STR_HEX, str]
          yield [:PDF_STRH_R, nil]
        else
          ops = parse_ops
          if ops.nil?
            on_error("buffer = \"#{s.rest}\"")
          else
            ops.each {|token, val| yield [token, val]}
          end
        end
      end
      yield [false, nil]
    end
    
    private
    
    def parse_ops
      s = @scanner
      OPS.each do |op, n, re|
        matched = s.scan(re)
        next unless matched
        case op
        when :BX
          @bx = true
          return [[:PDF_OP, [:BX, 0]]]
        when :EX
          @bx = false
          return [[:PDF_OP, [:EX, 0]]]
        when :BI
          return [[:PDF_OP, [:BI, 0]], [:PDF_DICT_L, nil]]
        when :ID
          #   v here now
          # ID.....EI...
          data = s.scan_until(RE_OP_EI)
          #          v here now
          # ID.....EI...
          #   |~~~~~| = data
          return nil unless data
          return [[:PDF_DICT_R, nil], [:PDF_OP_ID, data[0..-3]], [:PDF_OP, [:EI, nil]]]
        else
          return [[:PDF_OP, [op, n]]]
        end
      end
      
      # operator not found
      if @bx
        # in BX field; search any keyword-like token
        op = s.scan(RE_OPS)
        op.nil? ? nil : [:PDF_OP, [op.intern, nil]]
      else
        nil
      end
    end
    
  end
end

