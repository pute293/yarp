#! ruby

class Nn
  
  Loss = {
    # mean squere error function
    :mse => Proc.new {|y, t|
      if y.kind_of?(Enumerable)
        y.zip(t).inject(0){|acc, (y0, t0)| acc + (y0 - t0) * (y0 - t0) / 2.0}
      else
        (y - t) * (y - t) / 2.0
      end
    },
    
    # cross entropy function
    :cef => Proc.new {|y, t|
      if y.kind_of?(Enumerable)
        -(y.zip(t).inject(0){|acc, (y0, t0)| acc + t0 * Math.log(y0) + (1.0 - t0) * Math.log(1.0 - y0)})
      else
        -t * Math.log(y) - (1.0 - t) * Math.log(1.0 - y)
      end
    },
    
  }.freeze
  
  Activator = {
    # identity
    :identity => {
      :f => Proc.new {|x| x},
      :df => Proc.new {|x| 1.0},
    },
    
    # standard sigmoid
    :sigmoid => {
      :f => Proc.new {|x| 1.0 / (1.0 + Math.exp(-x.to_f))},
      :df => Proc.new {|x| s = Activator[:sigmoid][:f].call(x); s * (1.0 - s)},
    },
    
    # hyperbolic tangent
    :tanh => {
      :f => Proc.new {|x| Math.tanh(x.to_f)},
      :df => Proc.new {|x| s = Math.tanh(x.to_f); 1.0 - s * s},
    },
    
    # gaussian
    :gaussian => {
      :f => Proc.new {|x| (Math::E ** -(x * x)) / Math.sqrt(Math::PI)},
      :df => Proc.new {|x| -x * (Math::E ** -(x * x)) / Math.sqrt(Math::PI)},
    },
    
  }.freeze
  
  attr_reader :alpha, :momentum
  
  Default_Activator = :sigmoid
  #Default_Activator = :gaussian
  Default_Loss = :mse
    
  def initialize(input_size, output_size, hidden: 1, hidden_size: 3, activator: Default_Activator, result: nil, loss: Default_Loss, momentum: true)
    result ||= activator
    @input_size = input_size
    @output_size = output_size
    @hidden = hidden
    @hidden_size = hidden_size
    @activator = activator
    @result = result
    @loss = loss
    @momentum = !!momentum
    
    @input_layer = InputLayer.new(self, input_size)
    last_layer = hidden.times.inject(@input_layer) do |last_layer, i|
      last_layer.connect(NnLayer.new(self, hidden_size, activator))
    end
    @output_layer = OutputLayer.new(self, output_size, result, loss)
    last_layer.connect(@output_layer)
  end
  
  def train(input_set, teacher_set, alpha: 0.5, iter: 50, epoch: 10000, batch: 10)
    warn <<EOS
