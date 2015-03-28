# ============================================================================
# special operators; not in spec
# ============================================================================
defop :pp, 0, [], lambda {|p, args, stack|
  puts '***** top *****'
  p.systemdict[:pstack].call(p)
  puts '**** bottom ***'
}

# ============================================================================
# stack manipulations
# ============================================================================
defop :pop,   1,  [nil],      lambda {|p,args,stack| }
defop :exch,  2,  [nil,nil],  lambda {|p,args,stack| stack.push(args[1],args[0])}
defop :dup,   1,  [nil],      lambda {|p,args,stack| stack.push(args[0],args[0])}
defop :index, 1,  [Integer],  lambda {|p,args,stack|
  n = args[0]
  raise RangeCheck if n < 0
  n += 1
  raise StackUnderFlow if stack.size < n
  stack.push(stack[-n])
}
defop :roll,  2,  [Integer,Integer],  lambda {|p,args,stack|
  n,j = args
  raise RangeCheck if n < 0
  return if n == 0
  raise StackUnderFlow if stack.size < n
  array = stack.pop(n)
  stack.push(*array.rotate(-j))
}
defop :clear,       0,    [], lambda {|p,args,stack| stack.clear}
defop :count,       0,    [], lambda {|p,args,stack| stack.push(stack.size)}
defop :mark,        0,    [], lambda {|p,args,stack| stack.push(MARK)}
defop :cleartomark, MARK, [], lambda {|p,args,stack| }
defop :counttomark, MARK, [], lambda {|p,args,stack| stack.push(MARK, *args, args.size)}

# ============================================================================
# alithmetic operators
# ============================================================================
defop :add,     2,    [Numeric,Numeric],  lambda {|p, args, stack| stack.push(args[0] + args[1])}
defop :div,     2,    [Numeric,Numeric],  lambda {|p, args, stack| stack.push(args[0].to_f / args[1].to_f)}
defop :idiv,    2,    [Numeric,Numeric],  lambda {|p, args, stack| stack.push((args[0].to_f / args[1].to_f).to_i)}
defop :mod,     2,    [Numeric,Numeric],  lambda {|p, args, stack| stack.push(args[0] % args[1])}
defop :mul,     2,    [Numeric,Numeric],  lambda {|p, args, stack| stack.push(args[0] * args[1])}
defop :sub,     2,    [Numeric,Numeric],  lambda {|p, args, stack| stack.push(args[0] - args[1])}
defop :abs,     1,    [Numeric],          lambda {|p, args, stack| stack.push(args[0].abs)}
defop :neg,     1,    [Numeric],          lambda {|p, args, stack| stack.push(-args[0])}
defop :ceiling, 1,    [Numeric],          lambda {|p, args, stack| stack.push(args[0].ceil)}
defop :floor,   1,    [Numeric],          lambda {|p, args, stack| stack.push(args[0].floor)}
defop :round,   1,    [Numeric],          lambda {|p, args, stack| stack.push(args[0].round)}
defop :trancate,1,    [Numeric],          lambda {|p, args, stack| stack.push(args[0].truncate)}
defop :sqrt,    1,    [Numeric],          lambda {|p, args, stack| stack.push(Math.sqrt(args[0]))}
defop :atan,    2,    [Numeric,Numeric],  lambda {|p, args, stack| stack.push(Math.atan2(*args)*180/Math::PI)}
defop :cos,     1,    [Numeric],          lambda {|p, args, stack| stack.push(Math.cos(args[0]*Math::PI/180))}
defop :sin,     1,    [Numeric],          lambda {|p, args, stack| stack.push(Math.sin(args[0]*Math::PI/180))}
defop :exp,     2,    [Numeric,Numeric],  lambda {|p, args, stack| stack.push(args[0].to_f**args[1])}
defop :ln,      1,    [Numeric],          lambda {|p, args, stack| stack.push(Math.log(args[0]))}
defop :log,     1,    [Numeric],          lambda {|p, args, stack| stack.push(Math.log10(args[0]))}
defop :rand,    0,    [],                 lambda {|p, args, stack| stack.push(@@random.rand(0x100000000))}
defop :srand,   1,    [Integer],          lambda {|p, args, stack| @@random.srand(args[0])}
defop :rrand,   0,    [],                 lambda {|p, args, stack| stack.push(@@random.seed)}

