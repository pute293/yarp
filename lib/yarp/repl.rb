require 'optparse'
require 'fileutils'
require 'readline'

module YARP
  
  class << self
    alias :method_missing_old :method_missing
    
    def q; exit end
    
    def repl(doc)
      @doc = doc
      $stdin.sync = $stdout.sync = $stderr.sync = true
      puts "variable `doc' represents PDF document object"
      puts "type `q' or `exit' to exit"
      def self.method_missing(name, *args); @doc.respond_to?(name) ? @doc.send(name, *args) : method_missing_old(name, *args) end
      if $stdin.tty?
        loop do
          line = Readline.readline('$pdf > ', true)
          begin
            str = eval(line, binding).to_s
            puts str.size < 1024 ? str : "#{str[0,1024]} ..."
          rescue
            puts "#{$!}\n#{$@[0]}"
          end
        end
      else
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
  end
  
  version = VERSION
  indent = "\x00"
  bar = "\x01"
  banner = <<-EOS
    === Ruby Implemented PDF Parser (v#{version}) ==================
    Usage:
    #{indent}#{File.basename($0)} any.pdf
    #{indent}#{File.basename($0)} -[f|h|v]
    #{indent}#{File.basename($0)} -e PDF [-o DIR]
    #{bar}
    Options:
  EOS
  banner = banner.gsub(/^ +/, '')
  opts = OptionParser.new
  opts.banner = banner.gsub(indent, opts.summary_indent).gsub(bar, '-' * banner.lines.first.size)
  opts.version = version
  extraction = nil
  dir = nil
  
  opts.on('-f', '--font', 'update font cache') { YARP.update_font; exit(0) }
  opts.on('-e PDF', '--extract=PDF', 'extract images') {|v| extraction = v }
  opts.on('-o DIR', '--output-dir=DIR', 'set output dir; use with --extract') {|v| dir = v }
  opts.on_tail('-h', '--help', 'show this message') { puts opts; puts '=' * banner.lines.first.size; exit(0) }
  opts.on_tail('-v', '--version', 'show version') { puts opts.version; exit(0) }
  
  opts.summary_width = 20
  #opts.default_argv << '--help'
  ARGV << '--help' if ARGV.empty?
  opts.parse!(ARGV)
  
  $stdout.sync = true
  if extraction
    unless File.exist?(extraction)
      puts "#{extraction.force_encoding('UTF-8')} not found"
      exit(1)
    end
    if dir
      if File.exist?(dir) && !File.directory?(dir)
        puts "#{dir} is not directory"
        exit(1)
      end
      begin
        FileUtils.mkdir_p(dir)
        puts "create directory #{dir}"
      rescue
        puts "fail to make directory #{dir}"
        exit(1)
      end
    end
    
    f = extraction
    puts "extracting images from #{f}"
    YARP.open(f) do |doc|
      Dir.chdir(dir)
      doc.each_page.with_index do |page, i|
        images = page.each_image.to_a
        next if images.empty?
        if images.size == 1
          ext, img = images[0].get_image
          n = "#{i.to_s.rjust(3,?0)}.#{ext}"
          puts n
          IO.binwrite(n, img)
        else
          images.each_with_index do |image, j|
            ext, img = image.get_image
            n = "#{i.to_s.rjust(3,?0)}_#{j.to_s.rjust(3,?0)}.#{ext}"
            puts n
            IO.binwrite(n, img)
          end
        end
      end
    end
  else
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
end
