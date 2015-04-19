#! ruby

require 'stringio'
require 'pp'
require_relative '../lib/yarp'
require_relative 'glyph/glyph'

$bar = '-' * 80
$barb = '=' * 80

class Integer
  def to_f2dot14
    raise TypeError, 'overflow' unless (0..0xffff).include?(self)
    mantissa = case self >> 14
      when 0 then 0
      when 1 then 1
      when 2 then -2
      when 3 then -1
    end
    frac = Rational(self & 0b0011_1111_1111_1111, 16384)  # 16384 == 0b0100_0000_0000_0000
    (mantissa + (mantissa < 0 ? -frac : frac)).to_f
  end
end

def show_glyph(window, glyph, show_box, show_point, show_metrics, aa)
  window.caption = "#{glyph.font.fullname.first} / #{glyph.gid}"
  unless glyph.valid?
    window.draw_font_ex(5, 0, "GID #{glyph.gid}", $font, color: [0,0,0])
    str = glyph.composite? ? 'composite glyph' : 'not defined'
    window.draw_font_ex(5, 16, str, $font, color: [0,0,0])
    return
  end
  
  w, h = window.width, window.height
  
  font = glyph.font
  xmin, xmax, ymin, ymax = %i{ xmin xmax ymin ymax }.collect{|sym| font.send(sym)}
  fw = xmax - xmin
  fh = ymax - ymin
  fs = [fw, fh].max.to_f
  r = w / fs * $scale.to_f
  mx, my = $margin_x, $margin_y
  
  gxmin, gxmax, gymin, gymax = %i{ xmin xmax ymin ymax }.collect{|sym| glyph.send(sym)}
  
  # bounding box
  bbox = [gxmin * r + mx, h - gymin * r - my, gxmax * r + mx, h - gymax * r - my]
  if show_box
    bbox0 = [xmin * r + mx, h - ymin * r - my, xmax * r + mx, h - ymax * r - my]
    bbox0_h_dotline = Image.create_from_array(1, h, ([[128, 0, 0, 255], [0, 0, 0, 0]] * (h / 2)).flatten(1))
    bbox0_v_dotline = Image.create_from_array(w, 1, ([[128, 0, 0, 255], [0, 0, 0, 0]] * (w / 2)).flatten(1))
    window.draw_box_fill(*bbox0, [200, 200, 255])
    window.draw(bbox0[0], 0, bbox0_h_dotline)
    window.draw(0, bbox0[1], bbox0_v_dotline)
    window.draw(bbox0[2], 0, bbox0_h_dotline)
    window.draw(0, bbox0[3], bbox0_v_dotline)
    window.draw_box_fill(*bbox, [255, 200, 200])
    
    if hhea = font[:hhea]
      ascender = hhea[:ascender]; ash = h - ascender * r - my
      descender = hhea[:descender]; dsh = h - descender * r - my
      hhea_h_dotline = Image.create_from_array(w, 1, ([[255, 0, 0, 255], [0, 0, 0, 0]] * (w / 2)).flatten(1))
      window.draw(0, ash, hhea_h_dotline)
      window.draw(0, dsh, hhea_h_dotline)
      dx = $font_small.get_width("ascender=#{ascender}")
      window.draw_font_ex(w - dx - 5, ash,  "ascender=#{ascender}", $font_small, color: [0,0,255])
      dx = $font_small.get_width("descender=#{descender}")
      window.draw_font_ex(w - dx - 5, dsh - 11,  "descender=#{descender}", $font_small, color: [0,0,255])
    end
  end
  
  # axes
  #origin = [[-gxmin, 0].max * r, [-gymin, 0].max * r]
  origin = [0, 0]
  window.draw_line(0, h - origin[1] - my, w, h - origin[1] - my, [32, 0, 0, 0]) # x-axis
  window.draw_line(origin[0] + mx, 0, origin[0] + mx, h, [32, 0, 0, 0])         # y-axis
  
  # horizontal and vertical metrics
  if show_metrics
    # horizontal
    aw, lsb = glyph.aw, glyph.lsb
    h_dotline = Image.create_from_array(1, h, ([[128, 255, 0, 0], [0, 0, 0, 0]] * (h / 2)).flatten(1))
    aw_x, lsb_x = [aw, lsb].collect{|w| w * r + mx}
    aw_y = lsb_y = h - origin[1] - my - 3
    window.draw(aw_x, 0, h_dotline)
    window.draw_font_ex(aw_x + 5, h - 12,  "aw=#{aw}", $font_small, color: [255,0,0])
    window.draw(lsb_x, 0, h_dotline)
    lsb_w = $font_small.get_width("lsb=#{lsb}")
    window.draw_font_ex(lsb_x - lsb_w - 3, h - 12,  "lsb=#{lsb}", $font_small, color: [255,0,0])
    
    # vertical
    ah, tsb = glyph.ah, glyph.tsb
    if tsb
      v_dotline = Image.create_from_array(w, 1, ([[128, 0, 0, 255], [0, 0, 0, 0]] * (w / 2)).flatten(1))
      tsb_x = origin[0] + mx - 3
      tsb_y = h - (gymax + tsb) * r - my - 3
      window.draw(0, tsb_y + 3, v_dotline)
      window.draw_font_ex(3, tsb_y + 5,  "tsb=#{tsb}", $font_small, color: [0,0,0])
      if ah
        ah_x = origin[0] + mx - 3
        ah_y = tsb_y + ah * r
        window.draw(0, ah_y + 3, v_dotline)
        #window.draw(ah_x, ah_y, ah_box)
        #window.draw_font_ex(ah_x - 12, ah_y + 5,  "ah", $font_small, color: [0,0,0])
        #window.draw_font_ex(ah_x - 28, ah_y + 15,  ah.to_s.rjust(5), $font_small, color: [0,0,0])
        window.draw_font_ex(3, ah_y + 5,  "ah=#{ah}", $font_small, color: [0,0,0])
      end
    end
  end
  
  # glyph
  points = glyph.coordinates.collect{|x, y, on| [x * r, y * r, on]}
  first_idx = 0
  on_box = Image.new(6, 6); on_box.circle_fill(3, 3, 3, [0, 0, 255])
  off_box = Image.new(6, 6); #off_box.box(0, 0, 5, 5, [255, 0, 0])
  off_box.line(0, 0, 5, 5, [255, 0, 0]); off_box.line(0, 5, 5, 0, [255, 0, 0])
  glyph.eoc.each do |idx|
    pts = points[first_idx..idx] << points[first_idx]
    pts[0][2] = true
    
    if aa
      pt_idx = first_idx
      dummy_box = Image.new(6, 6); dummy_box.circle_fill(3, 3, 3, [255, 0, 0])
      
      from = pts.shift
      real_knot = from[2]
      until pts.empty?
        to = pts.shift
        x0, y0 = real_knot ? [from[0] + mx, h - from[1] - my] : from
        x1, y1 = to[0] + mx, h - to[1] - my
        
        if show_point
          if real_knot
            window.draw(x0 - 2, y0 - 2, on_box)
            window.draw_font_ex(x0 + 2, y0 + 2, pt_idx.to_s, $font_small, color: [0,0,255])
            pt_idx += 1
          else
            window.draw_alpha(x0 - 2, y0 - 2, dummy_box, 128)
          end
        end
        
        if to[2]
          # straigh line
          window.draw_line(x0, y0, x1, y1, [0, 0, 0])
          from = to
          real_knot = true
        else
          # "to", x1 and y1 defined above is control point
          window.draw(x1 - 3, y1 - 3, off_box) if show_point
          to = pts.shift
          x2 = to[0] + mx
          y2 = h - to[1] - my
          if $bezier
            # 3-order bezier curve
            if show_point
              window.draw(x2 - 3, y2 - 3, off_box)
              window.draw_font_ex(x1 + 2, y1 + 2, pt_idx.to_s, $font_small, color: [255,0,0])
              window.draw_font_ex(x2 + 2, y2 + 2, (pt_idx + 1).to_s, $font_small, color: [255,0,0])
              pt_idx += 2
            end
            to = pts.shift
            x3 = to[0] + mx
            y3 = h - to[1] - my
            window.draw_spline3(x0, y0, x1, y1, x2, y2, x3, y3, [0, 0, 0])
            from = to
            real_knot = true
          elsif to[2]
            if show_point
              window.draw_font_ex(x1 + 2, y1 + 2, pt_idx.to_s, $font_small, color: [255,0,0])
              pt_idx += 1
            end
            window.draw_spline2(x0, y0, x1, y1, x2, y2, [0, 0, 0])
            from = to
            real_knot = true
          else
            # center of [x1, y1] and [x2, y2] is temporary knot point
            if show_point
              window.draw_font_ex(x1 + 2, y1 + 2, pt_idx.to_s, $font_small, color: [255,0,0])
              pt_idx += 1
            end
            pts.unshift(to)
            x2, y2 = [(x1 + x2) / 2, (y1 + y2) / 2]
            window.draw_spline2(x0, y0, x1, y1, x2, y2, [0, 0, 0])
            from = [x2, y2]
            real_knot = false
          end
        end
      end
    else
      pt_idx = first_idx
      pts.each_cons(2) do |from, to|
        x0, y0 = from[0] + mx, h - from[1] - my
        x1, y1 = to[0] + mx, h - to[1] - my
        if show_point
          if from[2]
            window.draw(x0 - 2, y0 - 2, on_box)
            pt_color = [0, 0, 255]
          else
            window.draw(x0 - 3, y0 - 3, off_box)
            pt_color = [255, 0, 0]
          end
          window.draw_font_ex(x0 + 2, y0 + 2, pt_idx.to_s, $font_small, color: pt_color)
          pt_idx += 1
        end
        window.draw_line(x0, y0, x1, y1, [0, 0, 0])
      end
    end
    first_idx = idx + 1
  end
  
  # anchors
  if show_point && !glyph.anchors.empty?
    anchor_box = Image.new(10, 10)
    anchor_box.line(0, 0, 9, 9, [255, 0, 255]); anchor_box.line(0, 9, 9, 0, [255, 0, 255])
    anchor_box.circle_fill(5, 5, 3, [255, 0, 255])
    y_center = bbox[1] / 2
    xy = []
    glyph.anchors.each do |klass, x, y|
      x = x * r + mx
      y = h - y * r - my
      dx = $font_small.get_width(klass)
      dy = y < y_center ? -16 : 7
      dy *= xy.count([x, y]) + 1
      window.draw_font_ex(x - dx / 2, y + dy, klass, $font_small, color: [0,0,0])
      window.draw(x - 5, y - 5, anchor_box)
      xy.push([x, y])
    end
  end
  
  
  # infomations
  y = 0
  s = $font.size
  window.draw_font_ex(5, y,  "GID #{glyph.gid}", $font, color: [0,0,0]); y += s
  #window.draw_font_ex(5, 16, "O=(#{origin[0].round(3)}, #{origin[1].round(3)})", $font, color: [0,0,0]); y += s
  window.draw_font_ex(5, y, "#{glyph.uni ? glyph.uni.collect{|u|'U+%04x'%u}.join(', ') : 'U+????'}", $font, color: [0,0,0]); y += s
  window.draw_font_ex(5, y, "scale=#{r.round(3)}", $font, color: [0,0,0]); y += s
  window.draw_font_ex(5, y, "x=(#{gxmin}..#{gxmax}), y=(#{gymin}..#{gymax})", $font, color: [0,0,0]); y += s
  mouse_x, mouse_y = Input.mouse_pos_x, Input.mouse_pos_y
  mouse_x = (mouse_x - mx) / r - origin[0]; mouse_y = (h - mouse_y - my) / r - origin[1]
  window.draw_font_ex(5, y, "(#{mouse_x.round(3)}, #{mouse_y.round(3)})", $font, color: [0,0,0]); y += s
  window.draw_font_ex(5, y, 'Features:', $font, color: [0,0,0]); y += s
  features = glyph.features
  if features.nil?
    # do nothing
  elsif features.empty?
    window.draw_font_ex(21, y, '(none)', $font, color: [0,0,0]); y += s
  else
    features.each {|ft| window.draw_font_ex(21, y, "<#{ft}>", $font, color: [0,0,0]); y += s}
  end
