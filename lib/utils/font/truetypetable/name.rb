module PDF::Utils::Font
  
  class TrueType
    
    class Name < Table
      NameIds = %i{
        CopyRight FamilyName FontFace UniqueID FullName Version PsName2
        TradeMark Vendor Designer Description VendorURL DesignerURL
        License LicenseURL Reserved FamilyName2 FontFace2 MacFullName
        SampleText PsName WWSFamilyName WWSFontFace
      }
      class << NameIds
        alias :'[]' :fetch
        alias :fetch_old :fetch
        def fetch(idx)
          (256..0x7fff).include?(idx) ? idx : self.fetch_old(idx)
        end
      end
      NameIds.freeze
      
      def self.decode(data, pid, eid, lcid)
        #raise NotImplementedError, "LCID #{lcid} is greater than 0x8000 (#{0x8000})" if 0x8000 <= lcid
        enc = case pid
        when :Unicode then 'UTF-16BE'
        when :Macintosh
          case eid
          when :Roman     then 'MacRoman'
          when :Japanese  then 'MacJapanese'
          #when :Chinese_Traditional then 
          when :Korean    then 'MacKorean'
          #when :Arabic then 
          #when :Hebrew then 
          #when :Greek     then 'MacGreek'
          #when :Russian then 
          #when :RSymbol then 
          #when :Devanagari then 
          #when :Gurmukhi then 
          #when :Gujarati then 
          #when :Oriya then 
          #when :Bengali then 
          #when :Tamil then 
          #when :Telugu then 
          #when :Kannada then 
          #when :Malayalam then 
          #when :Sinhalese then 
          #when :Burmese then 
          #when :Khmer then 
          #when :Thai then 
          #when :Laotian then 
          #when :Georgian then 
          #when :Armenian then 
          when :Chinese_Simplified then 'MacChineseSimplified'
          #when :Tibetan then 
          #when :Mongolian then 
          #when :Geez then 
          #when :Slavic then 
          #when :Vietnamese then 
          #when :Sindhi then 
          #when :Uninterpreted then
          else nil
          end
        when :ISO
          nil
        when :Windows
          case eid
          when :Symbol  then 'UTF-16BE'
          when :UCS_2   then 'UTF-16BE'
          #when :SJIS
          when :PRC     then 'BIG5-UAO'
          when :Big5    then 'BIG5-UAO'
          #when :Wansung
          #when :Johab
          #when :Reserved
          when :UCS_4   then 'UTF-16BE'
          else nil
          end
        when :Custom
          nil
        end
        #unless enc
        #  warn "#{pid}/#{eid}/#{lcid}; bytes = #{data.bytes.collect{|x|'%02x'%x}.join(' ')}"
        #  return ""
        #end
        raise NotImplementedError, "#{pid}/#{eid}/#{lcid}; bytes = #{data.bytes.collect{|x|'%02x'%x}.join(' ')}" unless enc
        data.dup.force_encoding(enc).encode('UTF-8').gsub(/\x00/, '')
      end
      
      def read_names(io)
        io.seek(offset)
        fmt, count, str_offset = io.read(6).unpack('n3')
        entries = io.read(count * 12).unpack('n*').each_slice(6)  # 12 is sizeof(NameRecord); NameRecord consists of 6 USHORT member
        if fmt == 1
          lang_count = io.us
          lang_entries = io.read(lang_count * 4).unpack('n*').each_slice(2)
        end
        origin = offset + str_offset
        entries.collect do |pid, eid, lcid, nameid, len, off|
          pid = PlatformIds.fetch(pid)
          eid = pid == :Custom ? eid : EncodingIds.fetch(pid).fetch(eid)
          nameid = NameIds.fetch(nameid)
          io.seek(origin + off)
          str = self.class.decode(io.read(len), pid, eid, lcid)
          {:pid => pid, :eid => eid, :lcid => lcid, :nameid => nameid, :data => str}
        end
      end
    end
    
  end
end
