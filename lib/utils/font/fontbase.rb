module PDF::Utils::Font
  
  class FontBase
    attr_accessor :embedded
    attr_reader :type, :fullname, :familyname, :glyphcount
    
    def get_cmaps; raise NotImplementedError, 'must be overrided' end
    def gid2name(*gids); raise NotImplementedError, 'must be overrided' end
    def name2gid(*names); raise NotImplementedError, 'must be overrided' end
    def glyph_data(gid_or_name); raise NotImplementedError, 'must be overrided' end
    def search_gid(glyph_data); raise NotImplementedError, 'must be overrided' end
    def cid_keyed?; false end
    def cid2gid(*cids); cid_keyed? ? 'must be overrided' : Array.new(cids.size, nil) end
    def embedded?; @embedded ||= false end
    def actual; embedded? ? Font.search(fullname) : self end
    
    module ExtendIO
      def byte; read(1).ord end
      def char; read(1).ord end
      def ushort; read(2).unpack('n')[0] end
      def short; [ushort].pack('s').unpack('s')[0] end
      def uint24; read(3).bytes.inject(0){|acc,x|(acc<<8)|x} end
      def ulong; read(4).unpack('N')[0] end
      def long; ulong.pack('l').unpack('l')[0] end
      def fixed
        num = short
        den = Rational(ushort, 0x10000)
        num + (num < 0 ? -den : den)
      end
      alias :fword :short
      alias :ufword :ushort
      def f2dot14
        int = ushort
        mantissa = case int >> 14
          when 0 then 0
          when 1 then 1
          when 2 then -2
          when 3 then -1
        end
        frac = Rational(int & 0b0011_1111_1111_1111, 16384)  # 16384 == 0b0100_0000_0000_0000
        mantissa + (mantissa < 0 ? -frac : frac)
      end
      alias :b :byte
      alias :c :char
      alias :us :ushort
      alias :s :short
      alias :i3 :uint24
      alias :l :long
      alias :ul :ulong
      alias :f :fixed
      alias :f2 :f2dot14
      def tag
        tg = read(4).force_encoding('us-ascii')
        raise InvalidFontFormat, "invalid tag [#{tg.bytes}]" unless tg.valid_encoding?
        tg
      end
      def pascal; read(read(1).ord) end
      def msb(num); read(num).bytes.inject(0){|acc,cur| (acc << 8) | cur} end
    end
    
    def initialize(io, *args)
      @fullname, @familyname, @glyphcount = [], [], 0
      @io = io.extend(ExtendIO)
    end
    
    private
    
    def warn(*args)
      PDF.warn(*args)
    end
    
  end
  
end