# ============================================================================
# array operators
# ============================================================================
defop :']',     MARK, [],                 lambda {|p, args, stack| stack.push(PsArray.new(args))}
defop :array,   1,    [Integer],          lambda {|p, args, stack|
  n = args[0]
  raise RangeCheck if n < 0
  null_array = n.times.collect{ PsNull.new }
  stack.push(PsArray.new(null_array))
}

# ============================================================================
# dictionary operators
# ============================================================================
defop :dict, 1, [Integer], lambda {|p, args, stack|
  n = args[0]
  raise RangeCheck if n < 0
  dict = PsDict.new
  dict.capacity = n
  stack.push(dict)
}
defop :>>, MARK, [], lambda {|p, args, stack|
  raise RangeCheck if args.size.odd?
  stack.push(PsDict[*args])
}
defop :maxlength,   1,  [PsDict], lambda {|p, args, stack| stack.push(args[0].capacity)}
defop :begin,       1,  [PsDict], lambda {|p, args, stack| p.dictionary_stack.push(args[0])}
defop :end,         0,  [],       lambda {|p, args, stack|
  s = p.dictionary_stack
  raise DictStackUnderflow if s.size <= 1
  s.pop
}
defop :def, 2, [nil,nil], lambda {|p, args, stack|
  raise InvalidAccess if p.currentdict.frozen?
  key, val = args
  key = key.intern if key.kind_of?(LiteralName)
  p.currentdict[key] = val
}
defop :load, 1, [nil], lambda {|p, args, stack|
  key = args[0]
  key = key.intern if key.kind_of?(LiteralName)
  p.dictionary_stack.reverse_each {|dict|
    if dict.has_key?(key)
      stack.push(dict[key])
      return
    end
  }
  s = p.systemdict
  if s.has_key?(key)
    stack.push(s[key])
    return
  end
  raise Undefined, "Name #{key} is not defined"
}
defop :store, 2, [nil,nil], lambda {|p, args, stack|
  key,val = args
  key = key.intern if key.kind_of?(LiteralName)
  p.dictionary_stack.reverse_each {|dict|
    if dict.has_key?(key)
      raise InvalidAccess if dict.frozen?
      dict[key] = val
      return
    end
  }
  p.currentdict[key] = val
}
defop :undef, 2, [PsDict,nil], lambda {|p, args, stack|
  args[0].delete(args[1])
}
defop :known, 2, [PsDict,nil], lambda {|p, args, stack|
  stack.push(args[0].has_key?(args[1]))
}
defop :currentdict, 0, [], lambda {|p, args, stack| stack.push(p.currentdict)}
defop :systemdict,  0, [], lambda {|p, args, stack| stack.push(p.systemdict)}

# ============================================================================
# string operations
# ============================================================================
defop :string, 1, [Integer], lambda {|p, args, stack|
  raise RangeCheck if args[0] < 0
  stack.push(PsString.new("\x00"*args[0]))
}
defop :search, 2, [PsString, PsString], lambda {|p, args, stack|
  str, seed = args
  idx = str.to_s.index(seed.to_s)
  if idx
    post_idx = idx + seed.size
    pre = str.get_interval(0, idx)
    match = str.get_interval(idx, seed.size)
    post = str.get_interval(post_idx, str.size - post_idx)
    stack.push(post, match, pre, true)
  else
    stack.push(str, false)
  end
}
defop :anchorsearch, 2, [PsString, PsString], lambda {|p, args, stack|
  str, seed = args
  if str.to_s.start_with?(seed.to_s)
    match = str.get_interval(0, seed.size)
    post = str.get_interval(seed.size, str.size - seed.size)
    stack.push(post, match, true)
  else
    stack.push(str, false)
  end
}

