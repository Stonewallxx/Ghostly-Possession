#==============================================================================
# Ghostly Possession: how a will-o'-wisp looks
#==============================================================================
# The wisp (his picks 2026-10-24, sheets gp-wisp-look / gp-wisp-hop): the
# Soft Flame, light purple, pale at the heart, with the Glowing Orb's two
# tiny motes circling it (the far one passes under the flame), a soft halo
# and a faint pool of light on the ground; it bobs and its tip flickers.
# Never night-tinted (plain sprites; the game tints only map characters), its
# glow added light (blend_type 1). Fade and Reappear: it shrinks and fades
# slowly as its two motes leave it and fly on along the trail to where it'll
# show, bigger and brighter, a short tail behind each (his pick 2026-10-25:
# Lead the Way; often off screen: follow them), then fades in further on,
# small and faint first. At the trail's end it sinks into the ground.
#
# The treasure's ball (gp-wisp-ball, Glow and Motes): the game's own item
# ball, night-tinted like any map sprite, with a purple halo and pool of
# light and the wisp's two motes still circling it. Hung on the ball's
# Sprite_Character (as UI/MapAura.rb hangs the aura), so it follows the
# scroll, battles and fades.
#
# Sounds (to be chosen by ear in game): it appears with the soft chime of
# PRSFX- Confuse Ray; Saint9 as it hops; Saint8 as it sinks; Darkness6 when
# it's lost. With Kanto Reloaded a toast as it appears (Flame Icon, his pick):
# "A strange light flickers nearby..."
#
# Drawn with the map's viewport (it scrolls with the map: Wisps.trail_xy, on
# the map next door too)
# as one of its spriteset's user sprites, attached again whenever the map's
# sprites are made again (battles, transfers, a load).
#==============================================================================

