# coding: utf-8

require 'digest/sha2'
require 'openssl'

module PDF::Decrypt
  class Standard  # exntends PDF::Decrypt::Standard for R >= 5 revisions
    
    private
    
    alias set_params_old set_params
    alias init_key_old init_key
    alias calc_user_pass_old calc_user_pass
    alias check_user_pass_old check_user_pass
    alias calc_obj_key_old calc_obj_key
    
    def set_params(dict)
      set_params_old(dict)
      @oe = dict[:OE]
      @ue = dict[:UE]
    end
    
    def init_key(password)
      case @r
      when 2..4
        init_key_old(password)
      when 5
        init_key_r5(password)
      when 6
        init_key_r6(password)
      end
    end
    
    # Revision 5 key calculation results 
    # both of decrytion key and user password.
    def init_key_r5(password)
      user_hash = @u[0,32]
      user_vald = @u[32,8]
      user_salt = @u[40,8]
      
      # truncate utf-8 encoded password to 127 bytes
      pass = password.b
      pass = pass[0,127]    # work only ruby 1.9 or later
      
      # 1. calc user password
      @user_pass = Digest::SHA256.digest(pass + user_vald)
      
      # 2. calc decryption key
      key = Digest::SHA256.digest(pass + user_salt)
      iv = [0,0,0,0].pack('L4')
      aes256(key, iv, @ue[0,32])
    end
    
    # Revision 6 is undocumented formally,
    # but we can reference to
    # http://esec-lab.sogeti.com/post/The-undocumented-password-validation-algorithm-of-Adobe-Reader-X
    # Same as revision 5 (init_key_r5), this calc results both dec-key and user password.
    def init_key_r6(password)
      user_hash = @u[0,32]
      user_vald = @u[32,8]
      user_salt = @u[40,8]
      
      pass = password.b
      pass = pass[0,127]
      
      # 1. calc user password
      @user_pass = hash_r6(pass, user_vald)
      
      # 2. calc decryption key
      key = hash_r6(pass, user_salt)
      iv = [0,0,0,0].pack('L4')
      aes256(key, iv, @ue[0,32])
    end
    
    # return 32-bytes hash value
    def hash_r6(password, salt, vec='')
      # initialization
      pass = password.b[0,127]
      digest = Digest::SHA256
      input = digest.digest(pass + salt.b + vec.b)
      key = input[0,16]
      iv = input[16,16]
      block_size = 32
      aes = OpenSSL::Cipher::AES128.new('CBC')
      
      reset = Proc.new do |key, iv|
        aes.reset
        aes.decrypt
        aes.key = key
        aes.iv = iv
        aes.padding = 0
      end
      
      i = 0
      while (i < 64 && i < x[-1].ord + 32) # short curcuit
        block = input[0,block_size]
        reset.call(key, iv)
        
        x = aes.update(pass + input + vec)
        sum = x.unpack('C16').inject(&:+)
        case sum % 3
        when 0
          block_size = 32
          digest = Digest::SHA256
        when 1
          block_size = 48
          digest = Digest::SHA384
        when 2
          block_size = 64
          digest = Digest::SHA512
        end
        digest.update(x)
        
        64.times do
          x = aes.update(pass + input + vec)
          digest.update(x)
        end
        
        input = digets.final
        key = input[0,16]
        iv = input[16,16]
        i += 1
      end
      input[0,32]
    end
    
    def calc_user_pass
      case @r
      when 2..4
        calc_user_pass_old
      when 5
        @user_pass
      when 6
        raise NotImplementedError, 'revision 6 is not implemented yet'
      end
    end
    
    def check_user_pass
      w = case @r
      when 2..4
        check_user_pass_old
      when 5, 6
        32
      end
      @user_pass[0,w] == @u[0,w]
    end
    
    def calc_obj_key(*args)
      if @stmf[:method] == :AESV3
        @key
      else
        calc_obj_key_old(*args)
      end
    end
    
    def aes256(key, iv, data)
      aes = OpenSSL::Cipher::AES256.new('CBC')
      aes.decrypt
      aes.padding = 0
      aes.iv = iv
      aes.key = key
      result = aes.update(data)
      result << aes.final
      result
    end
  end
end