# ============================================================================
# boolean operations
# ============================================================================
defop :eq, 2, [nil,nil], lambda {|p, args, stack| stack.push(args[0] == args[1])}
defop :ne, 2, [nil,nil], lambda {|p, args, stack| stack.push(args[0] != args[1])}
defop :ge, 2, [[Numeric,PsString],[Numeric,PsString]], lambda {|p, args, stack|
  a1, a2 = args
  raise TypeCheck if (a1.class <=> a2.class).nil?
  stack.push(args[0] >= args[1])
}
defop :gt, 2, [[Numeric,PsString],[Numeric,PsString]], lambda {|p, args, stack|
  a1, a2 = args
  raise TypeCheck if (a1.class <=> a2.class).nil?
  stack.push(args[0] > args[1])
}
defop :le, 2, [[Numeric,PsString],[Numeric,PsString]], lambda {|p, args, stack|
  a1, a2 = args
  raise TypeCheck if (a1.class <=> a2.class).nil?
  stack.push(args[0] <= args[1])
}
defop :lt, 2, [[Numeric,PsString],[Numeric,PsString]], lambda {|p, args, stack|
  a1, a2 = args
  raise TypeCheck if (a1.class <=> a2.class).nil?
  stack.push(args[0] < args[1])
}
defop :and, 2, [[Integer,TrueClass,FalseClass],[Integer,TrueClass,FalseClass]],
  lambda {|p, args, stack|
    a1, a2 = args
    if (a1.class <=> a2.class).nil?
      # int & bool / bool & bool
      raise TypeCheck if args.any?{|a|a.kind_of?(Integer)}
    end
    stack.push(a1 & a2)
  }
defop :not, 1, [[Integer,TrueClass,FalseClass]], lambda {|p, args, stack|
  a = args[0]
  if a.kind_of?(Integer)
    stack.push(~a)
  else
    stack.push(!a)
  end
}
defop :or, 2, [[Integer,TrueClass,FalseClass],[Integer,TrueClass,FalseClass]],
  lambda {|p, args, stack|
    a1, a2 = args
    if (a1.class <=> a2.class).nil?
      # int & bool / bool & bool
      raise TypeCheck if args.any?{|a|a.kind_of?(Integer)}
    end
    stack.push(a1 | a2)
  }
defop :xor, 2, [[Integer,TrueClass,FalseClass],[Integer,TrueClass,FalseClass]],
  lambda {|p, args, stack|
    a1, a2 = args
    if (a1.class <=> a2.class).nil?
      # int & bool / bool & bool
      raise TypeCheck if args.any?{|a|a.kind_of?(Integer)}
    end
    stack.push(a1 ^ a2)
  }
defop :bitshift, 2, [Integer,Integer], lambda {|p, args, stack|
  stack.push(args[0] << args[1])
}

# ============================================================================
# control operators
# ============================================================================
defop :exec, 1, [nil], lambda {|p, args, stack|
  a = args[0]
  if a.instance_of?(Symbol)
    a = p.dictionary_stack.reverse_each.find{|dict| dict.has_key?(a) ? (break dict[a]) : false}
    raise Undefined unless a
  end
  
  if a.respond_to?(:executable) && a.executable
    case a
    when Proc, ExecArray
      a.call(p)
    when PsNull
      # do nothing
    when PsString
      # eval
      s = a.to_s
      p.parse(s)
    else stack.push(a)
    end
  else
    stack.push(a)
  end
}
defop :if, 2, [[true,false],:call], lambda {|p, args, stack|
  tf, fn = args
  fn.call(p) if tf
}
defop :ifelse, 3, [[true,false],:call,:call], lambda {|p, args, stack|
  tf, fn1, fn2 = args
  tf ? fn1.call(p) : fn2.call(p)
}
defop :for, 4, [Numeric,Numeric,Numeric,:call], lambda {|p, args, stack|
  cur, inc, limit, fn = args
  check = Proc.new { p.exit_flag ? true : inc < 0 ? cur < limit : limit < cur }
  p.loop_depth += 1
  while true
    break if check.call
    stack.push(cur)
    fn.call(p)
    cur += inc
  end
  p.exit_flag = false
  p.loop_depth -= 1
}
defop :repeat, 2, [Integer,:call], lambda {|p, args, stack|
  n, fn = args
  p.loop_depth += 1
  n.times do
    break if p.exit_flag
    fn.call(p)
  end
  p.loop_depth -= 1
}
defop :loop, 1, [:call], lambda {|p, args, stack|
  fn = args[0]
  loop do
    break if p.exit_flag
    fn.call(p)
  end
}
defop :exit, 0, [], lambda {|p, args, stack|
  raise InvalidExit if p.loop_depth == 0
  p.exit_flag = true
}
defop :quit, 0, [], lambda {|p, args, stack|
  raise QuitCalled
}
defop :eexec, 1, [[IO,StringIO,IOScanner,PsString]], lambda {|p, args, stack|
  a = args[0]
  cipher = a.kind_of?(PsString) ? a.to_s : a.read
  # decrypt ciphered string; see Adobe Type1 Font Format
  r = 0xd971
  c1, c2 = 52845, 22719
  junk_head = 4
  
  end_of_eexec = a.pos + cipher.rindex(/[0\s]{512}/)
  cipher = if p.binmode?
    cipher.bytes
  elsif cipher.bytes[0,512].find{|x|x & 0x80 != 0}
    # binary mode
    p.binmode = true
    cipher.bytes
  else
    cipher.gsub(/\s+/,'').chars.each_slice(2).collect(&:join).collect{|x|x.to_i(16)}
  end
  
  text = cipher.collect{|x|
    plain = x ^ (r >> 8) & 0xff
    r = ((r + x) * c1 + c2) & 0xffff
    plain.chr
  }.drop(junk_head).join
  
  if a.kind_of?(IOScanner)
    s = IOScanner.new(text)
    a.kids.push(s)
    s.parent = a
    a.pos = end_of_eexec
    p.execution_stack.push(s)
    p.parse
  else
    p.parse(text)
  end
}

