require 'dxruby'

def Window.draw_spline2(x0, y0, x1, y1, x2, y2, color=[0, 0, 0], div: 20)
  if div <= 1.0
    self.draw_line(x0, y0, x1, y1, color)
    self.draw_line(x1, y1, x2, y2, color)
    return
  end
  
  dt = 1.0 / div
  ctrls = 0.0.step(1.0, dt).collect do |t|
    u = 1 - t
    u2 = u * u
    t2 = t * t
    tu = u * t
    x = u2 * x0 + 2 * tu * x1 + t2 * x2
    y = u2 * y0 + 2 * tu * y1 + t2 * y2
    [x, y]
  end
  
  ctrls.unshift([x0, y0])
  ctrls.push([x2, y2])
  
  ctrls.each_cons(2){|pt0, pt1| self.draw_line(*pt0, *pt1, color)}
end

def Window.draw_spline3(x0, y0, x1, y1, x2, y2, x3, y3, color=[0, 0, 0], div: 20)
  if div <= 1.0
    self.draw_line(x0, y0, x1, y1, color)
    self.draw_line(x1, y1, x2, y2, color)
    self.draw_line(x2, y2, x3, y3, color)
    return
  end
  
  dt = 1.0 / div
  ctrls = 0.0.step(1.0, dt).collect do |t|
    u = 1 - t
    u2 = u * u
    u3 = u2 * u
    t2 = t * t
    t3 = t2 * t
    tu = u * t
    x = u3 * x0 + 3 * u2 * t * x1 + 3 * u * t2 * x2 + t3 * x3
    y = u3 * y0 + 3 * u2 * t * y1 + 3 * u * t2 * y2 + t3 * y3
    [x, y]
  end
  
  ctrls.unshift([x0, y0])
  ctrls.push([x3, y3])
  
  ctrls.each_cons(2){|pt0, pt1| self.draw_line(*pt0, *pt1, color)}
end

