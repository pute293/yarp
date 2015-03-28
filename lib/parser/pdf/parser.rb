# coding: utf-8

require 'stringio'
require 'monitor'
require_relative 'pdf.tab'
require_relative 'pdf.lex'

module YARP::Parser
  class ObjectParser
    
    attr_reader :v, :xrefs, :document_id
    attr_reader :object_cache
    
    def initialize(io)
      super()
      #@yydebug = true
      @monitor = Monitor.new  # use as recursive mutex
      @io = io
      @v, @xref_pos = check(io)
      @last_dict = nil  # for stream dictionary
      @accepted = false # for xref table
      @object_cache = {}
      
      # begin parse
      @xrefs = get_xref # xref stream shall not be encrypted
      trailer_has_id = @xrefs.find{|xref|xref.trailer[:ID]}
      @document_id = trailer_has_id ? trailer_has_id.trailer[:ID][0] : nil
      # get encrypt dictionary
      encrypts = @xrefs.collect{|xref|xref[:Encrypt]}.uniq.compact
      @encrypt_obj = case encrypts.size
        when 0 then nil
        when 1 then encrypts[0]
        #else raise InvalidPdfError, "plural encrypt dictionaries"
        else encrypts[0]
        end
      @encrypted = !@encrypt_obj.nil?
      @dec = @encrypted ? YARP::Decrypt.create(@encrypt_obj, @document_id) : nil
    end
    
    # @io offset will not change.
    def parse(from_offset=nil)
      @monitor.synchronize do
        cur = @io.tell
        begin
          @io.seek(from_offset) if from_offset
          warn "$ parse start from #{sprintf('0x%08x', @io.tell)}:#{@io}\n"
          yyparse(self, :parse_obj)
        ensure
          @io.seek(cur)
        end
      end
    end
    
    def parse_string(str)
      StringIO.open(str, 'rb:ASCII-8BIT') do |sio|
        @monitor.synchronize do
          io, @io = @io, sio
          ret = parse
          @io = io
          ret
        end
      end
    end
    
    def deref(refobj)
      n, g = refobj.to_a
      entry = nil
      @xrefs.find do |xref|
        entry = xref.find {|entry|entry.num == n && entry.gen == g}
      end
      raise YARP::InvalidPdfError, "#{n}/#{g} not found" if entry.nil?
      offset = entry.offset
      if offset < 0
        warn "$ realize #{entry}"
        entry.realize
      else
        @monitor.synchronize { parse(entry.offset) }
      end
    end
    
    def decrypt_object!(obj)
      if obj == @encrypt_obj
        obj
      elsif !obj.encrypted?
        obj
      else
        @dec.decrypt_object!(obj)
      end
      nil
    end
    
    def decrypt_stream(obj, raw_bytes)
      if obj == @encrypt_obj
        raw_bytes
      elsif !obj.encrypted?
        raw_bytes
      else
        @dec.decrypt_stream(obj, raw_bytes)
      end
    end
    
    def decrypt_string(obj, raw_bytes)
      if obj == @encrypt_obj
        raw_bytes
      elsif !obj.encrypted?
        raw_bytes
      else
        @dec.decrypt_string(obj, raw_bytes)
      end
    end
    
    def read_stream(offset, length)
      @monitor.synchronize do
        cur = @io.tell
        begin
          @io.seek(offset)
          @io.read(length)
        ensure
          @io.seek(cur)
        end
      end
    end
    
    def encrypted?; @encrypted end
    
    def encrypt_obj?(pdf_obj)
      pdf_obj == @encrypt_obj
    end
    
    def metadata_encrypted?
      @dec.nil? ? false : @dec.metadata_encrypted?
    end
    
    def inspect
      "#<#{self.class}:#{sprintf('%#x', object_id)} @yydebug=#{@yydebug}>"
    end
    
    
    private
    
    def check(io)
      io.seek(0)
      RE_PDF_BEGIN =~ io.read(8)
      on_error('invalid header') unless $&
      v = $1; vv = v.to_f
      on_error("invalid version #{v}") if (vv < 1.0 || 1.8 < vv)
      
      io.seek(-128, IO::SEEK_END)
      trail = ''
      idx = nil
      until idx
        trail = io.read(128) + trail
        io.seek(-256, IO::SEEK_CUR)
        on_error('trailer not found') if io.tell == 0
        idx = trail.rindex(RE_PDF_END)
      end
      RE_PDF_END =~ trail[idx..-1]
      on_error('trailer not found') unless $&
      xref_pos = $1.to_i
      on_error("trailer found at #{xref_pos}; but cannot seek to") if io.seek(xref_pos) != 0
      [v, xref_pos]
    end
    
    def get_xref
      xrefs = []
      offset = @xref_pos
      while offset
        xref = parse(offset)
        xrefs.unshift(xref)
        offset = xref[:Prev]
      end
      xrefs
    end
    
    include ParserBase
    
  end
  
end