end

require 'dxruby'
require_relative 'extension/spline'

Margin_X = 50
Margin_Y = 50
Scale = Rational(1, 1)
Scale_a = Rational(2, 3)
$margin_x = Margin_X
$margin_y = Margin_Y
$scale = Scale
$font = Font.new(16, 'Consolas')
$font_small = Font.new(12, 'Consolas')

#until ARGV.empty?
font_path = ARGV.shift || 'c:/windows/fonts/arial.ttf'
#next unless /\.[ot]tf$/ =~ font_path
#next unless FileTest.file?(font_path)
#puts font_path
font = YARP::Utils::Font.new(font_path)
cmaps = font.get_cmaps.select(&:unicode_keyed?)
gpos = font[:GPOS]
#end
#exit
$bezier = font.kind_of?(YARP::Utils::Font::OpenType)
max_gid = font.glyphcount - 1
gid = 0
glyph = Glyph.new(font, gid, cmaps, gpos)

$width = 512
$height = 512

Window.width = $width
Window.height = $height
Window.bgcolor = [255, 255, 255]
Window.fps = 30

Input.set_repeat(10, 5)

def Input.key_repeat_off(*keys)
  keys.flatten.each {|key| self.set_key_repeat(key, 0, 0)}
end

key_to_off = [
  K_A, K_S, K_D, K_LALT, K_RALT, K_0, K_1, K_2, K_3, K_4, K_5, K_6, K_7, K_8, K_9,
  K_NUMPAD0, K_NUMPAD1, K_NUMPAD2, K_NUMPAD3, K_NUMPAD4, K_NUMPAD5, K_NUMPAD6, K_NUMPAD7, K_NUMPAD8, K_NUMPAD9,
  K_TAB,
]
Input.key_repeat_off(key_to_off)