--- start training ---
input size: #{@input_size}
output size: #{@output_size}
hidden layers: #{@hidden}
hidden size: #{@hidden_size}
activator: #{@activator}
result: #{@result}
loss: #{@loss}
initial alpha: #{alpha}
momentum: #{@momentum}
mode: #{iter ? ('iteration ' + (iter < 0 ? '(infinite)' : "(#{iter} times)")) : 'batch'}
----------------------
EOS
    last_layer = @input_layer
    while last_layer
      warn last_layer.class.name
      warn " |> size: #{last_layer.size}"
      warn " |> weight: #{last_layer.weights}"
      warn
      last_layer = last_layer.next_layer
    end
    warn '----------------------'
    
    @output_layer.learn = true
    @alpha = alpha.to_f
    error = Float::NAN
    sets = input_set.zip(teacher_set)
    if iter
      @bacth = false
      errors = [nil] * 100; idx = 0
      iter = iter < 0 ? Float::INFINITY : iter
      (0..iter).lazy.each do |i|
        @alpha *= 0.95
        @alpha = 1e-3 if @alpha < 1e-3
        #@alpha = 0.99 if 1 < @alpha
        set = sets.sample
        @output_layer.teacher = set[1]
        @input_layer.propagete(set[0])
        
        if i % 100000 == 0
          es = errors.collect{|e| e ? e : 0}
          warn "(#{i}) error: #{es.inject(&:+) / es.size}"
        end
        
        errors[idx] = @output_layer.error; idx = (idx + 1) % errors.size
        break if (errors.none?(&:nil?) && errors.inject(&:+) / errors.size < 0.001 && iter.to_f.infinite?)
        #break if (@output_layer.error < 0.001 && iter.to_f.infinite?)
        #@alpha = Math.sqrt(@output_layer.error)
      end
      errors = errors.collect{|e| e ? e : 0}
      error = errors.inject(&:+) / errors.size
    else
      @bacth = true
      epoch.times do
        batch.times do
          @alpha *= 0.99
          @alpha = 1e-3 if @alpha < 1e-3
          set = sets.sample
          @output_layer.teacher = set[1]
          @input_layer.propagete(set[0])
          #warn "#{@output_layer.error} / #{@alpha}"
        end
        @output_layer.restore_best
      end
      error = @output_layer.error
    end
    
    warn '---- end training ----'
    warn "error: #{errors.inject(&:+) / errors.size}"
    warn '----------------------'
    
    last_layer = @input_layer
    while last_layer
      warn last_layer.class.name
      warn " |> size: #{last_layer.size}"
      warn " |> weight: #{last_layer.weights}"
      warn
      last_layer = last_layer.next_layer
    end
  end
  
  def guess(inputs)
    @output_layer.learn = false
    @input_layer.propagete(inputs)
  end
  
  def batch?
    @bacth
  end
  
  class NnLayer
    
    R = Random.new
    attr_reader :size, :weights, :prev_layer, :next_layer
    
    def alpha; @nn.alpha end
    def momentum; @nn.momentum end
    def batch?; @nn.batch? end
    
    def initialize(nn, size, activator)
      @nn = nn
      @prev_layer = nil
      @next_layer = nil
      @size = size
      h = activator.kind_of?(Symbol) ? Activator.fetch(activator) : activator
      @h = h.fetch(:f)
      @dh = h.fetch(:df)
      raise TypeError 'invalid activation function hash' unless (@h.respond_to?(:call) && @dh.respond_to?(:call))
    end
    
    def connect(nxt)
      raise TypeError unless nxt.kind_of?(NnLayer)
      nxt.prev_layer = self
      #@weights = Array.new(size + 1) { Array.new(nxt.size) { R.rand } }
      #nxt.weights = Array.new(size + 1) { Array.new(nxt.size) { (R.rand - 0.5) * 10 } }
      nxt.weights = Array.new(size) { Array.new(nxt.size) { R.rand * 0.1 } }
      nxt.weights.push(Array.new(nxt.size, 0.0))  # bias
      @next_layer = nxt
    end
    
    def propagete(inputs)
      # indices:
      #   i: index of this layer's unit
      #   j: index of next layer's unit
      # values:
      #   weights[i][j]:  join weight of prev unit i and this unit j
      #                   last element of w is the bias of prev layer
      #   inputs[k]: output of previous layer's unit k
      #   a[j]: activation = sum(i=0..)[zi * wij]
      #   z[j]: output to next layer's unit j = h(a[j])
      
      inputs = inputs.dup
      inputs.push(1.0)  # bias
      @x = inputs
      a = @weights.zip(inputs).collect {|wi, xi| wi.collect{|wij| xi * wij}}  # := aij
      #@a_ = a
      @a = a.transpose.collect{|aj| aj.inject(&:+)}
      @z = @a.collect{|aj| @h.call(aj)}
      #puts self.class.name
      #puts " | x: #{@x}"
      #puts " | a: #{@a}"
      #puts " | z: #{@z}"
      #puts
      @next_layer ? @next_layer.propagete(@z) : @z
    end
    
    def back_propagete(delta_upper, w)
      #@a.push(w.transpose.last.inject(&:+)) # activation of bias
      sum = w.collect{|wi| [wi, delta_upper].transpose.collect{|wij, dj| wij * dj}.inject(&:+)}
      #@delta = [@a, sum].transpose.collect{|aj, sj| @dh.call(aj) * sj}
      @delta = @a.zip(sum).collect{|aj, sj| @dh.call(aj) * sj}
      @grad = @x.collect{|xi| @delta.collect{|dj| dj * xi}}
      #puts self.class.name
      #puts " | d: #{@delta}"
      #puts " | a: #{@a}"
      #puts " | s: #{sum}"
      #puts " | g: #{@grad}"
      #puts " | w: #{@weights}"
      #puts
      #puts " | o: #{@z}"
      #puts " | d: #{delta}"
      #p @weights.transpose
      
      @prev_layer.back_propagete(@delta, @weights) if @prev_layer
    end
    
    protected
    
    attr_writer :weights, :prev_layer, :next_layer
    attr_reader :delta, :grad
    
    def update(save=true)
      if momentum
        if @moment
          @grad = @moment = [@grad, @moment].transpose.collect{|gi, mi| [gi, mi].transpose.collect{|gij, mij| alpha * mij + gij}}
          #@h = @h + alpha * 
          #p @moment
          #p @grad
          #p g
          #raise "a"
        else
          # first time
          @moment = @grad
        end
      end
      @weights = [@weights, @grad].transpose.collect do |wi, gi|
        [wi, gi].transpose.collect{|wij, gij| wij - alpha * gij}
      end
      self.save if save
      @next_layer.update if @next_layer
    end
    
    def save; (@save ||= []).push(@weights) end
    
    def restore(idx)
      @weights = @save.fetch(idx)
      @save = []
    end
    
  end
  
  class InputLayer < NnLayer
    
    def initialize(nn, size)
      super(nn, size, :identity)
    end
    
    def propagete(inputs)
      #puts self.class.name
      #puts " | x: #{inputs}"
      #puts
      @next_layer.propagete(inputs)
    end
    
    def back_propagete(*args)
      @next_layer.update(batch?)
    end
  end
  
  class OutputLayer < NnLayer
    
    attr_reader :error, :result
    attr_accessor :learn
    
    def initialize(nn, size, activator, loss)
      super(nn, size, activator)
      #@dh = Proc.new{|x| x}
      @e = loss.kind_of?(Symbol) ? Loss.fetch(loss) : loss
      @error = Float::NAN
      @result = nil
      @learn = false
      raise TypeError 'error function e must be Proc' unless @e.kind_of?(Proc)
    end
    
    def teacher=(v)
      raise KeyError, 'invalid size' if v.size != self.size
      @t = v
    end
    
    def propagete(inputs)
      @next_layer = nil
      @result = y = super
      #@x = inputs
      #@result = @z = inputs#.collect {|zj| @h.call(zj)}
      #p [inputs, @z[0], @t[0]]
      @error = @e.call(@z, @t)
      #puts self.class.name
      #puts " | z: #{@z}"
      #puts " | t: #{@t}"
      #puts " | e: #{@error}"
      #puts
      learn ? back_propagete : @result
    end
    
    def back_propagete
      @delta = @z.zip(@t).collect{|y, t| y - t}
      @grad = @x.collect{|xi| @delta.collect{|dj| dj * xi}}
      #puts self.class.name
      #puts " | d: #{@delta}"
      #puts " | g: #{@grad}"
      #puts " | w: #{@weights}"
      #puts
      @prev_layer.back_propagete(@delta, @weights)
    end
    
    def save; (@save ||= []).push([@error, @weights]) end
    
    def restore_best
      idx = @save.index(@save.min)
      @error, @weights = @save[idx]
      @save = []
      @prev_layer.restore(idx)
    end
  end
  
end

cf = 4.times.collect{ Random.rand - 0.5 }
#y = proc {|x| cf[0] + cf[1] * x + cf[2] * x * x}
y = proc {|x| cf[0] + cf[1] * x + cf[2] * x * x + cf[3] * x * x * x}
x = 1000.times.collect{ (Random.rand - 0.5) * 10 }
#x = xs.take(10)
t = x.collect{|x0| y.call(x0)}
warn "cf: #{cf}"
#warn "x: #{x}"
#warn "t: #{t}"
warn
nn = Nn.new(1, 1, hidden: 1, hidden_size: 4, activator: :gaussian, result: :identity)
nn.train(x.collect{|xx|[xx]}, t.collect{|tt|[tt]}, iter:100000)

#x = 100.times.collect{ (Random.rand - 0.5) * 50 }
#t = x.collect{|x0| y.call(x0)}
puts "# x\ty1\ty2"
x.collect{|x0| [x0, y.call(x0), nn.guess([x0])[0]]}.sort.each{|a| puts a.collect(&:to_s).join("\t")}
#  p [x0, nn.guess([x0])[0], y0]
#end

