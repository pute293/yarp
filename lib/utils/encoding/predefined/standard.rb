module YARP::Utils::Encoding
  
  # StandardEncoding is 1 char/byte encoding,
  # same as Ascii for range 0x20-0x7e.
  # (ref. PostScript Language Reference, Third Edition
  #    table E.6 (p. 784)
  #    http://www.adobe.com/products/postscript/pdfs/PLRM.pdf).
  StandardEncoding = Hash[
    [ # 00 - 1f is not defined
      nil,    nil,    nil,    nil,    nil,    nil,    nil,    nil,    # 00
      nil,    nil,    nil,    nil,    nil,    nil,    nil,    nil,    #   
      nil,    nil,    nil,    nil,    nil,    nil,    nil,    nil,    # 10
      nil,    nil,    nil,    nil,    nil,    nil,    nil,    nil,    #   
      # 20 - 9f is same as Ascii                                      #   
      0x20,   0x21,   0x22,   0x23,   0x24,   0x25,   0x26,   0x27,   # 20
      0x28,   0x29,   0x2a,   0x2b,   0x2c,   0x2d,   0x2e,   0x2f,   #   
      0x30,   0x31,   0x32,   0x33,   0x34,   0x35,   0x36,   0x37,   # 30
      0x38,   0x39,   0x3a,   0x3b,   0x3c,   0x3d,   0x3e,   0x3f,   #   
      0x40,   0x41,   0x42,   0x43,   0x44,   0x45,   0x46,   0x47,   # 40
      0x48,   0x49,   0x4a,   0x4b,   0x4c,   0x4d,   0x4e,   0x4f,   #   
      0x50,   0x51,   0x52,   0x53,   0x54,   0x55,   0x56,   0x57,   # 50
      0x58,   0x59,   0x5a,   0x5b,   0x5c,   0x5d,   0x5e,   0x5f,   #   
      0x60,   0x61,   0x62,   0x63,   0x64,   0x65,   0x66,   0x67,   # 60
      0x68,   0x69,   0x6a,   0x6b,   0x6c,   0x6d,   0x6e,   0x6f,   #   
      0x70,   0x71,   0x72,   0x73,   0x74,   0x75,   0x76,   0x77,   # 70
      0x78,   0x79,   0x7a,   0x7b,   0x7c,   0x7d,   0x7e,   nil,    #   
      nil,    nil,    nil,    nil,    nil,    nil,    nil,    nil,    # 80
      nil,    nil,    nil,    nil,    nil,    nil,    nil,    nil,    #   
      nil,    nil,    nil,    nil,    nil,    nil,    nil,    nil,    # 90
      nil,    nil,    nil,    nil,    nil,    nil,    nil,    nil,    #   
      # a0 - ff is difference from either MacRoman or x-MacSymbol     #   
      nil,    0xa1,   0xa2,   0xa3,   0x2044, 0xa5,   0x0192, 0xa7,   # A0
      0xa4,   0x27,   0x201c, 0xab,   0x2039, 0x203a, 0xfb01, 0xfb02, #   
      nil,    0x2013, 0x2020, 0x2021, 0xb7,   nil,    0xb6,   0x2022, # B0
      0x201a, 0x201e, 0x201d, 0xbb,   0x2026, 0x2030, nil,    0xbf,   #   
      nil,    0x60,   0xb4,   0x02c6, 0x02dc, 0xaf,   0x02d8, 0x02d9, # C0
      0xa8,   nil,    0xb0,   0xb8,   nil,    0x02dd, 0x02db, 0x02c7, #   
      0x2014, nil,    nil,    nil,    nil,    nil,    nil,    nil,    # D0
      nil,    nil,    nil,    nil,    nil,    nil,    nil,    nil,    #   
      nil,    0xc6,   nil,    0xaa,   nil,    nil,    nil,    nil,    # E0
      0x0141, 0xd8,   0x0152, 0xba,   nil,    nil,    nil,    nil,    #   
      nil,    0xe6,   nil,    nil,    nil,    0x0131, nil,    nil,    # F0
      0x0142, 0xf8,   0x0153, 0xdf,   nil,    nil,    nil,    nil,    #   
    ].each_with_index.collect{|x,i| [i.chr, x ? x : 0]}
  ].freeze
  
end