# ============================================================================
# type operators
# ============================================================================
defop :type, 1, [nil], lambda {|p, args, stack|
  type = case args[0]
    when Symbol, LiteralName
      :nametype
    when PsString then :stringtype
    when PsArray  then :arraytype
    when PsDict   then :dicttype
    when Proc     then :operatortype
    when Integer  then :integertype
    when Numeric  then :realtype
    when PsNull   then :nulltype
    when TrueClass, FalseClass
      :booleantype
    when MARK    then :mark_type
    else raise 'must not happen'
  end
  stack.push(type)
}
defop :cvlit, 1, [nil], lambda {|p, args, stack|
  a = args[0]
  if a.respond_to?(:executable)
    a.executable = false
  elsif a.instance_of?(Symbol)
    a = LiteralName.new(a)
  else
    a.instance_eval {
      @executable = false
      def executable; @executable end
      def executable=(b); @executable = !!b end
    }
  end
  if a.kind_of?(ExecArray)
    stack.push(a.to_psarray)
  else
    stack.push(a)
  end
}
defop :cvx, 1, [nil], lambda {|p, args, stack|
  a = args[0]
  if a.respond_to?(:executable)
    a.executable = true
  elsif a.instance_of?(Symbol)
    # do nothing
  else
    a.instance_eval {
      @executable = true
      def executable; @executable end
      def executable=(b); @executable = !!b end
    }
  end
  ret = case a
  when PsArray
    a.to_execarray
  when LiteralName
    a.intern
  else a
  end
  stack.push(ret)
}
defop :xcheck, 1, [nil], lambda {|p, args, stack|
  a = args[0]
  if a.respond_to?(:executable)
    stack.push(a.executable)
  else
    stack.push(false)
  end
}
defop :executeonly, 1, [nil], lambda {|p, args, stack|
  # TODO
   stack.push(args[0])
}
defop :noaccess, 1, [nil], lambda {|p, args, stack|
  # TODO
   stack.push(args[0])
}
defop :readonly, 1, [nil], lambda {|p, args, stack|
  # TODO
   stack.push(args[0])
  #stack.push(args[0].freeze)
}
defop :cvi, 1, [[Numeric,PsString]], lambda {|p, args, stack|
  i = args[0].kind_of?(Numeric) ? args[0] : args[0].to_s
  # to_f is for expornential value such as "3.3e1"
  stack.push(i.to_f.to_i)
}
defop :cvn, 1, [PsString],  lambda {|p, args, stack|
  a = args[0]
  name = LiteralName.new(a)
  name.executable = a.executable
  stack.push(name)
}
defop :cvr, 1, [[Numeric,PsString]], lambda {|p, args, stack|
  i = args[0].kind_of?(Numeric) ? args[0] : args[0].to_s
  stack.push(i.to_f)
}
defop :cvs, 2, [nil,PsString], lambda {|p, args, stack|
  arg, str = args
  arg = arg.to_s  # polymorphic!
  if str.size < arg.size
    raise RangeCheck
  else
    str.put_interval(0, arg.bytes)
    stack.push(str.get_interval(0, arg.size))
  end
}
defop :cvrs, 3, [Numeric,Integer,PsString], lambda {|p, args, stack|
  arg, radix, str = args
  arg = arg.to_i.to_s(radix)
  if str.size < arg.size
    raise RangeCheck
  else
    str.put_interval(0, arg.bytes)
    stack.push(str.get_interval(0, arg.size))
  end
}

