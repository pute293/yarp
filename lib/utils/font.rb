require 'thread'
require 'yaml'
require 'stringio'
require 'pathname'

module PDF::Utils
  module Font
    
    class InvalidFontFormat < StandardError; end
    
    # hash of { "font_name" => "font_path" }
    FontCache = ConcurrentHash.new
    class << FontCache
      def done?; @done ||= false end
      def done!; @done = true end
      def update; update_async.join end
      
      def FontCache.update_async
        @done = false
        Thread.new(self, PDF.Config.fetch('font-path')) do |hash, font_path|
          puts 'updating font cache...'
          font_path.each do |path|
            path = Pathname.new(path)
            Dir.glob(path + '**/*') do |f|
              next unless FileTest.file?(f)
              begin
                font = Font.new(f)
                if font.kind_of?(Enumerable)
                  # TrueType Collection
                  font.each {|fnt|fnt.fullname.each{|name|hash[name.encoding == ::Encoding::UTF_8 ? name : name.b] = f; puts "font \"#{name.encode('UTF-8')}\" => #{f}"}}
                else
                  font.fullname.each{|name|hash[name.encoding == ::Encoding::UTF_8 ? name : name.b] = f; puts "font \"#{name.encode('UTF-8')}\" => #{f}"}
                end
              rescue InvalidFontFormat
                next
              rescue
                warn "exception: #{$!}"
                warn "exception is occurred on processing #{f}; this font file (?) will be ignored"
                next
              rescue Exception
                warn 'fatal error:'
                raise
              end
            end
          end
          
          yaml_path = "#{__dir__}/fontcache.yaml"
          File.open(yaml_path, 'wb') {|yaml|
            yaml.puts '# font name => installed font path'
            YAML.dump(hash.to_hash, yaml)
          } rescue warn "fatal error:\nfail to open #{yaml_path}"
          @done = true
        end
      end
    end
    
    YAML.load_file("#{__dir__}/fontcache.yaml").each{|font, path| FontCache[font] = path}
    FontCache.done!
    
    # arg: string or IO
    def self.new(arg, autoclose: false)
      io = case arg
      when String
        begin
          # path
          font = open(arg, 'rb:ASCII-8BIT')
          autoclose = true
          font
        rescue
          # binary
          StringIO.new(arg, 'rb:ASCII-8BIT')
        end
      when IO, StringIO
        arg
      else raise ArgumentError, "expected string or IO, but #{arg.class} given"
      end
      
      args = [io]
      
      magic = nil
      cff = false
      
      origin = io.pos
      magic = io.read(4)
      cff = /CFF / =~ io.read(1024)
      io.seek(origin)
      
      klass = case magic
      when 'ttcf' then TrueTypeCollection
      when 'true' then TrueType
      when 'OTTO' then OpenType
      when "\x00\x01\x00\x00"
        cff ? OpenType : TrueType
      else
        header = magic.unpack('nC2')
        if header[0] == 0x100 && (1..4).include?(header[2]) # when this is cff file, first 2 bytes are major/minor version (should be 1/0) and byte of offset 3 is offSize (1..4 integer)
          Type2
        elsif 0x20 <= magic[0].ord  # started with printable characters; which means this file may be PostScript
          ps = PDF::Parser::PostScriptParser.new
          if header[0] == 0x8001
            # type1 binary file (pfb)
            ps.binmode
            script = ''.b
            magic, header_size = io.read(6).unpack('nV')
            script += io.read(header_size)
            magic, body_size = io.read(6).unpack('nV')
            script += io.read(body_size)
            magic, tail_size = io.read(6).unpack('nV')
            script += io.read(tail_size)
          else
            # type1 ascii file (pfa)
            script = io.read
          end
          
          fonts = ps.resources[:Font]
          begin
            ps.resources[:Font].clear
            ps.parse(script)
            font = ps.resources.fetch(:Font)
            fontname, fontdict  = font.shift
            type = fontdict ? fontdict[:FontType] : nil
            raise InvalidFontFormat, 'unknown font type' unless (fontname && type)
            args.push(fontdict)
            case type
            when 1 then Type1
            when 3 then Type3
            else raise InvalidFontFormat, 'unknown font type'
            end
            #raise InvalidFontFormat, 'PostScript Font (Type1, Multiple Master Type1, Type3 or Type42'
          rescue => e
            #raise
            ps.resources[:Font] = fonts
            e.kind_of?(InvalidFontFormat) ? raise : (raise InvalidFontFormat, 'unknown font type')
          end
          #Type1 # or MMType1, Type3, Type42
        else raise InvalidFontFormat, 'not a font file'
        end
      end
      
      obj = klass.new(*args)
      ObjectSpace.define_finalizer(obj) { io.close } if autoclose
      obj
    end
    
    ReCMapName = Regexp.union(Dir.glob("#{__dir__}/encoding/code2cid/*").collect{|f| File.basename(f)}.reject{|f| /^!/ =~ f}.collect{|f| /-#{f}$/})
    
    def self.search(font_names)
      font_names = font_names.collect{|name|
        name.sub!(/^(\w{6}\+)+/, '')  # remove embedded mark (they are sometimes included more than one in font name)
        name.sub!(ReCMapName, '')     # remove CMap name (they are sometimes included in font name)
        name.gsub!(/#([[:xdigit:]][[:xdigit:]])/){$1.to_i(16).chr} while /#[[:xdigit:]][[:xdigit:]]/ =~ name
        name.gsub(/\s*,\s*/, ' ').gsub(/\s+/, ' ')
      }.uniq
      font_name = font_names.find{|name| FontCache[name]}
      return nil unless font_name
      path = FontCache[font_name]
      font = self.new(path)
      if font.kind_of?(Enumerable)
        font = font.find{|fnt| fnt.fullname.any?{|fullname| fullname.bytes == font_name.bytes}}
      end
      font
    end
    
  end
end

require_relative 'font/fontbase'
require_relative 'font/cff'
require_relative 'font/psfont'
require_relative 'font/truetype'
require_relative 'font/truetypecollection'
require_relative 'font/opentype'
