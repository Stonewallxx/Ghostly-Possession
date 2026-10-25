#==============================================================================
# Ghostly Possession: Town Lights
#==============================================================================
# With Spooky Season On, Town Lights On and Darkness on Deepest Violet or
# darker (his picks 2026-10-24), from 9 pm to 4:30 am towns light up, glow
# only: no light-source shapes (no dot on the lamps, no doorway-sized blocks).
#
#   Lit Fixtures   The windows' and glass doors' own panes and the lamps' own
#                  bulbs glow, about two-thirds lit and looking the same on
#                  any Darkness (as on Midnight Violet): one picture per map
#                  of just those pixels, made ahead of time by
#                  Tools/TownLights (Graphics/GhostlyPossession/TownLights).
#   Warm Pools     Light falls on the ground below each window and in front
#                  of each door, never over the building, and the panes light
#                  their wall a little.
#   Lamps          An area light, about four tiles round each (the map's light
#                  events, and lamps drawn in its tiles). KIF's own lamp glow
#                  is hidden while it's on.
#   Pitch Black    Every lamp, door and window cuts its own patch of the dark.
#
# Where every light is comes from Data/town_lights.json (Tools/TownLights).
#==============================================================================

module GhostlyPossession
  module TownLights
    WARM = [255, 196, 104].freeze
    LAMP_R = 128          # a lamp's area light (about four tiles)
    POOL_W = 28           # a window's pool, half its width
    POOL_H = 14           # ...and its depth
    DOOR_W = 34
    DOOR_H = 18
    WALL_R = 14           # the panes' own glow on the wall, beyond the glass
    HOLES = { :lamp => 110, :door => 56, :window => 46 }.freeze   # in Pitch Black
    Z_LIT = 1             # just over the ground's tiles
    Z_GLOW = 2
    FADE = 20             # frames to fade in or out
    PICTURES = "Graphics/GhostlyPossession/TownLights/"

    @data = nil
    @layer = nil

    module_function

    def data
      return @data if @data
      text = File.read(File.join(GhostlyPossession::ROOT, "Data", "town_lights.json"), :encoding => "UTF-8")
      parsed = if defined?(::KIF::Mods::MiniJSON) then ::KIF::Mods::MiniJSON.parse(text)
               elsif defined?(::JSON) then ::JSON.parse(text)
               end
      @data = parsed.is_a?(Hash) ? (parsed["maps"] || {}) : {}
      return @data
    rescue StandardError => e
      GhostlyPossession.log("The town lights couldn't be read: #{e.class}: #{e.message}")
      return @data = {}
    end

    def entry(map_id = ($game_map ? $game_map.map_id : 0))
      return data[map_id.to_s]
    end

    # From 9 pm to 4:30 am (minute by the game's clock)
    def hours_on?
      minutes = ::PBDayNight.pbGetDayNightMinutes
      return minutes >= 21 * 60 || minutes < 4 * 60 + 30
    rescue StandardError
      return false
    end

    def wanted?
      return false unless Settings.town_lights? && Settings.darkness >= 1
      return Season.outdoor? && !Season.dark_effect?
    end

    def active?
      return wanted? && hours_on? && !entry.nil?
    end

    def layer
      return @layer
    end

    #--------------------------------------------------------------------------
    # The soft stamps (made once): a warm glow, alpha falling off from the middle
    #--------------------------------------------------------------------------
    def stamp(key)
      @stamps ||= {}
      s = @stamps[key]
      return s if s && !s.disposed?
      w, h, peak, power, half = { :area => [256, 256, 0.46, 1.4, false], :pool => [64, 32, 0.5, 1.5, true],
                                  :wall => [64, 64, 0.22, 1.6, false], :door => [64, 36, 0.55, 1.4, true] }[key]
      bmp = Bitmap.new(w, h)
      cx = w / 2.0
      cy = half ? 0.0 : h / 2.0
      ry = half ? h.to_f : h / 2.0
      shades = {}
      h.times do |y|
        w.times do |x|
          d = Math.sqrt(((x + 0.5 - cx) / (w / 2.0))**2 + ((y + 0.5 - cy) / ry)**2)
          next if d >= 1.0
          a = (255 * peak * (1.0 - d)**power).round
          next if a <= 0
          bmp.set_pixel(x, y, shades[a] ||= Color.new(WARM[0], WARM[1], WARM[2], a))
        end
      end
      return @stamps[key] = bmp
    end

    #--------------------------------------------------------------------------
    # The map's lights on the screen: [[kind, screen x, screen y, extra], ...]
    #--------------------------------------------------------------------------
    def screen_offset
      sub = defined?(::Game_Map::X_SUBPIXELS) ? ::Game_Map::X_SUBPIXELS : 4
      return [$game_map.display_x / sub, $game_map.display_y / sub]
    end

    def lights_in_view(e = entry, margin = LAMP_R)
      return [] unless e
      dx, dy = screen_offset
      w, h = Graphics.width, Graphics.height
      out = []
      seen = lambda { |x, y| x > -margin && y > -margin && x < w + margin && y < h + margin }
      Array(e["lamps"]).each { |x, y| out << [:lamp, x - dx, y - dy] if seen.call(x - dx, y - dy) }
      Array(e["doors"]).each { |x, foot| out << [:door, x - dx, foot - dy] if seen.call(x - dx, foot - dy) }
      Array(e["windows"]).each do |x, top, bottom, base|
        next unless seen.call(x - dx, bottom - dy)
        out << [:window, x - dx, (top + bottom) / 2.0 - dy, bottom - top, base - dy]
      end
      return out
    end

    # Pitch Black's patches (Season.light)
    def holes
      return [] unless active? && @layer && @layer.lit?
      return lights_in_view.map do |kind, x, y, *rest|
        case kind
        when :lamp then [x, y + 22, HOLES[:lamp]]
        when :door then [x, y - 6, HOLES[:door]]
        else [x, y, HOLES[:window]]
        end
      end
    end

    #--------------------------------------------------------------------------
    # The layer on the map (the spriteset updates it and disposes it with itself)
    #--------------------------------------------------------------------------
    class Layer
      def initialize(e, viewport)
        @entry = e
        @lit = nil
        if e["overlay"]
          @lit = Sprite.new(viewport)
          @lit.bitmap = Bitmap.new(PICTURES + e["overlay"].to_s)
          @lit.z = Z_LIT
          @lit.opacity = 0
        end
        @glow = Sprite.new(viewport)
        @glow.bitmap = Bitmap.new(Graphics.width, Graphics.height)
        @glow.blend_type = 1
        @glow.z = Z_GLOW
        @glow.opacity = 0
        @disposed = false
        update
      end

      def disposed?
        return @disposed
      end

      def lit?
        return !@disposed && @glow.opacity > 0
      end

      def dispose
        return if @disposed
        [@lit, @glow].compact.each do |s|
          s.bitmap.dispose if s.bitmap && !s.bitmap.disposed?
          s.dispose
        end
        @disposed = true
      end

      def update
        return if @disposed
        target = TownLights.active? ? 255 : 0
        step = (255.0 / FADE).ceil
        o = @glow.opacity
        o = o < target ? [o + step, target].min : [o - step, target].max
        @glow.opacity = o
        @lit.opacity = o if @lit
        @glow.visible = o > 0
        @lit.visible = o > 0 if @lit
        return if o <= 0
        dx, dy = TownLights.screen_offset
        if @lit
          @lit.x = @entry["ox"].to_i - dx
          @lit.y = @entry["oy"].to_i - dy
        end
        redraw
      rescue StandardError => e
        GhostlyPossession.log("The town lights couldn't be drawn: #{e.class}: #{e.message}")
        dispose
      end

      # Each frame: the warm glows of what's in view
      def redraw
        b = @glow.bitmap
        b.clear
        TownLights.lights_in_view(@entry).each do |kind, x, y, *rest|
          case kind
          when :lamp
            put(b, :area, x, y + 22, LAMP_R, LAMP_R)
          when :door
            put(b, :door, x, y, DOOR_W, DOOR_H, true)
          when :window
            tall, base = rest
            put(b, :wall, x, y, tall / 2.0 + WALL_R, tall / 2.0 + WALL_R)
            put(b, :pool, x, base, POOL_W, POOL_H, true)
          end
        end
      end

      # A stamp centred on x, y (a half stamp: its top edge at y, so a pool
      # starts at the building's foot and never goes up over it)
      def put(b, key, x, y, rx, ry, half = false)
        st = TownLights.stamp(key)
        rect = half ? Rect.new((x - rx).round, y.round, (rx * 2).round, ry.round) :
                      Rect.new((x - rx).round, (y - ry).round, (rx * 2).round, (ry * 2).round)
        b.stretch_blt(rect, st, st.rect)
      end
    end

    def attach(scene)
      @layer.dispose if @layer && !@layer.disposed?
      @layer = nil
      e = entry
      return unless e && wanted? && scene && scene.respond_to?(:spriteset) && scene.spriteset && defined?(::Spriteset_Map)
      @layer = Layer.new(e, ::Spriteset_Map.viewport)
      scene.spriteset.addUserSprite(@layer)
    end

    # KIF's own lamp glow (its OutdoorLight events' LE picture) hidden while
    # the town's lights are on
    module HideLampGlow
      def update
        ret = super
        @light.opacity = 0 if @light && GhostlyPossession::TownLights.layer && GhostlyPossession::TownLights.active?
        return ret
      end
    end

    def boot
      if defined?(::LightEffect_DayNight) && !::LightEffect_DayNight.ancestors.include?(HideLampGlow)
        ::LightEffect_DayNight.prepend(HideLampGlow)
      end
      Season.light(:town_lights) { GhostlyPossession::TownLights.holes } if defined?(Season) && Season.respond_to?(:light)
      if defined?(::Events) && ::Events.respond_to?(:onMapSceneChange) && !@booted
        ::Events.onMapSceneChange += proc { |_sender, e|
          begin
            GhostlyPossession::TownLights.attach(e[0])
          rescue StandardError => ex
            GhostlyPossession.log("The town lights couldn't be put up: #{ex.class}: #{ex.message}")
          end
        }
        @booted = true
      end
      return true
    end
  end
end
