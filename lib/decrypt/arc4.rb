# coding: utf-8

# reference: http://inaz2.hatenablog.com/entry/2013/11/30/233649
# 8 bit word ARC4 algolithm

# OpenSSL::Cipher::RC4 usually supports key length just 40 and 128,
# so re-implement RC4 algorithm for arbitrary key length

module PDF::Decrypt
  class Arc4
    @@R = Random.new  # for random_key method
    @@B = ''.b.freeze   # empty string
    @@PAD = "\x00".b.freeze
    
    def initialize(key_len_bits = 128)
      @padding = false  # unused
      @key_len = -1
      @key = @@B.dup
      @table = nil
      @buffer = @@B.dup
      self.key_len_bits = key_len_bits
    end
    
    def decrypt(*args)
      reset
    end
    
    def encrypt(*args)
      reset
    end
    
    def final
      ret = process(@buffer)
      @buffer = @@B.dup
      init_table(@key)
      ret
    end
    
    # initialize @key, @buffer and @table
    def reset
      @buffer = @@B.dup
      self.key = @@B.dup
    end
    
    def update(data)
      @buffer << data.b
      @@B.dup
    end
    alias << update
    
    
    def key; @key end
    def key=(key)
      update_key(key)
      @key
    end
    
    def block_size; 1 end
    def iv=(i); i end
    def iv_len; 0 end
    def key_len; @key_len / 8 end
    def key_len_bits; @key_len end
    def key_len=(i)
      raise ArgumentError, "invalid key length #{i}; it must be 5-256" unless (5..256).include?(i)
      self.key_len_bits = i * 8
      i
    end
    def key_len_bits=(i)
      if i % 8 != 0
        raise NotImplementedError, "currently, only multiple of 8 bit key length is supported; given #{i}"
      elsif not (40..2048).include?(i)
        raise ArgumentError, "invalid key length #{i/8}; it must be 5-256 bytes (40-2048 bits)"
      end
      @key_len = i
      update_key(@key)
      @key_len
    end
    def name; 'Arc4' end
    def padding; @padding end
    def padding=(p)
      @padding = case p
      when 0 then false
      when 1 then true
      else raise ArgumentError, "invalid parameter #{p}; expected 0 or 1"
      end
    end
    def pkcs5_keyivgen(*args); raise NotImplementedError, "#{self.class}#pkcs5_keyivgen" end
    def random_iv; '' end
    def random_key
      len = @key_len / 8
      len += 1 if @ley_len % 8 != 0
      bytes = @@R.bytes(len)
      self.key = bytes
    end
    
    
    private
    
    def update_key(key)
      k = key.b
      len = @key_len / 8
      d = len - k.size
      if 0 < d
        pad = @@PAD * d
        @key = k + pad
      else
        @key = k[0,len]
      end
      init_table(@key)
    end
    
    def init_table(key)
      len = key.size
      s = (0..255).to_a   # translation table
      j = 0
      0.upto(255) {|i|
        j = (j + s[i] + key[i % len].ord) % 256
        s[i], s[j] = s[j], s[i]
      }
      @table = s
    end
    
    def process(data)
      data = data.unpack('C*')
      idx = 0
      max = data.size
      pgra do |x|
        data[idx] ^= x
        idx += 1
        break if idx == max
      end
      data.pack('C*')
    end
    
    def pgra
      s = @table
      i, j = 0, 0
      while true
        i = (i + 1) % 256
        j = (j + s[i]) % 256
        s[i], s[j] = s[j], s[i]
        t = s[i] + s[j]
        yield s[t % 256]
      end
    end
  end
end
