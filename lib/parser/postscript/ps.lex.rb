# coding: utf-8

module YARP::Parser
  class PostScriptParser
    
    RE_OPS = /\A[^#{PDF_WORD_BREAK}]+/n
    
    def parse_stream
      until (scanner.nil? || scanner.eos?)
        s = scanner
        case
        when s.scan(RE_PDF_WS)
        when s.scan(RE_PDF_COMMENT)
          #warn "$ comment: #{$&}"
        when s.scan(RE_PDF_TRUE)
          yield [:PS_TRUE, true]
        when s.scan(RE_PDF_FALSE)
          yield [:PS_FALSE, false]
        when s.scan(RE_PDF_NULL)
          yield [:PS_NULL, nil]
        when s.scan(RE_PS_INT)
          yield [:PS_NUM_INT, s[2].to_i(s[1].to_i)]
        when s.scan(RE_PS_REAL1), s.scan(RE_PS_REAL2)
          yield [:PS_NUM_REAL, s[0].to_f]
        when s.scan(RE_PDF_REAL1), s.scan(RE_PDF_REAL2)
          yield [:PS_NUM_REAL, s[0].to_f]
        when s.scan(RE_PDF_INT)
          yield [:PS_NUM_INT, s[0].to_i]
        when s.scan(RE_PS_IEN)
          n = s[0][2..-1].gsub(/#([[:xdigit:]][[:xdigit:]])/) {|n| $1.to_i(16).chr}
          yield [:PS_IEN, IEName.new(n)]
        when s.scan(RE_PDF_NAME)
          n = s[0][1..-1].gsub(/#([[:xdigit:]][[:xdigit:]])/) {|n| $1.to_i(16).chr}
          yield [:PS_NAME, LiteralName.new(n)]
        when s.scan(RE_PDF_D1)
          yield [:PS_MARK, :<<]
        when s.scan(RE_PDF_D2)
          yield [:PS_OP, :>>]
        when s.scan(RE_PDF_A1)
          yield [:PS_MARK, :'[']
        when s.scan(RE_PDF_A2)
          yield [:PS_OP, :']']
        when s.scan(RE_PS_P1)
          yield [:PS_PROC_START, :'{']
        when s.scan(RE_PS_P2)
          yield [:PS_PROC_END, :'}']
        when s.scan(RE_PDF_SL)
          # parse string
          str = s[0][1..-2].gsub(/\r\n?/, "\n").gsub(/\\\n/, '') # normalize line feeds
          str.gsub!(/\\\d{1,3}/) {|m| m[1..-1].to_i(8).chr}   # \ddd => char
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
          yield [:PS_STRL_L, nil]
          yield [:PS_STR_ASCII, str]
          yield [:PS_STRL_R, nil]
        when s.scan(RE_PDF_SH)
          str = s[0][1..-2].delete(PDF_WHITE_SPACE)
          str += '0' if str.size.odd?
          str = str.scan(/../).collect{|x|x.to_i(16).chr}.join
          yield [:PS_STRH_L, nil]
          yield [:PS_STR_HEX, str]
          yield [:PS_STRH_R, nil]
        when s.scan(RE_OPS)
          yield [:PS_OP, s[0].intern]
        else
          r = s.rest
          on_error("pos = #{s.pos}, buffer = \"#{r.bytesize < 1024 ? r : (r[0,1024] + ' ...')}\"")
        end
      end
      yield [false, nil]
    end
    
  end
end