Input.set_cursor(IDC_CROSS)

# config
gid_changed = true
show_box = true
show_point = true
show_metrics = true
aa = true
gid_wait = nil

begin
Window.loop do
  show_glyph(Window, glyph, show_box, show_point, show_metrics, aa)
  
  #a = Input.key_down?(K_LALT) || Input.key_down?(K_RALT)
  s = Input.key_down?(K_LSHIFT) || Input.key_down?(K_RSHIFT)
  c = Input.key_down?(K_LCONTROL) || Input.key_down?(K_RCONTROL)
  #gid+=1;glyph=Glyph.new(font,gid,cmaps, gpos)
  case
  when Input.key_down?(K_LALT) || Input.key_down?(K_RALT)
    gid_wait ||= []
    n = case
    when Input.key_push?(K_0) || Input.key_push?(K_NUMPAD0) then 0
    when Input.key_push?(K_1) || Input.key_push?(K_NUMPAD1) then 1
    when Input.key_push?(K_2) || Input.key_push?(K_NUMPAD2) then 2
    when Input.key_push?(K_3) || Input.key_push?(K_NUMPAD3) then 3
    when Input.key_push?(K_4) || Input.key_push?(K_NUMPAD4) then 4
    when Input.key_push?(K_5) || Input.key_push?(K_NUMPAD5) then 5
    when Input.key_push?(K_6) || Input.key_push?(K_NUMPAD6) then 6
    when Input.key_push?(K_7) || Input.key_push?(K_NUMPAD7) then 7
    when Input.key_push?(K_8) || Input.key_push?(K_NUMPAD8) then 8
    when Input.key_push?(K_9) || Input.key_push?(K_NUMPAD9) then 9
    end
    gid_wait.push(n) if n
  when (Input.key_release?(K_LALT) || Input.key_release?(K_RALT)) && gid_wait && !gid_wait.empty?
    gid_ = gid_wait.inject(0){|acc, n| acc = acc * 10 + n}
    gid = gid_ < 0 ? 0 : max_gid < gid_ ? max_gid : gid_
    glyph = Glyph.new(font, gid, cmaps, gpos)
    gid_wait = nil
  end
  
  case
  when Input.key_push?(K_TAB)
    mode = !mode
  when Input.key_push?(K_HOME)
    gid = 0
    glyph = Glyph.new(font, gid, cmaps, gpos)
  when Input.key_push?(K_END)
    gid = max_gid
    glyph = Glyph.new(font, gid, cmaps, gpos)
  when Input.key_push?(K_END)
    gid = max_gid
    glyph = Glyph.new(font, gid, cmaps, gpos)
  when s && Input.key_down?(K_PRIOR)
    gid -= 16
    gid = 0 if gid < 0
    glyph = Glyph.new(font, gid, cmaps, gpos)
  when s && Input.key_down?(K_NEXT)
    gid += 16
    gid = max_gid if max_gid < gid
    glyph = Glyph.new(font, gid, cmaps, gpos)
  when s && Input.key_down?(K_LEFT)
    if gid != 0
      gid -= 1
      glyph = Glyph.new(font, gid, cmaps, gpos)
    end
  when s && Input.key_down?(K_RIGHT)
    if gid != max_gid
      gid += 1
      glyph = Glyph.new(font, gid, cmaps, gpos)
    end
  when c && Input.key_down?(K_UP)
    $margin_y -= 10
    $margin_x += 10 if Input.key_down?(K_LEFT)
    $margin_x -= 10 if Input.key_down?(K_RIGHT)
  when c && Input.key_down?(K_DOWN)
    $margin_y += 10
    $margin_x += 10 if Input.key_down?(K_LEFT)
    $margin_x -= 10 if Input.key_down?(K_RIGHT)
  when c && Input.key_down?(K_LEFT)
    $margin_x += 10
  when c && Input.key_down?(K_RIGHT)
    $margin_x -= 10
  when Input.key_push?(K_PRIOR)
    gid -= 16
    gid = 0 if gid < 0
    glyph = Glyph.new(font, gid, cmaps, gpos)
  when Input.key_push?(K_NEXT)
    gid += 16
    gid = max_gid if max_gid < gid
    glyph = Glyph.new(font, gid, cmaps, gpos)
  when Input.key_push?(K_LEFT)
    if gid != 0
      gid -= 1
      glyph = Glyph.new(font, gid, cmaps, gpos)
    end
  when Input.key_push?(K_RIGHT)
    if gid != max_gid
      gid += 1
      glyph = Glyph.new(font, gid, cmaps, gpos)
    end
  when Input.key_push?(K_A)
    aa = !aa
  when Input.key_push?(K_S)
    show_box = !show_box
  when Input.key_push?(K_D)
    show_point = !show_point
  when Input.key_push?(K_F)
    show_metrics = !show_metrics
  when Input.key_push?(K_O)
    $margin_x = Margin_X
    $margin_y = Margin_Y
    $scale = Scale
  when s && Input.key_push?(K_Z)
    w, h = Window.width, Window.height
    w *= Scale_a; h *= Scale_a
    Window.resize(w, h)
  when s && Input.key_push?(K_X)
    w, h = Window.width, Window.height
    w /= Scale_a; h /= Scale_a
    Window.resize(w, h)
  when Input.key_push?(K_Z)
    $scale *= Scale_a
  when Input.key_push?(K_X)
    $scale /= Scale_a
  when Input.key_push?(K_ESCAPE) || Input.key_push?(K_Q)
    break
  end
end
rescue Exception
  puts gid
  p $@
  raise
end

