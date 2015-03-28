# coding: ascii-8bit

module PDF::Utils::Encoding
  
  Encodings = ::Encoding.name_list.reject{|enc|/ascii/i=~enc}.select{|enc|::Encoding::Converter.search_convpath(enc, 'UTF-8') rescue false}.select{|enc| enc=::Encoding.find(enc);enc && !enc.dummy?}.freeze
  
  def self.search(str)
    encs = []
    Encodings.each do |enc|
      tmp_str = str.dup.force_encoding(enc)
      next unless tmp_str.valid_encoding?
      encs << enc
    end
    encs.empty? ? nil : encs
  end
  
  # find cid to unicode mapping file
  def self.cid2unicode(name)
    name = "#{name}-UCS2"
    path = File.expand_path("encoding/cid2unicode/#{name}", __dir__)
    FileTest.file?(path) ? File.read(path) : nil
  end
  
  # find code to cid mapping file
  def self.code2cid(name)
    path = File.expand_path("encoding/code2cid/#{name}", __dir__)
    FileTest.file?(path) ? File.read(path) : nil
  end
  
  #def self.cid_to_unicode(name)
  #  if name.to_s.start_with?('Adobe-')
  #    path = File.expand_path("../encoding/#{name}.rb", __FILE__)
  #    raise ArgumentError, "cmap file #{name} not found" unless FileTest.file?(path)
  #    eval(File.read(path))
  #  else
  #    path = File.expand_path("../encoding/#{name}", __FILE__)
  #    raise ArgumentError, "cmap file #{name} not found" unless FileTest.file?(path)
  #    ps = PDF::Parser::PostScriptParser.new(File.read(path))
  #    cmap = ps.resources.fetch(:CMap)
  #    cmap.dup.shift[1][:'.codemap']
  #  end
  #  
  #end
  
  
  # definition of PDF priset encodings;
  # StandardEncoding, MacRomanEncoding, WinAnsiEncoding, PDFDocEncoding,
  # MacExpertEncoding, SymbolEncoding and ZapfDingbatsEncoding.
  # Each constant is Hash which maps 1-byte char to corresponding unicode codepoint.
  autoload :StandardEncoding, "#{__dir__}/encoding/predefined/standard.rb"
  autoload :MacRomanEncoding, "#{__dir__}/encoding/predefined/macroman.rb"
  autoload :WinAnsiEncoding, "#{__dir__}/encoding/predefined/winansi.rb"
  autoload :PDFDocEncoding, "#{__dir__}/encoding/predefined/pdfdoc.rb"
  autoload :MacExpertEncoding, "#{__dir__}/encoding/predefined/macexpert.rb"
  autoload :SymbolEncoding, "#{__dir__}/encoding/predefined/symbol.rb"
  autoload :ZapfDingbatsEncoding, "#{__dir__}/encoding/predefined/zapfdingbats.rb"
  
  # NameToUnicode is Hash which maps Symbol of glyph name to Array of unicode codepoints.
  autoload :NameToUnicode, "#{__dir__}/encoding/nametounicode.rb"
end
