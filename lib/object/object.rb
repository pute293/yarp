require_relative 'ref'
require_relative 'pdfobject'
require_relative 'stream'
require_relative 'xref'
require_relative 'page'
require_relative 'xobject'
require_relative 'image'
require_relative 'font'

module PDF
  class PdfObject   # factory method PDF::PdfObject.create
    
    attr_reader :cache_needed
    
    def self.create(parser, num = -1, gen = 0, data = nil, kwd = {})
      cache = parser.object_cache
      return cache[[num,gen]] if cache.has_key?([num,gen])
      
      klass = nil
      enc = kwd[:encrypted].nil? ? parser.encrypted? : kwd[:encrypted]
      inst = kwd[:in_stream].nil? ? false : true
      args = [parser, num, gen, data, enc, inst]
      case data
      when Hash
        type = data.nil? ? nil : data[:Type]
        klass = case type
          when :XRef    then XRef
          when :Pages   then PageTree
          when :Page    then Page
          when :ObjStm  then ObjStream
          when :Font    then Font
          else
            subtype = data.nil? ? nil : data[:Subtype]
            case subtype
            when :Image then Image
            when :PS    then PostScript
            when :Form
              data[:Subtype2] == :PS ? PostScript : Form
            else
              if data[:_stream_]
                Stream
              else
                PdfObject
              end
            end
        end
      when Array
        #klass = PdfArray
        data.collect!{|item|item.kind_of?(Ref) ? item.data : item}
        #cache[[num,gen]] = data
        def data.type; :'' end
        def data.subtype; :'' end
        return data
      when Numeric, Symbol, String, TrueClass, NilClass
        # number, name, string, true, false, null for each pdf object
        cache[[num,gen]] = data
        return data
      else
        raise InvalidPdfError, "unknown data type: #{data.class}"
      end
      obj = klass.new(*args)
      if enc && klass != XRef
        parser.decrypt_object!(obj)
      end
      cache[[num,gen]] = obj if obj.cache_needed
      obj
    end
  end
end

