defop :beginbfchar, 1, [Integer], lambda {|p, args, stack|
  stack.push(MARK)
}
defop :endbfchar, MARK, [], lambda {|p, args, stack|
  args.pop if args.size.odd?  # throw away junk
  map = p.currentdict[:'.unicodemap'] ||= {}
  args.each_slice(2) do |src, dst|
    raise NotImplementedError, 'LiteralName conversion is not implemented yet' unless dst.kind_of?(PsString) # it may be literal name
    raise RangeCheck if dst.empty?
    case dst.size
    when 1,2
      # single character
      map[src.to_s] = [dst.to_integer]
    else
      # multi characters
      ints = dst.each_slice(2).collect{|hi,lo=0|(hi<<8)|lo}
      map[src.to_s] = ints
    end
  end
}
defop :beginbfrange, 1, [Integer], lambda {|p, args, stack|
  stack.push(MARK)
}
defop :endbfrange, MARK, [], lambda {|p, args, stack|
  excess = args.size % 3; args.pop(excess)  # throw away
  p.currentdict[:'.unicodemap'] ||= {}
  map = p.currentdict[:'.unicodemap']
  args.each_slice(3) do |s, e, c|
    case c
    when PsString, PsArray
      # ok
    when LiteralName, Symol
      # it may be array or literal name
      raise NotImplementedError, 'LiteralName conversion is not implemented yet'
    else raise TypeCheck
    end
    count = e.to_integer - s.to_integer + 1
    if c.kind_of?(PsArray)
      # <xxxx> <xxxx> [<xxxx> <xxxx> ... ]
      count.times do |i|
        dst = c[i]
        case dst.size
        when 1,2
          # single character
          map[s.to_s] = [dst.to_integer]
        else
          # multi characters
          ints = dst.each_slice(2).collect{|hi,lo=0|(hi<<8)|lo}
          map[s.to_s] = ints
        end
        s = s.succ
      end
    else
      count.times do |i|
        map[s.to_s] = [c.to_integer]
        s = s.succ
        c = c.succ
      end
    end
  end
}
defop :begincidchar, 1, [Integer], lambda {|p, args, stack|
  stack.push(MARK)
}
defop :endcidchar, MARK, [], lambda {|p, args, stack|
  map = p.currentdict[:'.cidmap'] ||= {}
  args.each_slice(2) {|src, dst| map[src.to_s] = [dst].pack('n')}
}
defop :begincidrange, 1, [Integer], lambda {|p, args, stack|
  stack.push(MARK)
}
defop :endcidrange, MARK, [], lambda {|p, args, stack|
  excess = args.size % 3; args.pop(excess)  # throw away
  map = p.currentdict[:'.cidmap'] ||= {}
  args.each_slice(3) do |s, e, c|
    count = e.to_integer - s.to_integer + 1
    count.times do
      map[s.to_s] = [c].pack('n')
      s = s.succ
      c += 1
    end
  end
}
defop :begincmap, 0, [], lambda {|p, args, stack|
  p.currentdict[:'.cmap'] = true
}
defop :endcmap, 0, [], lambda {|p, args, stack|
  p.currentdict.delete(:'.cmap')
}
defop :begincodespacerange, 1, [Integer], lambda {|p, args, stack|
  stack.push(MARK)
}
defop :endcodespacerange, MARK, [], lambda {|p, args, stack|
  args.pop if args.size.odd?  # throw away junk
  p.currentdict[:'.codespacerange'] ||= []
  range_array = p.currentdict[:'.codespacerange']
  args.each_slice(2) do |s,e|
    s = s.to_integer
    e = e.to_integer
    range_array.push(Range.new(s,e))
  end
}
defop :beginnotdefchar, 1, [Integer], lambda {|p, args, stack|
  stack.push(MARK)
}
defop :endnotdefchar, MARK, [], lambda {|p, args, stack|
  map = p.currentdict[:'.cidmap'] ||= {}
  args.each_slice(2) {|src, dst| map[src.to_s] = [dst].pack('n')}
}
defop :beginnotdefrange, 1, [Integer], lambda {|p, args, stack|
  stack.push(MARK)
}
defop :endnotdefrange, MARK, [], lambda {|p, args, stack|
  excess = args.size % 3; args.pop(excess)  # throw away
  map = p.currentdict[:'.cidmap'] ||= {}
  args.each_slice(3) do |s, e, c|
    count = e.to_integer - s.to_integer + 1
    c = [c].pack('n')
    count.times do
      map[s.to_s] = c
      s = s.succ
    end
  end
}
#defop :beginrearrangedfont
#defop :endrearrangedfont
#defop :beginusematrix
#defop :endusematrix
