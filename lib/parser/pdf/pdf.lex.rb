module YARP::Parser
  class ObjectParser
    
    # parse one object (num gen obj ... endobj) or xref table (xref ... trailer << ... >>)
    def parse_obj
      @accepted = false
      io = @io
      add_buf = Proc.new {|str|
        new_buf = io.read(512)
        if str.nil?
          # return empty string if eof
          new_buf || ''
        else
          # raise error if eof
          unless new_buf
            str = "; #{str}" if str
            on_error("unexpected eof#{str}") if new_buf.nil?
          else
            new_buf
          end
        end
      }
      buf = io.read(512)
      while true
        # keep buffer size greater than 512 except for EOF
        # so RE_PDF_INT always matches lexical integer, neither obj nor ref
        buf << add_buf.call if buf.size < 512
        #p buf[0,10]
        case buf
        when RE_PDF_WS
          buf = $'
        when RE_PDF_COMMENT
          #warn "$ comment: #{$&}"
          buf = $'
        when RE_PDF_TRUE
          buf = $'
          yield [:PDF_TRUE, true]
        when RE_PDF_FALSE
          buf = $'
          yield [:PDF_FALSE, false]
        when RE_PDF_NULL
          buf = $'
          yield [:PDF_NULL, nil]
        when RE_PDF_REAL1, RE_PDF_REAL2
          buf = $'
          yield [:PDF_NUM_REAL, $&.to_f]
        when RE_PDF_OBJ1
          buf = $'
          n, g = $1, $2
          yield [:PDF_OBJ, [n.to_i,g.to_i]]
        when RE_PDF_OBJ2
          yield [:PDF_OBJ_END, nil]
          #io.seek(-buf.size, IO::SEEK_CUR)
          yield [false, nil]
          @accepted = false
          break
        when RE_PDF_REF
          buf = $'
          yield [:PDF_REF, [$1.to_i, $2.to_i]]
        when RE_PDF_INT
          buf = $'
          yield [:PDF_NUM_INT, $&.to_i]
        when RE_PDF_NAME
          buf = $'
          n = $&[1..-1].gsub(/#([[:xdigit:]][[:xdigit:]])/) {|n| $1.to_i(16).chr}
          yield [:PDF_NAME, n.intern]
        when RE_PDF_D1
          buf = $'
          @last_dict = nil
          yield [:PDF_DICT_L, nil]
        when RE_PDF_D2
          buf = $'
          yield [:PDF_DICT_R, nil]
        when RE_PDF_A1
          buf = $'
          yield [:PDF_ARRAY_L, nil]
        when RE_PDF_A2
          buf = $'
          yield [:PDF_ARRAY_R, nil]
        when RE_PDF_SL
          buf = $'
          str = $&[1..-2].gsub(/\r\n?/, "\n").gsub(/\\\n/, '') # normalize line feeds
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
          yield [:PDF_STRL_L, nil]
          yield [:PDF_STR_ASCII, str]
          yield [:PDF_STRL_R, nil]
        when RE_PDF_SH
          buf = $'
          str = $&[1..-2].delete(PDF_WHITE_SPACE)
          str += '0' if str.bytesize.odd?
          str = str.scan(/../).collect{|x|x.to_i(16).chr}.join
          yield [:PDF_STRH_L, nil]
          yield [:PDF_STR_HEX, str]
          yield [:PDF_STRH_R, nil]
        when RE_PDF_STREAM1
          yield [:PDF_STREAM, nil]
          dict = @last_dict
            on_error('invalid stream; stream dictionary is not found') if dict.nil?
          len = dict[:Length]
          len = len.data if len.kind_of?(YARP::Ref)
            on_error('invalid stream; stream dictionary does not has Length field') if len.nil?
          pos = io.tell - $'.size   # start offset of stream content
          io.seek(pos + len)        # set io on end-of-stream
          buf = add_buf.call('invalid end-of-stream')
          @last_dict = nil
          yield [:STREAM_BYTES, pos]
        when RE_PDF_STREAM2
          buf = $'
          yield [:PDF_STREAM_END, nil]
          # TODO: sometimes 'endobj' is omitted
        when RE_PDF_XREF
          # xref table
          buf = $'
          hash = {}
          while true
            # xref table subsection
            RE_PDF_XREF_SUB1 =~ buf
            unless $&
              if buf.size < 5
                # buf size shotage
                buf += add_buf.call('unexpected end of xref table')
                next
              else
                # end-of-table; break while loop
                break
              end
            end
            s, n, buf = $1.to_i, $2.to_i, $'
            entry_size = n * 20
            buf << io.read(entry_size) if buf.size < entry_size
            n.times.each do |i|
              RE_PDF_XREF_SUB2 =~ buf
              buf = $'
              num = s + i
              gen = $2.to_i
              key = YARP::Ref.new(self, num, gen)
              hash[key] = {:offset => $1.to_i, :used => ($3 == 'n')}
            end
          end
          yield [:PDF_XREF_TABLE, hash]
        when RE_PDF_TRAILER
          buf = $'
          yield [:PDF_TRAILER, nil]
        else
          if @accepted
            # parsed xref table
            yield [false, nil]
            @accepted = false
            break
          elsif buf.empty?
            buf = add_buf.call
            if buf.empty?
              yield [false, nil]
              @accepted = false
              break
            end
          else
            buf += add_buf.call("buffer = \"#{buf.bytes.collect{|i|sprintf('%02x',i)}.join(' ')}\"")
          end
        end
      end
    end
    
  end
  
end
