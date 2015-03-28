module YARP
  
  def self.open(name)
    Kernel.open(name, 'rb:ASCII-8BIT') do |io|
      doc = Document.new(io)
      yield doc
    end
  end
  
  class Document
    
    attr_reader :version, :catalog, :info
    attr_reader :title, :author, :page_count, :metadata
    alias root catalog
    
    def initialize(io)
      ps = Parser::ObjectParser.new(io)
      @parser = ps
      @xrefs = ps.xrefs
      # get catalog and info objects
      catalog, info = nil, nil
      @xrefs.each do |xref|
        t = xref.trailer
        catalog = t[:Root] if catalog.nil?
        info = t[:Info] if info.nil?
        break if (catalog && info)
      end
      @catalog = catalog.kind_of?(Ref) ? catalog.data : catalog
      @info = case info
        when nil    then {}  # /Info entry is optional
        when Ref then info.data
        else info
      end
      @encrypted = ps.encrypted?
      @pages_root = @catalog[:Pages]
      @page_count = @pages_root[:Count] # /Count entry of root Page-Tree object contains count of all leafs
      v = @catalog[:Version]
      @version = v ? v.to_s : ps.v
      @metadata = @catalog[:Metadata]
      if @metadata && !ps.metadata_encrypted?
        # override metadata decryption method
        def @metadata.decrypt_stream
          raw_stream
        end
      end
      @title = @info[:Title] || ''
      @author = @info[:Author] || ''
    end
    
    def page(n)
      max = @page_count - 1
      raise IndexError, "out of range: #{n}; max value is #{max}" if (n < 0 || max < n)
      @pages_root[n]
    end
    
    def encrypted?
      @encrypted
    end
    
    def objects
      self.to_enum(:each_object)
    end
    
    def each_object
      @xrefs.each {|xref|
        xref.each do |entry|
          obj = entry.realize
          yield obj if (obj && obj.respond_to?(:type))
          # XRefEntry#realize returns nil if the object is not used
        end
      }
    end
    
    def pages
      self.to_enum(:each_page)
    end
    
    def each_page(&block)
      @pages_root.each(&block)
    end
    
    def r(num, gen=0)
      Ref.new(@parser, num, gen).data
    end
    
  end
  
end