# ============================================================================
# file operators
# ============================================================================
defop :closefile, 1, [[IO,StringIO,IOScanner]], lambda {|p, args, stack|
  case a = args[0]
  when IO, StringIO then a.close
  when IOScanner
    parent = a.parent
    return unless parent
    # return from eexec
    #junk_head = 4
    #p.execution_stack.select{|scanner| scanner == parent}.each{|scanner| warn scanner.pos;scanner.pos += a.pos * (p.binmode? ? 1 : 2) + a.additional_size + 1 + junk_head}
    p.execution_stack.pop
  end
}
defop :read, 1, [[IO,StringIO,IOScanner]], lambda {|p, args, stack|
  io = args[0]
  if io.eof? then stack.push(false)
  else stack.push(io.read(1).ord, true)
  end
}
defop :readstring, 2, [[IO,StringIO,IOScanner], PsString], lambda {|p, args, stack|
  io, pstr = args
  raise RangeCheck if pstr.size == 0
  str = io.read(pstr.size)
  bool = str.bytesize == pstr.size
  pstr.put_interval(0, str.bytes)
  stack.push(pstr.get_interval(0, str.bytesize), bool)
}
defop :readline, 2, [[IO,StringIO,IOScanner], PsString], lambda {|p, args, stack|
  io, str = args
  pos = io.pos
  line = io.readline
  eos = /[\r\n]$/ =~ line
  line = line.chomp
  if str.size < line.bytesize
    str.put_interval(0, line[0, str.size].bytes)
    io.pos = pos + str.size
    raise RangeCheck
  end
  str.put_interval(0, line.bytes)
  stack.push(str.get_interval(0, line.bytesize), !!eos)
}
defop :currentfile, 0, [], lambda {|p, args, stack|
  stack.push(p.scanner)
}
defop :print, 1, [PsString], lambda {|p, args, stack| $stdout.print(args[0].to_s)}
defop '=',    1, [nil],    lambda {|p, args, stack|
  $stdout.puts(args[0].to_s)
}
defop '==',     1,    [nil],          lambda {|p, args, stack|
  a = args[0]
  s = a.respond_to?(:to_string) ? a.to_string : a.to_s
  $stdout.puts(s)
}
defop :stack, 0, [], lambda {|p, args, stack|
  stack.reverse_each do |item|
    $stdout.puts(item.to_s)
  end
}
defop :pstack, 0, [], lambda {|p, args, stack|
  stack.reverse_each do |item|
    s = item.respond_to?(:to_string) ? item.to_string : item.to_s
    $stdout.puts(s)
  end
}

# ============================================================================
# polymorphic operators; spec p.52-53
# ============================================================================
defop :get, 2, [nil,nil], lambda {|p, args, stack|
  arg, key = args
  key = key.intern if key.kind_of?(LiteralName)
  # error check
  case arg
  when PsSequence
    raise TypeCheck unless key.kind_of?(Integer)
    raise RangeCheck if arg.size <= key
  when PsDict
    raise Undefined unless arg.has_key?(key)
  else raise TypeCheck
  end
  stack.push(arg[key])
}
defop :put, 3, [nil,nil,nil], lambda {|p, args, stack|
  arg, key, val = args
  key = key.intern if key.kind_of?(LiteralName)
  raise InvalidAccess if arg.frozen?
  # error check
  case arg
  when PsSequence
    raise TypeCheck unless key.kind_of?(Integer)
    raise RangeCheck if arg.size <= key
  when PsDict # any key/val is ok
    #key = key.intern if key.kind_of?(LiteralName)
  else raise TypeCheck
  end
  arg[key] = val
}
defop :copy, 1, [nil], lambda {|p, args, stack|
  case arg = args[0]
  when Integer
    return if arg == 0
    raise RangeCheck if arg < 0
    raise StackUnderFlow if stack.size < arg
    stack.push(*stack[-arg..-1])
  when PsSequence
    raise StackUnderFlow if stack.empty?
    seq = stack.last
    raise TypeCheck unless seq.instance_of?(arg.class)
    raise InvalidAccess if seq.frozen?
    raise RangeCheck if arg.size < seq.size
    stack.push(stack.pop.copy)
  when PsDict
    raise StackUnderFlow if stack.empty?
    dict = stack.last
    raise TypeCheck unless dict.kind_of?(PsDict)
    stack.pop.each {|k,v| arg[k] = v}
    stack.push(arg)
  else raise TypeCheck
  end
}
defop :length, 1, [nil], lambda {|p, args, stack|
  case arg = args[0]
  when PsSequence, PsDict
    stack.push(arg.size)
  else raise TypeCheck
  end
}
defop :forall, 2, [nil,:call], lambda {|p, args, stack|
  target, fn = args
  case target
  when PsSequence
    target.each {|item| stack.push(item); fn.call(p)}
  when PsDict
    target.each {|k,v| stack.push(k,v); fn.call(p)}
  else raise TypeCheck
  end
}
defop :getinterval, 3, [PsSequence, Integer, Integer], lambda {|p, args, stack|
  stack.push(args[0].get_interval(args[1], args[2]))
}
defop :putinterval, 3, [PsSequence, Integer, PsSequence], lambda {|p, args, stack|
  raise TypeCheck if args[0].class != args[2].class
  args[0].put_interval(args[1], args[2])
}

