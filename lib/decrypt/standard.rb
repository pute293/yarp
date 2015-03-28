# coding: utf-8

require 'digest/md5'
require 'openssl'
require_relative 'arc4'

module YARP::Decrypt
  class Standard
    
    # password is used for only initialize key
    def initialize(dict, did, password)
      require_relative 'standard_ex' if 5 <= dict[:V]
      set_params(dict)
      #@filters = {:Identity => {}}
      @filters = {}
      @stmf, @strf, @eff = nil, nil, nil
      @did = did
      if 4 <= @v
        cf = dict[:CF]
        cf.each {|name, hash| @filters[name] = {:method => hash[:CFM], :length => hash[:Length]} } if cf
        @stmf = @filters.fetch(dict[:StmF])
        @strf = @filters.fetch(dict[:StrF])
        @eff = @filters.fetch(dict[:EFF])
      else
        hash = {:method => :V2, :length => @bitlen / 8}
        @stmf = @strf = @eff = hash
      end
      @key = init_key(password)
      @user_pass = calc_user_pass()
      unless check_user_pass()
        calc = @user_pass.bytes.collect{|x|'%02x' % x}.join('-')
        expected = @u.bytes.collect{|x|'%02x' % x}.join('-')
        raise DecryptFailed, "user password calculation failed; calced: #{calc}, expected: #{expected}"
      end
      @key_cache = {}
    end
    
    def metadata_encrypted?
      @m
    end
    
    def decrypt_string(pdf_obj, raw_bytes)
      obj_key = calc_obj_key(pdf_obj.num, pdf_obj.gen)
      filter = @strf
      decrypt_str_impl(obj_key, filter, raw_bytes)
    end
    
    def decrypt_stream(pdf_obj, raw_bytes)
      obj_key = calc_obj_key(pdf_obj.num, pdf_obj.gen)
      filter = @stmf
      decrypt_str_impl(obj_key, filter, raw_bytes)
    end
    
    def decrypt_object!(pdf_obj)
      key = calc_obj_key(pdf_obj.num, pdf_obj.gen)
      data = pdf_obj.dict
      return pdf_obj if (data.nil? || data.empty?)
      case data
      when Hash
        decrypt_hash!(pdf_obj, data)
      when Array
        decrypt_array!(pdf_obj, data)
      end
      pdf_obj
    end
    
    def decrypt_hash!(pdf_obj, dict)
      dict.each do |key, val|
        dict[key] = case val
          when String
            decrypt_string(pdf_obj, val)
          when Array
            decrypt_array!(pdf_obj, val)
          when Hash
            decrypt_hash!(pdf_obj, val)
          else val
        end
      end
    end
    
    def decrypt_array!(pdf_obj, array)
      array.collect! do |val|
        case val
        when String
          decrypt_string(pdf_obj, val)
        when Array
          decrypt_array!(pdf_obj, val)
        when Hash
          decrypt_hash!(pdf_obj, val)
        else val
        end
      end
    end
    
    
    private
    
    def decrypt_str_impl(obj_key, filter, raw_bytes)
      size = raw_bytes.size
      return raw_bytes if size == 0
      
      case filter[:method]
      when :None
        return raw_bytes
      when :V2
        rc4 = Arc4.new(obj_key.size * 8)
        rc4.key = obj_key
        result = rc4.update(raw_bytes)
        result << rc4.final
        return result
      when :AESV2, :AESV3
        if size % 16 != 0
          raise DecryptFailed, "invalid stream length #{size}; exptected multiple of 16", caller(1)
        elsif size == 16
          return ''.b   # empty stream
        elsif size < 32
          raise DecryptFailed, "invalid stream length #{size}; exptected 32 or greater", caller(1)
        end
        iv = raw_bytes[0,16]
        raw_bytes = raw_bytes[16..-1]
        aes = OpenSSL::Cipher::AES.new(filter[:length] * 8, 'CBC')
        aes.decrypt
        aes.padding = 0
        aes.iv = iv
        aes.key = obj_key
        result = aes.update(raw_bytes)
        result << aes.final
        return result.b
        # OpenSSL::Cipher::AES always returns ascii-8bit string,
        # but it is undocumented so Strng#b method used
      end
    end
    
    PADDING = [
      0x28, 0xBF, 0x4E, 0x5E, 0x4E, 0x75, 0x8A, 0x41,
      0x64, 0x00, 0x4E, 0x56, 0xFF, 0xFA, 0x01, 0x08,
      0x2E, 0x2E, 0x00, 0xB6, 0xD0, 0x68, 0x3E, 0x80,
      0x2F, 0x0C, 0xA9, 0xFE, 0x64, 0x53, 0x69, 0x7A
    ].collect{|i|i.chr}.join
    
    def set_params(dict)
      # for initialization
      @v, @r = dict[:V], dict[:R]
      @o, @u = dict[:O], dict[:U]
      @p, @m = dict[:P], dict[:EncryptMetadata]
      @bitlen = dict[:Length]
    end
    
    def init_key(password)
      buf = password.b
      if buf.size < 32
        buf = (buf + PADDING)[0,32]
      elsif 32 < buf.size
        buf = buf[0,32]
      end
      buf << @o
      buf << [@p].pack('L')
      buf << @did
      buf << [-1].pack('L') if (!@m && 4 <= @r)
      key = Digest::MD5.digest(buf)
      n = @bitlen / 8
      50.times { key = Digest::MD5.digest(key)[0, n] } if 3 <= @r
      len = @r == 2 ? 5 : n
      key[0,len]
    end
    
    # get 32 byte password
    def calc_user_pass
      key = @key
      rc4 = Arc4.new(@bitlen)
      rc4.decrypt
      result = ''.b
      case @r
      when 2
        rc4.key = key
        result = rc4.update(PADDING)
        result << rc4.final
      when 3, 4
        rc4.key = key
        result = rc4.update(Digest::MD5.digest(PADDING + @did))
        result << rc4.final
        1.upto(19) do |i|
          xor_key = key.bytes.collect{|x|(x^i).chr}.join
          rc4.reset
          rc4.key = xor_key
          result = rc4.update(result)
          result << rc4.final
        end
        result << PADDING
      end
      result[0, 32]
    end
    
    # check @user_pass is valid
    def check_user_pass
      w = case @r
      when 2
        32
      when 3, 4
        16
      end
      @user_pass[0,w] == @u[0,w]
    end
    
    # get key for object decryption
    def calc_obj_key(num, gen)
      cache = @key_cache[[num,gen]]
      return cache if cache
      buf = @key.dup
      buf << [num].pack('L')[0,3]
      buf << [gen].pack('L')[0,2]
      buf << [0x546c4173].pack('L') if @stmf[:method] == :AESV2 # "sAlT"
      key = Digest::MD5.digest(buf)
      n = (@bitlen / 8) + 5
      n = 16 if 16 < n
      key = key[0,n]
      @key_cache[[num,gen]] = key
      key
    end
  end
end

