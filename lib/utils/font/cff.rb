module YARP::Utils::Font
  
  class InvalidCffFormat < InvalidFontFormat; end
  
  module CFF
    module_function
    
    # predefined encoding which specifies code to SID mapping
    Encodings = {
      :Standard => [
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
        17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32,
        33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48,
        49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64,
        65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80,
        81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110,
        0, 111, 112, 113, 114, 0, 115, 116, 117, 118, 119, 120, 121, 122, 0, 123,
        0, 124, 125, 126, 127, 128, 129, 130, 131, 0, 132, 133, 0, 134, 135, 136,
        137, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 138, 0, 139, 0, 0, 0, 0, 140, 141, 142, 143, 0, 0, 0, 0,
        0, 144, 0, 0, 0, 145, 0, 0, 146, 147, 148, 149, 0, 0, 0, 0
      ].freeze,
      :Expert => [
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        1, 229, 230, 0, 231, 232, 233, 234, 235, 236, 237, 238, 13, 14, 15, 99,
        239, 240, 241, 242, 243, 244, 245, 246, 247, 248, 27, 28, 249, 250, 251, 252,
        0, 253, 254, 255, 256, 257, 0, 0, 0, 258, 0, 0, 259, 260, 261, 262,
        0, 0, 263, 264, 265, 0, 266, 109, 110, 267, 268, 269, 0, 270, 271, 272,
        273, 274, 275, 276, 277, 278, 279, 280, 281, 282, 283, 284, 285, 286, 287, 288,
        289, 290, 291, 292, 293, 294, 295, 296, 297, 298, 299, 300, 301, 302, 303, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 304, 305, 306, 0, 0, 307, 308, 309, 310, 311, 0, 312, 0, 0, 313,
        0, 0, 314, 315, 0, 0, 316, 317, 318, 0, 0, 0, 158, 155, 163, 319,
        320, 321, 322, 323, 324, 325, 0, 0, 326, 150, 164, 169, 327, 328, 329, 330,
        331, 332, 333, 334, 335, 336, 337, 338, 339, 340, 341, 342, 343, 344, 345, 346,
        347, 348, 349, 350, 351, 352, 353, 354, 355, 356, 357, 358, 359, 360, 361, 362,
        363, 364, 365, 366, 367, 368, 369, 370, 371, 372, 373, 374, 375, 376, 377, 378,
      ].freeze
    }.freeze
    
    Charsets = {
      # predefined standard charsets which specifies GID to name (as symbol) mapping
      :Standard => %i{
        .notdef space exclam quotedbl numbersign dollar percent ampersand quoteright parenleft parenright asterisk plus comma hyphen period
        slash zero one two three four five six seven eight nine colon semicolon less equal greater
        question at A B C D E F G H I J K L M N
        O P Q R S T U V W X Y Z bracketleft backslash bracketright asciicircum
        underscore quoteleft a b c d e f g h i j k l m n
        o p q r s t u v w x y z braceleft bar braceright asciitilde
        exclamdown cent sterling fraction yen florin section currency quotesingle quotedblleft guillemotleft guilsinglleft guilsinglright fi fl endash
        dagger daggerdbl periodcentered paragraph bullet quotesinglbase quotedblbase quotedblright guillemotright ellipsis perthousand questiondown grave acute circumflex tilde
        macron breve dotaccent dieresis ring cedilla hungarumlaut ogonek caron emdash AE ordfeminine Lslash Oslash OE ordmasculine
        ae dotlessi lslash oslash oe germandbls onesuperior logicalnot mu trademark Eth onehalf plusminus Thorn onequarter divide
        brokenbar degree thorn threequarters twosuperior registered minus eth multiply threesuperior copyright Aacute Acircumflex Adieresis Agrave Aring
        Atilde Ccedilla Eacute Ecircumflex Edieresis Egrave Iacute Icircumflex Idieresis Igrave Ntilde Oacute Ocircumflex Odieresis Ograve Otilde
        Scaron Uacute Ucircumflex Udieresis Ugrave Yacute Ydieresis Zcaron aacute acircumflex adieresis agrave aring atilde ccedilla eacute
        ecircumflex edieresis egrave iacute icircumflex idieresis igrave ntilde oacute ocircumflex odieresis ograve otilde scaron uacute ucircumflex
        udieresis ugrave yacute ydieresis zcaron exclamsmall Hungarumlautsmall dollaroldstyle dollarsuperior ampersandsmall Acutesmall parenleftsuperior parenrightsuperior twodotenleader onedotenleader zerooldstyle
        oneoldstyle twooldstyle threeoldstyle fouroldstyle fiveoldstyle sixoldstyle sevenoldstyle eightoldstyle nineoldstyle commasuperior threequartersemdash periodsuperior questionsmall asuperior bsuperior centsuperior
        dsuperior esuperior isuperior lsuperior msuperior nsuperior osuperior rsuperior ssuperior tsuperior ff ffi ffl parenleftinferior parenrightinferior Circumflexsmall
        hyphensuperior Gravesmall Asmall Bsmall Csmall Dsmall Esmall Fsmall Gsmall Hsmall Ismall Jsmall Ksmall Lsmall Msmall Nsmall
        Osmall Psmall Qsmall Rsmall Ssmall Tsmall Usmall Vsmall Wsmall Xsmall Ysmall Zsmall colonmonetary onefitted rupiah Tildesmall
        exclamdownsmall centoldstyle Lslashsmall Scaronsmall Zcaronsmall Dieresissmall Brevesmall Caronsmall Dotaccentsmall Macronsmall figuredash hypheninferior Ogoneksmall Ringsmall Cedillasmall questiondownsmall
        oneeighth threeeighths fiveeighths seveneighths onethird twothirds zerosuperior foursuperior fivesuperior sixsuperior sevensuperior eightsuperior ninesuperior zeroinferior oneinferior twoinferior
        threeinferior fourinferior fiveinferior sixinferior seveninferior eightinferior nineinferior centinferior dollarinferior periodinferior commainferior Agravesmall Aacutesmall Acircumflexsmall Atildesmall Adieresissmall
        Aringsmall AEsmall Ccedillasmall Egravesmall Eacutesmall Ecircumflexsmall Edieresissmall Igravesmall Iacutesmall Icircumflexsmall Idieresissmall Ethsmall Ntildesmall Ogravesmall Oacutesmall Ocircumflexsmall
        Otildesmall Odieresissmall OEsmall Oslashsmall Ugravesmall Uacutesmall Ucircumflexsmall Udieresissmall Yacutesmall Thornsmall Ydieresissmall 001.000 001.001 001.002 001.003 Black
        Bold Book Light Medium Regular Roman Semibold
      }.freeze,
      # predefined charsets which specifies GID to SID mapping
      :ISOAdobe     => (0..228).to_a.freeze,
      :Expert       => [0, 1, (229..238).to_a, 13, 14, 15, 99, (239..248).to_a, 27, 28, (249..266).to_a, 109, 110, (267..318).to_a, 158, 155, 163, (319..326).to_a, 150, 164, 169, (327..378).to_a].flatten.freeze,
      :ExpertSubset => [0, 1, 231, 232, (235..238).to_a, 13, 14, 15, 99, (239..248).to_a, 27, 28, 249, 250, 251, (253..266).to_a, 109, 110, (267..270).to_a, 272, 300, 301, 302, 305, 314, 315, 158, 155, 163, (320..326).to_a, 150, 164, 169, (327..346).to_a].flatten.freeze,
    }.freeze
    
    def parse_cff(str)
      io = StringIO.new(str, 'rb:ASCII-8BIT')
      io.extend(self.class::ExtendIO)
      
      # int => string (glyph name, font name, ...)
      sid = {}
      
      # Header section
      header = read_header(io)
      io.seek(header[:size])
      # Name INDEX section
      font_names = read_index(io).collect(&:intern)
      # Top DICT INDEX section
      top_dicts = read_index(io).collect do |str|
        dict = read_dict(str)
        init_top_dict(dict)
      end
      fonts = Hash[*font_names.zip(top_dicts).flatten]
      # String INDEX section
      read_index(io).each_with_index {|str,i| sid[i + 391] = str.intern}
      # Global Subr INDEX section
      read_index(io)  # throw away
      
      # per-font sections
      ## CharStrings INDEX sections
      ## dict[:CharStrings] specifies GID to glyph data mapping
      fonts.each do |font, dict|
        io.seek(dict[:CharStrings])
        charstrings = read_index(io)
        dict[:CharStrings] = charstrings
        dict[:nGlyphs] = charstrings.size
      end
      ## CharSets sections
      ## dict[:Charsets] specifies GID to name (as symbol) mapping
      fonts.each do |font, dict|
        charsets = case charset = dict[:charset]
        when 0 then Charsets[:ISOAdobe]
        when 1 then Charsets[:Expert]
        when 2 then Charsets[:ExpertSubset]
        else
          io.seek(charset)
          fmt = io.read(1).ord
          num = dict[:nGlyphs] - 1
          case fmt
          when 0 then io.read(num * 2).unpack('n*')
          when 1, 2
            array = []
            len = fmt == 1 ? 3 : 4
            fmt = fmt == 1 ? 'nC' : 'nn'
            while 0 < num
              sid_, r = io.read(len).unpack(fmt)
              array.push(sid_.upto(sid_+r).to_a)
              num -= r + 1
            end
            array.flatten
          else raise InvalidCffFormat, "in CharSets Section, unexpected format: #{fmt}; expected 0..2"
          end
        end
        charsets.unshift(0) unless charsets.include?(0)
        dict[:_charset] = charsets
        
        unless dict[:ROS]
          # predefined charsets
          std = Charsets[:Standard]
          dict[:Charsets] = charsets.collect{|i| i < 391 ? std.fetch(i) : sid.fetch(i)}.freeze
        else
          # CID-keyed Font
          # There are no predefined charsets for CID fonts.
          ros = dict[:ROS]
          r, o = sid.fetch(ros[0]), sid.fetch(ros[1])
          prefix = (r[0] + o[0] + o[-1].to_i.to_s).downcase
          len = Math.log10(charsets.max).to_i + 1
          dict[:Charsets] = charsets.collect{|i| "#{prefix}.#{i.to_s.rjust(len,'0')}".intern}.freeze
          ## ignore information for rasterization
          #cid = dict#[:CID]
          #io.seek(cid[:FDSelect])
          #fmt = io.read(1).ord
          #fdselect = case fmt # cid => index of font dict
          #when 0
          #  io.read(dict[:nGlyphs]).unpack('C*')
          #when 3
          #  num_ranges, = io.read(2).unpack('n')
          #  ranges = io.read(3 * num_ranges).unpack('nC' * num_ranges)
          #  sentinel, = io.read(2).unpack('n')
          #  ranges.push(sentinel, -1)
          #  hash = {}
          #  ranges.each_slice(2).each_cons(2) do |r1, r2|
          #    fst = r1[0]
          #    fd_idx = r1[1]
          #    fst.upto(r2[0] - 1) {|gid| hash[gid] = fd_idx}
          #  end
          #  hash
          #else raise InvalidFontFormat, "invalid FDSelect format #{fmt}; expected 0, 3"
          #end
          #io.seek(cid[:FDArray])
          #fdarray = read_index(io).collect{|str| read_dict(str)}
          #dict[:fdselect] = fdselect
          #dict[:fdarray] = fdarray.collect{|fd| if fd[:Private];io.seek(fd[:Private][1]);fd[:Private] = read_dict(io.read(fd[:Private][0]));end;fd}
        end
      end
      ## Encodings sections
      ## dict[:Encoding] specifies GID to code mapping
      fonts.each do |font, dict|
        if dict[:ROS]
          # CID-keyed font does not specify encoding
          dict.delete(:Encoding)
          next
        end
        encoding = case off = dict[:Encoding]
        when 0, 1
          # predefined encoding specifies code to SID mapping
          # !!! WARN: some GIDs are not assigned to any code in predefined encoding, e.g. /copyright (sid=170)
          enc = Encodings[off == 0 ? :Standard : :Expert]
          charsets = dict.delete(:_charset)  # GID to SID mapping
          charsets.collect{|sid| enc.index(sid)} # GID to code mapping
        else  # custom encoding specifies GID to code mapping
          io.seek(off)
          fmt = io.read(1).ord
          num = io.read(1).ord
          enc = case fmt
          when 0 then io.read(num).unpack('C*')
          when 1
            ranges = io.read(num * 2).unpack('C*').each_slice(2)
            ranges.collect{|fst,left| fst.upto(fst+left).to_a}.flatten
          else raise InvalidCffFormat, "invalid Encoding format: #{fmt}; expected 0, 1"
          end
          enc.unshift(0) unless (enc.empty? && enc.include?(0))
          enc
        end
        dict[:Encoding] = encoding.freeze
      end
      fonts.each {|font,dict| dict.freeze}
      fonts[:SID] = sid.freeze
      fonts
    end
    
    def read_header(io)
      header = io.read(4).unpack('C4')
      major, minor, size, offsize = header
      {:majer => major, :minor => minor, :size => size, :offsize => offsize}
    end
    
    def read_index(io)
      count, = io.read(2).unpack('n')
      return [] if count == 0
      ele_size, = io.read(1).unpack('C')
      offset_array = (count+1).times.collect{io.msb(ele_size)}
      sizes = offset_array.each_cons(2).collect{|a,b| b - a}
      sizes.collect{|size| io.read(size)}
    end
    
    DictOperators = {
      0 => :version, 1 => :Notice, 2 => :FullName, 3 => :FamilyName, 4 => :Weight, 5 => :FontBBox, 6 => :BlueValues, 7 => :OtherBlues,
      8 => :FamilyBlues, 9 => :FamilyOtherBlues, 10 => :StdHW, 11 => :StdVW, 12 => :_escape_, 13 => :UniqueID, 14 => :XUID, 15 => :charset,
      16 => :Encoding, 17 => :CharStrings, 18 => :Private, 19 => :Subrs, 20 => :defaultWidthX, 21 => :nominalWidthX, 22 => :_reserved_, 23 => :_reserved_,
      24 => :_reserved_, 25 => :_reserved_, 26 => :_reserved_, 27 => :_reserved_, 28 => :shortint, 29 => :longint, 30 => :BCD, 31 => :_reserved_, 255 => :_reserved_,
      0x0c00 => :Copyright, 0x0c01 => :isFixedPitch, 0x0c02 => :ItalicAngle, 0x0c03 => :UnderlinePosition,
      0x0c04 => :UnderlineThickness, 0x0c05 => :PaintType, 0x0c06 => :CharstringType, 0x0c07 => :FontMatrix,
      0x0c08 => :StrokeWidth, 0x0c09 => :BlueScale, 0x0c0a => :BlueShift, 0x0c0b => :BlueFuzz,
      0x0c0c => :StemSnapH, 0x0c0d => :StemSnapV, 0x0c0e => :ForceBold, 0x0c0f => :_reserved_,
      0x0c10 => :_reserved_, 0x0c11 => :LanguageGroup, 0x0c12 => :ExpansionFactor, 0x0c13 => :initialRandomSeed,
      0x0c14 => :SyntheticBase, 0x0c15 => :PostScript, 0x0c16 => :BaseFontName, 0x0c17 => :BaseFontBlend,
      0x0c18 => :_reserved_, 0x0c19 => :_reserved_, 0x0c1a => :_reserved_, 0x0c1b => :_reserved_,
      0x0c1c => :_reserved_, 0x0c1d => :_reserved_, 0x0c1e => :ROS, 0x0c1f => :CIDFontVersion,
      0x0c20 => :CIDFontRevision, 0x0c21 => :CIDFontType, 0x0c22 => :CIDCount, 0x0c23 => :UIDBase,
      0x0c24 => :FDArray, 0x0c25 => :FDSelect, 0x0c26 => :FontName
    }
    DictOperators.default = :_reserved_
    DictOperators.freeze
    
    def read_dict(str)
      io = StringIO.new(str, 'rb:ASCII-8BIT')
      dict = {}
      operand_stack = []
      until io.eof?
        b0, = io.read(1).unpack('C')
        operand = case b0
        when (0..21)
          # operator
          b0 = ((b0 << 8) | io.read(1).unpack('C')[0]) if b0 == 12
          op = DictOperators[b0]
          raise InvalidCffFormat, "invalid DICT operator 0x#{b0.to_s(16)}" if op == :_reserved_
          dict[op] = operand_stack.size <= 1 ? operand_stack.first : operand_stack.freeze
          operand_stack = []
          next
        when 28
          v0, = io.read(2).unpack('n')
          v0[15] == 0 ? v0 : -((v0 ^ 0xffff) + 1)
        when 29
          v0, = io.read(4).unpack('N')
          v0[31] == 0 ? v0 : -((v0 ^ 0xffff_ffff) + 1)
        when 30
          # real number
          v0 = ''
          begin
            v_, = io.read(1).unpack('C')
            v0 << '%02x' % v_
          end while (v_ & 0x0f) != 0x0f
          eon = v0.index('f')
          v0 = v0[0...eon]
          v0.gsub(/[a-e]/) {|x|
            case x
            when ?a then '.'
            when ?b then 'e'
            when ?c then 'e-'
            when ?d then '' # reserved
            when ?e then '-'
            end
          }.to_f
        when (32..246)
          b0 - 139
        when (247..250)
          b1, = io.read(1).unpack('C')
          ((b0 - 247) << 8) + b1 + 108
        when (251..254)
          b1, = io.read(1).unpack('C')
          -((b0 - 251) << 8) - b1 - 108
        else raise InvalidCffFormat, "b0 must be 0..21 or 28..254; but #{b0} (0x#{'%02x'%b0})"
        end
        operand_stack.push(operand)
      end
      dict
    end
    
    def init_top_dict(dict)
        # initialize dict
        dict[:isFixedPitch] ||= 0
        dict[:italic_angle] ||= 0
        dict[:UnderlinePosition] ||= -100
        dict[:UnderlineThickness] ||= 50
        dict[:PaintType] ||= 0
        dict[:CharstringType] ||= 2
        dict[:FontMatrix] ||= [0.001, 0.0, 0.0, 0.001, 0.0, 0.0]
        dict[:FontBBox] ||= [0.0, 0.0, 0.0, 0.0]
        dict[:StrokeWidth] ||= 0
        dict[:charset] ||= 0
        dict[:Encoding] ||= 0
        if dict[:ROS]
          dict[:CIDFontVersion] ||= 0
          dict[:CIDFontRevision] ||= 0
          dict[:CIDFontType] ||= 0
          dict[:CIDCount] ||= 8720
        end
        dict
    end
  end
  
end
