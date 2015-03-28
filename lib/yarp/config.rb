require 'yaml'

module YARP
  
  begin
    config_file = "#{__dir__}/../config.yaml"
    platform = case RUBY_PLATFORM
      #ref:
      # 1. http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-list/36194
      # 2. https://www.ruby-lang.org/ja/news/2010/08/18/ruby-1-9-2-is-released/
      when /mswin(?!ce)|mingw|cygwin|bccwin/i
        'Windows'
      when /linux|(free|net|open)bsdi?|hpux|irix|solaris|sunos|qnx|sysv/i
        'Unix'
      when /darwin/i
        'MacOS'
      when /wince/
        raise LoadError, "Windows CE is not supported"
      when /java|jruby/i
        raise LoadError, "JRuby is not supported"
      when /clr/i
        raise LoadError, "IronRuby is not supported"
      else
        # Symbian, AIX, BeOS(Haiku), Interix, MS-DOS, OS/2, OSF, UXP/DS, etc.
        raise LoadError, "unknown platform #{RUBY_PLATFORM}"
    end
    
    @@config = YAML.load_documents(File.read(config_file)).find{|doc| doc['platform'] == platform}
    raise LoadError, "fail to load 'config.yaml'" unless @@config
    
    @@config.each do |key, val|
      next unless key.end_with?('path')
      pathes = val.collect do |path|
        if platform == 'Windows' && /%([^\/\\%]+)%/ =~ path
          expanded = ENV[$1]
          raise LoadError, "undefined environment value: #{$1}" unless expanded
          path = $` + expanded + $'
        end
        File.expand_path(path)
      end
      @@config[key] = pathes
    end
    
    #any = YAML.load_documents(File.read(config_file)).find{|doc| doc['platform'] == 'any'}
    #any.each do |key, val|
    #  case key
    #  when 'warning'
    #    @@congif[key] = val
    #  end
    #end
    @@config.freeze
  rescue
    # LoadError is not rescued here
    warn "fail to load 'config.yaml'"
    raise
  end
  
end