module GhostlyPossession
  module WispLook
    CORE = [250, 242, 255, 255].freeze
    BODY = [206, 168, 255, 255].freeze
    EDGE = [146, 92, 240, 255].freeze
    TIP = [190, 150, 255, 170].freeze
    HALO = [168, 112, 255].freeze
    POOL = [150, 110, 255].freeze
    PAL = { "c" => CORE, "b" => BODY, "e" => EDGE, "t" => TIP }.freeze
    # the flame, 9 x 14, drawn at 2x; four frames (its tip sways)
    FLAMES = [
      ["....t....", "....t....", "...tet...", "...ebe...", "..ebbbe..", "..ebcbe..", ".ebbcbbe.", ".ebccbbe.", "ebbcccbbe", "ebcccccbe", "ebcccccbe", ".ebcccbe.", "..ebbbe..", "...eee..."],
      [".....t...", ".....t...", "....te...", "...ebe...", "..ebbbe..", "..ebcbe..", ".ebbcbbe.", ".ebccbbe.", "ebbcccbbe", "ebcccccbe", "ebcccccbe", ".ebcccbe.", "..ebbbe..", "...eee..."],
      ["...t.....", "...t.....", "...et....", "...ebe...", "..ebbbe..", "..ebcbe..", ".ebbcbbe.", ".ebbccbe.", "ebbcccbbe", "ebcccccbe", "ebcccccbe", ".ebcccbe.", "..ebbbe..", "...eee..."],
      [".........", "....t....", "....t....", "...tet...", "..ebebe..", "..ebbbe..", ".ebbcbbe.", ".ebccbbe.", "ebbcccbbe", "ebcccccbe", "ebcccccbe", ".ebcccbe.", "..ebbbe..", "...eee..."]
    ].freeze
    MOTE = ["ebe", "bcb", "ebe"].freeze
    ICON = ["...t...", "...e...", "..ebe..", "..bcb..", ".ebcbe.", ".bcccb.", "ebcccbe", "bcccccb", ".bcccb.", "..eee.."].freeze
    LIFT = 26                      # how high it floats over the ground (px)
    Z = 1500                       # over the map's characters and lights
    BOB = [0, -1, -2, -1].freeze
    TAIL = 6                       # a flying mote's tail (glows behind it)
    SOUNDS = { :appear => ["Anim/PRSFX- Confuse Ray", 70], :hop => ["Saint9", 50],
               :sink => ["Saint8", 60], :lost => ["Darkness6", 50] }.freeze

    module_function

    #--------------------------------------------------------------------------
    # Pictures, made once
    #--------------------------------------------------------------------------
    def art(rows, scale)
      w = rows.map(&:length).max
      b = Bitmap.new(w * scale, rows.length * scale)
      paint_art(b, rows, scale, 0, 0)
      return b
    end

    def paint_art(b, rows, scale, ox, oy)
      rows.each_with_index do |row, y|
        row.chars.each_with_index do |ch, x|
          c = PAL[ch]
          b.fill_rect(ox + x * scale, oy + y * scale, scale, scale, Color.new(*c)) if c
        end
      end
    end

    # The flame's four frames side by side (18 x 28 each)
    def flames
      return @flames if @flames && !@flames.disposed?
      @flames = Bitmap.new(18 * FLAMES.length, 28)
      FLAMES.each_with_index { |rows, i| paint_art(@flames, rows, 2, i * 18, 0) }
      return @flames
    end

    def mote
      @mote = art(MOTE, 1) if !@mote || @mote.disposed?
      return @mote
    end

    # A soft round light: alpha (1 - distance)^power * peak; squash < 1 flattens it
    def glow(r, rgb, peak, squash = 1.0, power = 2.0)
      key = [r, rgb, peak, squash, power]
      @glows ||= {}
      return @glows[key] if @glows[key] && !@glows[key].disposed?
      w = r * 2
      h = [(r * 2 * squash).round, 2].max
      b = Bitmap.new(w, h)
      h.times do |y|
        w.times do |x|
          dx = x + 0.5 - r
          dy = (y + 0.5 - h / 2.0) / squash
          d = Math.sqrt(dx * dx + dy * dy) / r
          next if d >= 1
          b.set_pixel(x, y, Color.new(rgb[0], rgb[1], rgb[2], ((1 - d)**power * peak * 255).round))
        end
      end
      @glows[key] = b
      return b
    end

    # Kanto Reloaded's toast icon: the small flame, 24 x 24
    def icon
      return @icon if @icon && !@icon.disposed?
      @icon = Bitmap.new(24, 24)
      paint_art(@icon, ICON, 2, (24 - 14) / 2, (24 - 20) / 2)
      return @icon
    end

    #--------------------------------------------------------------------------
    # Sounds and the toast
    #--------------------------------------------------------------------------
    def sound(key)
      name, volume = SOUNDS[key]
      pbSEPlay(name, volume) if name && defined?(pbSEPlay)
    rescue StandardError
      nil
    end

    def appear
      attach
      sound(:appear)
      if KR.has?(:Toast)
        ::Reloaded::Toast.show(_INTL("A strange light flickers nearby..."), :icon => icon)
      end
    rescue StandardError => e
      GhostlyPossession.log("A will-o'-wisp's toast couldn't be shown: #{e.class}: #{e.message}")
    end

    def hop;  sound(:hop);  end
    def sink; sound(:sink); end
    def lost; sound(:lost); end

    #--------------------------------------------------------------------------
    # The wisp on the map
    #--------------------------------------------------------------------------
    def attach
      return unless $scene.is_a?(::Scene_Map) && $scene.respond_to?(:spriteset?) && $scene.spriteset?
      set = $scene.spriteset
      return unless set && set.respond_to?(:addUserSprite)
      return if @view && !@view.disposed? && @set.equal?(set)
      @view.dispose if @view && !@view.disposed?
      @view = View.new(::Spriteset_Map.viewport)
      @set = set
      set.addUserSprite(@view)
    rescue StandardError => e
      GhostlyPossession.log("A will-o'-wisp couldn't be drawn: #{e.class}: #{e.message}")
    end

    class View
      def initialize(viewport)
        @disposed = false
        @pool = add_sprite(viewport, WispLook.glow(16, POOL, 0.45, 0.35, 1.5), Z - 2)
        @halo = add_sprite(viewport, WispLook.glow(26, HALO, 0.6, 1.0, 2.2), Z - 1)
        @flame = Sprite.new(viewport)
        @flame.bitmap = WispLook.flames
        @flame.ox = 9
        @flame.oy = 22
        @flame.z = Z
        @motes = 2.times.map do
          glow = add_sprite(viewport, WispLook.glow(6, HALO, 0.5), Z)
          dot = Sprite.new(viewport)
          dot.bitmap = WispLook.mote
          dot.ox = dot.oy = 1
          [glow, dot]
        end
        # Lead the Way: each mote flying on, its head, its dot and its tail
        @travel = 2.times.map do
          head = add_sprite(viewport, WispLook.glow(13, HALO, 1.0), Z + 1)
          dot = Sprite.new(viewport)
          dot.bitmap = WispLook.mote
          dot.ox = dot.oy = 1
          dot.z = Z + 2
          [head, dot, TAIL.times.map { add_sprite(viewport, WispLook.glow(6, HALO, 0.5), Z + 1) }]
        end
        hide
      end

      def add_sprite(viewport, bitmap, z)
        s = Sprite.new(viewport)
        s.bitmap = bitmap
        s.ox = bitmap.width / 2
        s.oy = bitmap.height / 2
        s.blend_type = 1
        s.z = z
        return s
      end

      def sprites
        return [@pool, @halo, @flame] + @motes.flatten + @travel.flatten
      end

      def hide
        sprites.each { |s| s.visible = false }
      end

      def update
        return if @disposed
        v = Wisps.view
        unless v && $game_map
          hide
          return
        end
        x, y, phase, t, len, ahead = v
        p = [t.to_f / [len, 1].max, 1.0].min
        o, k, lift, spread = 1.0, 1.0, LIFT, 1.0
        case phase
        when :in   then o, k = p, 0.6 + 0.4 * p
        when :out  then o, k, spread = 1 - p, 1 - 0.25 * p, 1 + p
        when :lost then o, spread = 1 - p, 1 + 0.5 * p
        when :sink then o, k, lift = 1 - p, 1 - 0.2 * p, LIFT * (1 - p)
        end
        frame = Graphics.frame_count
        f = (frame / 8) % FLAMES.length
        sx, gy = Wisps.trail_xy(x, y)
        gy -= 4
        cy = gy - lift + BOB[(frame / 12) % BOB.length]
        alpha = (255 * o).round
        place(@pool, sx, gy + 2, alpha, 1.0)
        place(@halo, sx, cy - 4, alpha, k * (f.even? ? 1.0 : 1.08))
        @flame.src_rect.set(f * 18, 0, 18, 28)
        place(@flame, sx, cy, alpha, k)
        if phase == :out && ahead && ahead.length > 1
          @motes.flatten.each { |s| s.visible = false }
          fly(ahead, p, frame)
          return
        end
        @travel.flatten.each { |s| s.visible = false }
        @motes.each_with_index do |(glow, dot), n|
          ang = frame * 0.05 + Math::PI / 4 + n * Math::PI
          mx = sx + (Math.cos(ang) * 15 * k * spread).round
          my = cy - 8 + (Math.sin(ang) * 6 * k * spread).round
          z = Math.sin(ang) < 0 ? Z - 1 : Z + 1      # the far one under the flame
          place(glow, mx, my, alpha, 1.0)
          place(dot, mx, my, alpha, 1.0)
          glow.z = dot.z = z
        end
      end

      # Lead the Way: the motes fly on along the trail's tiles to where it'll
      # show (eased: slow away, slow in), faint at first, each circling the
      # other and rising in an arc, a short tail behind
      def fly(ahead, p, frame)
        pts = ahead.map { |tx, ty| gx, gy = Wisps.trail_xy(tx, ty); [gx, gy - 4 - LIFT - 8] }
        q = p * p * (3 - 2 * p)
        fade = 0.35 + 0.65 * [p * 3, 1.0].min
        @travel.each_with_index do |(head, dot, tail), n|
          (0..TAIL).each do |back|
            qq = [q - back * 0.025, 0.0].max
            ax, ay = along(pts, qq)
            ang = frame * 0.12 + n * Math::PI - back * 0.12
            mx = ax + Math.cos(ang) * 10
            my = ay + Math.sin(ang) * 6 - Math.sin(qq * Math::PI) * 14
            if back == 0
              place(head, mx, my, (255 * fade).round, 1.0)
              place(dot, mx, my, (255 * fade).round, 2.0)
            else
              place(tail[back - 1], mx, my, (255 * fade * 0.5 * (1 - back / (TAIL + 1.0))).round, 1.0)
            end
          end
        end
      end

      # The point q (0 to 1) of the way along a line of points
      def along(pts, q)
        lens = pts.each_cons(2).map { |a, b| Math.hypot(b[0] - a[0], b[1] - a[1]) }
        d = q * lens.sum
        lens.each_with_index do |len, i|
          if d <= len || i == lens.length - 1
            f = len > 0 ? [d / len, 1.0].min : 0.0
            a, b = pts[i], pts[i + 1]
            return [a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f]
          end
          d -= len
        end
        return pts[-1]
      end

      def place(s, x, y, alpha, zoom)
        s.x = x.round
        s.y = y.round
        s.zoom_x = s.zoom_y = zoom
        s.opacity = alpha
        s.visible = alpha > 0
      end

      def dispose
        return if @disposed
        sprites.each { |s| s.dispose unless s.disposed? }   # (the bitmaps are shared: kept)
        @disposed = true
      end

      def disposed?
        return @disposed
      end
    end

    #--------------------------------------------------------------------------
    # The treasure's ball: Glow and Motes round the game's own ball
    #--------------------------------------------------------------------------
    IVAR = :@gp_wisp_ball

    def ball_follow(s, ch)
      looks = s.instance_variable_get(IVAR)
      unless ch && Wisps.ours?(ch, Wisps::BALL) && !ch.instance_variable_get(:@erased)
        ball_off(s) if looks
        return
      end
      looks = ball_make(s) if !looks || looks.any?(&:disposed?)
      pool, halo, *motes = looks
      shown = !s.disposed? && s.visible && s.opacity > 0
      cy = s.y - 11
      frame = Graphics.frame_count
      [pool, halo].each { |g| g.visible = shown; g.opacity = s.opacity }
      pool.x, pool.y, pool.z = s.x, s.y - 2, s.z - 1
      halo.x, halo.y, halo.z = s.x, cy, s.z - 1
      halo.zoom_x = halo.zoom_y = (frame / 8).even? ? 1.0 : 1.06
      motes.each_slice(2).each_with_index do |(glow, dot), n|
        ang = frame * 0.05 + Math::PI / 4 + n * Math::PI
        mx = s.x + (Math.cos(ang) * 14).round
        my = cy - 4 + (Math.sin(ang) * 5).round
        [glow, dot].each do |m|
          m.x, m.y = mx, my
          m.z = Math.sin(ang) < 0 ? s.z - 1 : s.z + 1
          m.visible = shown
          m.opacity = s.opacity
        end
      end
    rescue StandardError => e
      ball_off(s)
      GhostlyPossession.log("A will-o'-wisp's treasure couldn't glow: #{e.class}: #{e.message}")
    end

    def ball_make(s)
      ball_off(s)
      looks = [[glow(24, POOL, 0.7, 0.35, 1.3), true], [glow(28, HALO, 0.8, 1.0, 1.8), true]]
      2.times { looks << [glow(6, HALO, 0.5), true] << [mote, false] }
      sprites = looks.map do |bitmap, additive|
        sp = Sprite.new(s.viewport)
        sp.bitmap = bitmap
        sp.ox = bitmap.width / 2
        sp.oy = bitmap.height / 2
        sp.blend_type = 1 if additive
        sp.visible = false
        sp
      end
      s.instance_variable_set(IVAR, sprites)
      return sprites
    end

    def ball_off(s)
      looks = s.instance_variable_get(IVAR)
      return unless looks
      looks.each { |sp| sp.dispose unless sp.disposed? }      # (shared bitmaps kept)
      s.instance_variable_set(IVAR, nil)
    end

    module BallSprite
      def update(*args)
        ret = super
        GhostlyPossession::WispLook.ball_follow(self, @character)
        return ret
      end

      def dispose(*args)
        GhostlyPossession::WispLook.ball_off(self)
        return super
      end
    end

    def boot
      ::Sprite_Character.prepend(BallSprite) if defined?(::Sprite_Character) && !::Sprite_Character.ancestors.include?(BallSprite)
      return true
    end
  end
end
