module YARP
  
  begin
    require 'narray'
    NARRAY = true
  rescue LoadError
    warn "gem 'narray' not found; some methods substituted to slower one"
    NARRAY = false
  end
  
  begin
    require 'rmagick'
    RMAGICK = true
  rescue LoadError
    warn "gem 'rmagick' not found; some methods substituted to slower one"
    RMAGICK = false
  end
  
end
