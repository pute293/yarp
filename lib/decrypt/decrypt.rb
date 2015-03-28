# coding: utf-8

# definition of standard decryption filter
# resource:
#   1. http://wwwimages.adobe.com/content/dam/Adobe/en/devnet/pdf/pdfs/PDF32000_2008.pdf
#       define v 1..4; r 2..4
#   2. http://wwwimages.adobe.com/content/dam/Adobe/en/devnet/pdf/pdfs/adobe_supplement_iso32000.pdf
#       define v 5; r 5
#   3. http://wwwimages.adobe.com/content/dam/Adobe/en/devnet/pdf/pdfs/adobe_supplement_iso32000_1.pdf
#       define r 6

require_relative 'standard'

module YARP
  module Decrypt
    
    class InvalidEncryptDictionary < InvalidPdfError; end
    class DecryptFailed < InvalidPdfError; end
    
    def self.create(crypt_dict, doc_id, password='')
      dict = check_dict(crypt_dict)
      did = doc_id.kind_of?(Enumerable) ? doc_id.first : doc_id
      Standard.new(dict, did, password)
    end
    
    def self.check_dict(dict)   # private class method
      f = dict.fetch(:Filter)
      if f != :Standard
        raise InvalidEncryptDictionary, "unknown crypt filter #{f}; expected 'Standard'"
      end
      
      # check version
      v = dict.fetch(:V)
      case v
      when 1, 2, 4, 5
        # ok
      else
        raise InvalidEncryptDictionary, "invalid V value #{v}; expected 1, 2, 4 or 5"
      end
      
      # check revision
      r = dict.fetch(:R)
      case v
      when 1
        raise InvalidEncryptDictionary, "invalid R value #{r} for V #{v}; expected 2" if r != 2
      when 2, 3
        raise InvalidEncryptDictionary, "invalid R value #{r} for V #{v}; expected 3" if r != 3
      when 4
        raise InvalidEncryptDictionary, "invalid R value #{r} for V #{v}; expected 4" if r != 4
      when 5
        case r
        when 5, 6
          # ok
        else
          raise InvalidEncryptDictionary, "invalid R value #{r} for V #{v}; expected 5"
        end
      end
      
      # check user/owner key hash value
      o = dict.fetch(:O)
      u = dict.fetch(:U)
      valid_size = r < 5 ? 32 : 48
      if o.bytesize != valid_size
        raise InvalidEncryptDictionary, "invalid length of owner passward (#{o.bytesize} bytes); expected #{valid_size} bytes"
      elsif u.bytesize != valid_size
        raise InvalidEncryptDictionary, "invalid length of user passward (#{u.bytesize} bytes); expected #{valid_size} bytes"
      end
      # revision 5 needs more key
      if 5 <= r
        oe = dict.fetch(:OE)
        ue = dict.fetch(:UE)
        if oe.bytesize != 32
          raise InvalidEncryptDictionary, "invalid length of owner extended passward (#{oe.bytesize} bytes); expected 32 bytes"
        elsif ue.bytesize != 32
          raise InvalidEncryptDictionary, "invalid length of user extended passward (#{ue.bytesize} bytes); expected 32 bytes"
        end
      end
      
      p = [dict.fetch(:P)].pack('l').unpack('L')[0]
      dict[:P] = p
      
      m = dict[:EncryptMetadata]
      dict[:EncryptMetadata] = m.nil? ? true : m
      
      # check key length
      len = dict[:Length]
      if len.nil?
        #len = nil
      elsif len % 8 != 0
        raise InvalidEncryptDictionary, "invalid key length #{len}; expected multiple of 8"
      elsif len < 40 || 256 < len
        raise InvalidEncryptDictionary, "invalid key length #{len}; expected 40..256"
      end
      # version validation of key length
      case v
      when 1
        len = 40 if len.nil?
        raise InvalidEncryptDictionary, "invalid key length #{len}; expected 40" if len != 40
      when 2, 3, 4
        len = 128 if len.nil?
        raise InvalidEncryptDictionary, "invalid key length #{len}; expected 40..128" unless (40..128).include?(len)
      when 5
        len = 256 if len.nil?
        raise InvalidEncryptDictionary, "invalid key length #{len}; expected 256" if len != 256
      end
      dict[:Length] = len
      
      if 4 <= v
        def_len = len / 8
        stmf = dict[:StmF]
        eff = dict[:EFF]
        dict[:EFF] = eff.nil? ? stmf : eff
        cf = dict[:CF]
        cf.each {|name, hash|
          case name
          when :StdCF, :Identity
            # ok
          else
            raise InvalidEncryptDictionary, "invalid filter name #{name}; expected 'StdCF' or 'Identity'"
          end
          cfm = hash[:CFM]
          case cfm
          when :None
            # ok
          when :V2
            len = hash[:Length] || def_len
            hash[:Length] = len
          when :AESV2
            len = hash[:Length] || def_len
            raise InvalidEncryptDictionary, "invalid key length for AESv2 #{len}; expected 16" if len != 16
            hash[:Length] = len
          when :AESV3
            len = hash[:Length] || def_len
            raise InvalidEncryptDictionary, "invalid key length for AESv3 #{len}; expected 16, 24 or 32" unless [16, 24, 32].include?(len)
            hash[:Length] = len
          when nil
            hash[:CFM] = :None
          else
            raise InvalidEncryptDictionary, "invalid filter method #{cfm}; expected 'None', 'V2', 'AESV2' or 'AESV3'"
          end
        } if cf
      end
      dict
    end
    private_class_method :check_dict
    
  end
end