# ============================================================================
# resource operators
# ============================================================================
defop :defineresource, 3, [LiteralName,nil,LiteralName], lambda {|p, args, stack|
  key, inst, cat = args
  cat = @@resources[cat.intern]
  cat[key.intern] = inst
  stack.push(inst)
}
defop :undefineresource, 2, [LiteralName,LiteralName], lambda {|p, args, stack|
  key, cat = args
  cat = @@resources[cat.intern]
  cat.delete(key.intern)
}
defop :findresource, 2, [LiteralName,LiteralName], lambda {|p, args, stack|
  key, cat = args
  inst = find_resource(cat, key)
  stack.push(inst)
}

# ============================================================================
# glyph and font operators
# ============================================================================
defop :definefont, 2, [LiteralName,PsDict], lambda {|p, args, stack|
  key, fontdict = args
  # decrypt charstring
  pr = fontdict[:Private]
  junk_head = pr ? pr[:lenIV] || 4 : 4
  charstrings = {}
  fontdict[:CharStrings].each do |name, cipher|
    r = 4330
    c1, c2 = 52845, 22719
    text = cipher.bytes.collect{|x|
      plain = x ^ (r >> 8)
      r = ((r + x) * c1 + c2) & 0xffff
      plain.chr
    }.drop(junk_head).join
    charstrings[name] = text
  end
  fontdict[:CharStrings] = charstrings
  
  fonts = @@resources[:Font]
  fonts[key.intern] = fontdict
  stack.push(fontdict)
}
defop :show, 1, [PsString], lambda {|p, args, stack|
  a = args[0]
  $stdout.print(a.to_s)
}

# ============================================================================
# keywards
# ============================================================================
defop :StandardEncoding, 0, [], lambda {|p, args, stack|
  stack.push(PsArray.new(%i{
    .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef
    .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef
    space exclam quotedbl numbersign dollar percent ampersand quoteright parenleft parenright asterisk plus comma hyphen period slash
    zero one two three four five six seven eight nine colon semicolon less equal greater question
    at A B C D E F G H I J K L M N O
    P Q R S T U V W X Y Z bracketleft backslash bracketright asciicircum underscore
    quoteleft a b c d e f g h i j k l m n o
    p q r s t u v w x y z braceleft bar braceright asciitilde .notdef
    .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef
    .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef
    .notdef exclamdown cent sterling fraction yen florin section currency quotesingle quotedblleft guillemotleft guilsinglleft guilsinglright fi fl
    .notdef endash dagger daggerdbl periodcentered .notdef paragraph bullet quotesinglbase quotedblbase quotedblright guillemotright ellipsis perthousand .notdef questiondown
    .notdef grave acute circumflex tilde macron breve dotaccent dieresis .notdef ring cedilla .notdef hungarumlaut ogonek caron
    emdash .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef
    .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef
    .notdef AE .notdef asuperior .notdef .notdef .notdef .notdef Lslash Oslash OE ordmasculine .notdef .notdef .notdef .notdef
    .notdef ae .notdef .notdef .notdef dotlessi .notdef .notdef lslash oslash oe germandbls .notdef .notdef .notdef .notdef
  }))
}


