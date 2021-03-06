module YARP::Utils::Encoding
  
  MacExpertEncoding = Hash[
    [ nil,    nil,    nil,    nil,    nil,    nil,    nil,    nil,    # 00
      nil,    nil,    nil,    nil,    nil,    nil,    nil,    nil,    #   
      nil,    nil,    nil,    nil,    nil,    nil,    nil,    nil,    # 10
      nil,    nil,    nil,    nil,    nil,    nil,    nil,    nil,    #   
      0x20,   0xfe57, 0x02dd, 0xa2,   0x24,   0x24,   0xfe60, 0xb4,   # 20
      0x207d, 0x207e, 0x2025, 0x2024, 0x2c,   0x2d,   0x2e,   0x2044, #   
      0x30,   0x31,   0x32,   0x33,   0x34,   0x35,   0x36,   0x37,   # 30
      0x38,   0x39,   0x3a,   0x3b,   nil,    0x2014, nil,    0xfe56, #   
      nil,    nil,    nil,    nil,    0xd0,   nil,    nil,    0xbc,   # 40
      0xbd,   0xbe,   0x215b, 0x215c, 0x215d, 0x215e, 0x2153, 0x2154, #   
      nil,    nil,    nil,    nil,    nil,    nil,    0xfb00, 0xfb01, # 50
      0xfb02, 0xfb03, 0xfb04, 0x208d, nil,    0x208e, 0x02c6, 0x2d,   #   
      0x60,   0x41,   0x42,   0x43,   0x44,   0x45,   0x46,   0x47,   # 60
      0x48,   0x49,   0x4a,   0x4b,   0x4c,   0x4d,   0x4e,   0x4f,   #   
      0x50,   0x51,   0x52,   0x53,   0x54,   0x55,   0x56,   0x57,   # 70
      0x58,   0x59,   0x5a,   0x20a1, 0x31,   [0x52,0x70],0x02dc, nil,#   
      nil,    0x61,   0xa2,   nil,    nil,    nil,    nil,    0xc1,   # 80
      0xc0,   0xc2,   0xc4,   0xc3,   0xc5,   0xc7,   0xc9,   0xc8,   #   
      0xca,   0xcb,   0xed,   0xcc,   0xee,   0xef,   0xd1,   0xd3,   # 90
      0xd2,   0xd4,   0xd6,   0xd5,   0xda,   0xd9,   0xdb,   0xdc,   #   
      nil,    0x2078, 0x2084, 0x2083, 0x2086, 0x2088, 0x2087, 0x0160, # A0
      nil,    0xa2,   0x2082, nil,    0xa8,   nil,    0x02c7, 0x6f,   #   
      0x2085, nil,    0x2c,   0x2e,   0xdd,   nil,    0x24,   nil,    # B0
      nil,    0xde,   nil,    0x2089, 0x2080, 0x017d, 0xc6,   0xd8,   #   
      0xbf,   0x2081, 0x0142, nil,    nil,    nil,    nil,    nil,    # C0
      nil,    0xb8,   nil,    nil,    nil,    nil,    nil,    0x0152, #   
      0x2012, 0x2d,   nil,    nil,    nil,    nil,    0xa1,   nil,    # D0
      0x0178, nil,    0xb9,   0xb2,   0xb3,   0x2074, 0x2075, 0x2076, #   
      0x2077, 0x2079, 0x2070, nil,    0x65,   0x72,   0x74,   nil,    # E0
      nil,    0x69,   0x73,   0x64,   nil,    nil,    nil,    nil,    #   
      nil,    0x6c,   0x02db, 0x02d8, 0xaf,   0x62,   0x207f, 0x6d,   # F0
      0x2c,   0x2e,   0x02d9, 0x02da, nil,    nil,    nil,    nil,    #   
    ].each_with_index.collect{|x,i| [i.chr, x ? x : 0]}
  ].freeze
  
end
