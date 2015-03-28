module PDF::Utils::Font
  
  module TrueTypeCollection
    def self.new(*args)
      self.parse(*args)
    end
    
    # TTC file can not be embedded to PDF, so argument is always path to font file, but dump of PDF
    def self.parse(path, *args)
      offsets = open(path, 'rb:ASCII-8BIT') do |io|
        raise InvalidFontFormat, 'this is not TTC file' if io.read(4) != 'ttcf'
        size = io.size
        verion, num = io.read(8).unpack('NN')
        io.read(4 * num).unpack('N*')
      end
      
      offsets.collect do |off|
        io = open(path, 'rb:ASCII-8BIT')
        io.seek(off)
        font = Module.nesting.last
        font.new(io, autoclose: true)
      end
    end
  end
  
end
