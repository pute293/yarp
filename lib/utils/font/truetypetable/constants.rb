module YARP::Utils::Font
  
  class TrueType
    
    PlatformIds = %i{ Unicode Macintosh ISO Windows Custom }.freeze
    EncodingIds = {
      :Unicode    =>  %i{ 1.0 1.1 ISO10646 2.0_BMP 2.0 Variation All }.freeze,
      :Macintosh  =>  %i{ Roman Japanese Chinese_Traditional Korean Arabic Hebrew Greek Russian
                        RSymbol Devanagari Gurmukhi Gujarati Oriya Bengali Tamil Telugu Kannada
                        Malayalam Sinhalese Burmese Khmer Thai Laotian Georgian Armenian Chinese_Simplified
                        Tibetan Mongolian Geez Slavic Vietnamese Sindhi Uninterpreted }.freeze,
      :ISO        =>  %i{ ISO_7BIT_ASCII ISO_10646 ISO_8859_1 }.freeze,
      :Windows  =>  %i{ Symbol UCS_2 SJIS PRC Big5 Wansung Johab Reserved Reserved Reserved UCS_4 }.freeze,
    }.freeze
    
    Mac_Glyph_Names = %i{
      .notdef .null nonmarkingreturn space exclam quotedbl numbersign dollar percent ampersand quotesingle parenleft parenright asterisk plus comma
      hyphen period slash zero one two three four five six seven eight nine colon semicolon less
      equal greater question at A B C D E F G H I J K L
      M N O P Q R S T U V W X Y Z bracketleft backslash
      bracketright asciicircum underscore grave a b c d e f g h i j k l
      m n o p q r s t u v w x y z braceleft bar
      braceright asciitilde Adieresis Aring Ccedilla Eacute Ntilde Odieresis Udieresis aacute agrave acircumflex adieresis atilde aring ccedilla
      eacute egrave ecircumflex edieresis iacute igrave icircumflex idieresis ntilde oacute ograve ocircumflex odieresis otilde uacute ugrave
      ucircumflex udieresis dagger degree cent sterling section bullet paragraph germandbls registered copyright trademark acute dieresis notequal
      AE Oslash infinity plusminus lessequal greaterequal yen mu partialdiff summation product pi integral ordfeminine ordmasculine Omega
      ae oslash questiondown exclamdown logicalnot radical florin approxequal Delta guillemotleft guillemotright ellipsis nonbreakingspace Agrave Atilde Otilde
      OE oe endash emdash quotedblleft quotedblright quoteleft quoteright divide lozenge ydieresis Ydieresis fraction currency guilsinglleft guilsinglright
      fi fl daggerdbl periodcentered quotesinglbase quotedblbase perthousand Acircumflex Ecircumflex Aacute Edieresis Egrave Iacute Icircumflex Idieresis Igrave
      Oacute Ocircumflex apple Ograve Uacute Ucircumflex Ugrave dotlessi circumflex tilde macron breve dotaccent ring cedilla hungarumlaut
      ogonek caron Lslash lslash Scaron scaron Zcaron zcaron brokenbar Eth eth Yacute yacute Thorn thorn minus
      multiply onesuperior twosuperior threesuperior onehalf onequarter threequarters franc Gbreve gbreve Idotaccent Scedilla scedilla Cacute cacute Ccaron
      ccaron dcroat
    }.freeze
    
    # Microsoft LCID to AnsiCodepage
    # ref. http://www.microsoft.com/resources/msdn/goglobal/default.mspx
    # !!! WARN: CP864, CP1258, CP65000 and CP65001 are not able to convert to unicode
    LcidToCodepage = {
      0x0036 => 1252, 0x0436 => 1252, 0x001C => 1250, 0x041C => 1250, 0x0484 => 1252, 0x0001 => 1256, 0x1401 => 1256, 0x3C01 => 1256,
      0x0C01 => 1256, 0x0801 => 1256, 0x2C01 => 1256, 0x3401 => 1256, 0x3001 => 1256, 0x1001 => 1256, 0x1801 => 1256, 0x2001 => 1256,
      0x4001 => 1256, 0x0401 => 1256, 0x2801 => 1256, 0x1C01 => 1256, 0x3801 => 1256, 0x2401 => 1256, 0x002C => 1254, 0x082C => 1251,
      0x042C => 1254, 0x046D => 1251, 0x002D => 1252, 0x042D => 1252, 0x0023 => 1251, 0x0423 => 1251, 0x201A => 1251, 0x141A => 1250,
      0x047E => 1252, 0x0002 => 1251, 0x0402 => 1251, 0x0003 => 1252, 0x0403 => 1252, 0x0C04 =>  950, 0x1404 =>  950, 0x0804 =>  936,
      0x0004 =>  936, 0x1004 =>  936, 0x0404 =>  950, 0x7C04 =>  950, 0x0483 => 1252, 0x001A => 1250, 0x041A => 1250, 0x101A => 1250,
      0x0005 => 1250, 0x0405 => 1250, 0x0006 => 1252, 0x0406 => 1252, 0x048C => 1256, 0x0013 => 1252, 0x0813 => 1252, 0x0413 => 1252,
      0x0009 => 1252, 0x0C09 => 1252, 0x2809 => 1252, 0x1009 => 1252, 0x2409 => 1252, 0x4009 => 1252, 0x1809 => 1252, 0x2009 => 1252,
      0x4409 => 1252, 0x1409 => 1252, 0x3409 => 1252, 0x4809 => 1252, 0x1C09 => 1252, 0x2C09 => 1252, 0x0809 => 1252, 0x0409 => 1252,
      0x3009 => 1252, 0x0025 => 1257, 0x0425 => 1257, 0x0038 => 1252, 0x0438 => 1252, 0x0464 => 1252, 0x000B => 1252, 0x040B => 1252,
      0x000C => 1252, 0x080C => 1252, 0x0C0C => 1252, 0x040C => 1252, 0x140C => 1252, 0x180C => 1252, 0x100C => 1252, 0x0462 => 1252,
      0x0056 => 1252, 0x0456 => 1252, 0x0007 => 1252, 0x0C07 => 1252, 0x0407 => 1252, 0x1407 => 1252, 0x1007 => 1252, 0x0807 => 1252,
      0x0008 => 1253, 0x0408 => 1253, 0x046F => 1252, 0x0468 => 1252, 0x000D => 1255, 0x040D => 1255, 0x000E => 1250, 0x040E => 1250,
      0x000F => 1252, 0x040F => 1252, 0x0470 => 1252, 0x0021 => 1252, 0x0421 => 1252, 0x085D => 1252, 0x083C => 1252, 0x0434 => 1252,
      0x0435 => 1252, 0x0010 => 1252, 0x0410 => 1252, 0x0810 => 1252, 0x0011 =>  932, 0x0411 =>  932, 0x003F => 1251, 0x043F => 1251,
      0x0486 => 1252, 0x0487 => 1252, 0x0041 => 1252, 0x0441 => 1252, 0x0012 =>  949, 0x0412 =>  949, 0x0040 => 1251, 0x0440 => 1251,
      0x0026 => 1257, 0x0426 => 1257, 0x0027 => 1257, 0x0427 => 1257, 0x082E => 1252, 0x046E => 1252, 0x002F => 1251, 0x042F => 1251,
      0x003E => 1252, 0x083E => 1252, 0x043E => 1252, 0x047A => 1252, 0x047C => 1252, 0x0050 => 1251, 0x0450 => 1251, 0x0014 => 1252,
      0x0414 => 1252, 0x0814 => 1252, 0x0482 => 1252, 0x0029 => 1256, 0x0429 => 1256, 0x0015 => 1250, 0x0415 => 1250, 0x0016 => 1252,
      0x0416 => 1252, 0x0816 => 1252, 0x046B => 1252, 0x086B => 1252, 0x0C6B => 1252, 0x0018 => 1250, 0x0418 => 1250, 0x0417 => 1252,
      0x0019 => 1251, 0x0419 => 1251, 0x243B => 1252, 0x103B => 1252, 0x143B => 1252, 0x0C3B => 1252, 0x043B => 1252, 0x083B => 1252,
      0x203B => 1252, 0x183B => 1252, 0x1C3B => 1252, 0x7C1A => 1251, 0x1C1A => 1251, 0x0C1A => 1251, 0x181A => 1250, 0x081A => 1250,
      0x046C => 1252, 0x0432 => 1252, 0x001B => 1250, 0x041B => 1250, 0x0024 => 1250, 0x0424 => 1250, 0x000A => 1252, 0x2C0A => 1252,
      0x400A => 1252, 0x340A => 1252, 0x240A => 1252, 0x140A => 1252, 0x1C0A => 1252, 0x300A => 1252, 0x440A => 1252, 0x100A => 1252,
      0x480A => 1252, 0x080A => 1252, 0x4C0A => 1252, 0x180A => 1252, 0x3C0A => 1252, 0x280A => 1252, 0x500A => 1252, 0x0C0A => 1252,
      0x540A => 1252, 0x380A => 1252, 0x200A => 1252, 0x001D => 1252, 0x081D => 1252, 0x041D => 1252, 0x0428 => 1251, 0x085F => 1252,
      0x0044 => 1251, 0x0444 => 1251, 0x001E =>  874, 0x041E =>  874, 0x001F => 1254, 0x041F => 1254, 0x0442 => 1250, 0x0480 => 1256,
      0x0022 => 1251, 0x0422 => 1251, 0x042E => 1252, 0x0020 => 1256, 0x0420 => 1256, 0x0043 => 1254, 0x0843 => 1251, 0x0443 => 1254,
      0x002A => 1258, 0x042A => 1258, 0x0452 => 1252, 0x0488 => 1252, 0x0485 => 1251, 0x046A => 1252,
    }.select{|lcid, cp| Encoding::Converter.search_convpath("CP#{cp}", 'UTF-8') rescue false}.freeze
    
  end
  
end