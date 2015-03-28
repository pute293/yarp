lines = File.read(__FILE__.sub(/\.rb$/, '.txt')).lines
hash = Hash[*lines.collect{|line| line.sub(/#.*$/, '').strip}.reject(&:empty?)\
.collect(&:split).collect{|mac, uni|
  /^0x([[:xdigit:]]+)/ =~ mac
  mac = [$1].pack('H*')
  uni = uni.split('+').collect{|u| /^0x([[:xdigit:]]+)/ =~ u; $1.to_i(16)}.reject{|u| [0xF87E, 0xF87F].include?(u)}.pack('U*')
  [mac, uni]
}.flatten]
alt = {
  # 00 - 1F
  "\x00" => "\u0000",
  "\x01" => "\u0001",
  "\x02" => "\u0002",
  "\x03" => "\u0003",
  "\x04" => "\u0004",
  "\x05" => "\u0005",
  "\x06" => "\u0006",
  "\x07" => "\u0007",
  "\x08" => "\u0008",
  "\x09" => "\u0009",
  "\x0A" => "\u000A",
  "\x0B" => "\u000B",
  "\x0C" => "\u000C",
  "\x0D" => "\u000D",
  "\x0E" => "\u000E",
  "\x0F" => "\u000F",
  "\x10" => "\u0010",
  "\x11" => "\u0011",
  "\x12" => "\u0012",
  "\x13" => "\u0013",
  "\x14" => "\u0014",
  "\x15" => "\u0015",
  "\x16" => "\u0016",
  "\x17" => "\u0017",
  "\x18" => "\u0018",
  "\x19" => "\u0019",
  "\x1A" => "\u001A",
  "\x1B" => "\u001B",
  "\x1C" => "\u001C",
  "\x1D" => "\u001D",
  "\x1E" => "\u001E",
  "\x1F" => "\u001F",
}
hash.merge!(alt)
hash.freeze
String::MacChinSimpTable = hash
