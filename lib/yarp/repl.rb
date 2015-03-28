require 'optparse'

module YARP
  
  class << self
    alias :method_missing_old :method_missing
    def repl(doc)
      @doc = doc
      $stdin.sync = $stdout.sync = $stderr.sync = true
      puts "variable `doc' represents PDF document object"
      def self.method_missing(name, *args); @doc.respond_to?(name) ? @doc.send(name, *args) : method_missing_old(name, *args) end
      loop do
        print '$pdf > '
        line = $stdin.readline.strip.gsub(/\e\[\d*[A-D]/, '') # remove escape sequece
        begin
          str = eval(line, binding).to_s
          puts str.size < 1024 ? str : "#{str[0,1024]} ..."
        rescue
          puts "#{$!}\n#{$@[0]}"
        end
      end
    end
  end
  
  version = VERSION
  indent = "\x00"
  bar = "\x01"
  banner = <<-EOS
    === Ruby Implemented PDF Parser (v#{version}) ===
    Usage:
    #{indent}#{$0} -[f|h|v]
    #{indent}#{$0} -- any.pdf
    #{bar}
    Options:
  EOS
  banner = banner.gsub(/^ +/, '')
  opts = OptionParser.new
  opts.banner = banner.gsub(indent, opts.summary_indent).gsub(bar, '-' * banner.lines.first.size)
  opts.version = version
  
  opts.on('-f', '--font', 'update font cache') { YARP.update_font; exit(0) }
  opts.on_tail('-h', '--help', 'show this message') { puts opts; puts '=' * banner.lines.first.size; exit(0) }
  opts.on_tail('-v', '--version', 'show version') { puts opts.version; exit(0) }
  
  opts.summary_width = 16
  opts.default_argv << '--help'
  opts.parse!(ARGV)
  
  until ARGV.empty?
    f = ARGV.shift
    next unless FileTest.file?(f)
    ARGV.clear
    YARP.open(f) do |doc|
      puts f
      repl(doc)
    end
    break
  end
end
