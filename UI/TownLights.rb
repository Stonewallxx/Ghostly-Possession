#==============================================================================
# Ghostly Possession: Town Lights
#==============================================================================
# With Spooky Season On, Town Lights On and Darkness on Deepest Violet or
# darker (his picks 2026-10-24), from 9 pm to 4:30 am towns light up, glow
# only: no light-source shapes (no dot on the lamps, no doorway-sized blocks).
#
#   Lit Fixtures   The windows' and glass doors' own panes and the lamps' own
#                  bulbs glow, about two-thirds lit and looking the same on
#                  any Darkness (as on Deepest Violet): one picture per map
#                  of just those pixels (MapNNN).
#   The Glow       One picture per map added over the scene (MapNNNg, made
#                  at half size and shown at twice that): the panes' wall
#                  glow, the lamps' area light, and each window's and door's
#                  light on the ground: a soft oval at its foot that fans out
#                  as it fades, the way the glass faces, on open ground only
#                  (his picks 2026-10-25). Lights don't stack, and a lamp's
#                  light wins where it overlaps the others.
#   Cool Light     The Pokemon Centers' panes are a cool white, their light
#                  cool and a little brighter (his pick: Cool Clinic Light).
#   Pitch Black    Every lit pane, by its size (upper storeys, portholes
#                  too), door and lamp lifts its own patch of the dark, and
#                  each ground light its own (his picks 2026-10-25): one
#                  picture per map (MapNNNh, half size, its alpha the
#                  patches) that UI/SeasonDark.rb lays into the dark in one go.
#   Lighthouses    A bright beacon (his picks 2026-10-25), and a soft beam
#                  turning round each lantern, a turn every 8 seconds: one
#                  picture of its angles per lighthouse (MapNNNbK), a cell
#                  shown at a time by the clock, added over the map's tiles
#                  and characters (so it crosses in front of the tower);
#                  its lantern room and roof are left out of it, so it leaves
#                  the panes and passes behind the roof. In Pitch Black it
#                  lifts the dark where it falls (MapNNNbhK, the same cell).
#   Fire           Route 34's torch pillar (his pick 2026-10-25: Flickering
#                  Firelight): its flame in its own colours (the lit
#                  picture), and its warm light round it, about 4 tiles,
#                  flickering like fire (FireGlow, scaled and faded by the
#                  clock, over the tiles and characters like the beams); in
#                  Pitch Black its patch flickers with it (one of Season's
#                  lights).
#   Lamps          KIF's own lamp glow is hidden while it's on.
#
# Every picture and spot is made ahead of time by Tools/TownLights
# (Data/town_lights.json, Graphics/GhostlyPossession/TownLights); the game
# only shows them.
#==============================================================================

module GhostlyPossession
  module TownLights
    Z_LIT = 1             # just over the ground's tiles
    Z_GLOW = 2
    Z_BEAM = 1000         # over the map's tiles and characters, under wisps (1500) and fog (3000)
    FIRE_PIC = "FireGlow"
    FIRE_HOLE = 70        # a fire's patch in Pitch Black, at its brightest (the stamp's clear middle: 70 matches the picked design's fall-off)
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

    def screen_offset
      sub = defined?(::Game_Map::X_SUBPIXELS) ? ::Game_Map::X_SUBPIXELS : 4
      return [$game_map.display_x / sub, $game_map.display_y / sub]
    end

    # Pitch Black's patches (UI/SeasonDark.rb asks each frame): [picture,
    # screen x, y, its scale, how much of it (the lights' fade)], or nil
    def dark_picture
      return nil unless @layer && @layer.lit? && active?
      return @layer.holes_picture
    end

    # ...and the lighthouses' beams' lift, each [picture, its cell, screen x,
    # y, scale, how much of it]
    def dark_beams
      return [] unless @layer && @layer.lit? && active?
      return @layer.beam_lifts
    end

    def now
      return defined?(::System) && ::System.respond_to?(:uptime) ? ::System.uptime : ::Graphics.frame_count / 60.0
    end

    # How bright a fire is now, about 0.7 to 1 (three waves, like a flame)
    def flicker(t = now)
      return 0.86 + 0.08 * Math.sin(2 * Math::PI * t * 1.3) + 0.05 * Math.sin(2 * Math::PI * t * 3.1 + 1.0) +
             0.03 * Math.sin(2 * Math::PI * t * 7.3 + 2.0)
    end

    # Pitch Black's patches for the fires, flickering: [[x, y, radius], ...]
    def fire_lights
      return [] unless @layer && @layer.lit? && active?
      return @layer.fire_lights
    end

    # A beam's cell now: by the clock, a turn every b["turn"] seconds
    def beam_cell(b)
      now = self.now
      frames, turn = b["frames"].to_i, b["turn"].to_f
      k = ((now % turn) / turn * frames).floor % frames
      cols = b["cols"].to_i
      return Rect.new((k % cols) * b["cw"].to_i, (k / cols) * b["ch"].to_i, b["cw"].to_i, b["ch"].to_i)
    end

    #--------------------------------------------------------------------------
    # The layer on the map (the spriteset updates it and disposes it with itself)
    #--------------------------------------------------------------------------
    class Layer
      def initialize(e, viewport)
        @entry = e
        @lit = picture(viewport, e["overlay"], Z_LIT)
        @glow = picture(viewport, e["glow"], Z_GLOW)
        if @glow
          @glow.blend_type = 1
          @glow.zoom_x = @glow.zoom_y = (e["gscale"] || 1).to_f
        end
        @holes = e["holes"] ? Bitmap.new(PICTURES + e["holes"].to_s) : nil
        @beams = (e["beams"] || []).map do |b|
          s = picture(viewport, b["pic"], Z_BEAM)
          s.blend_type = 1
          s.zoom_x = s.zoom_y = (b["scale"] || 1).to_f
          [b, s, Bitmap.new(PICTURES + b["lift"].to_s)]
        end
        fires = e["fires"] || []
        @fire_pic = fires.empty? ? nil : Bitmap.new(PICTURES + FIRE_PIC)
        @fires = fires.map do |x, y|
          s = Sprite.new(viewport)
          s.bitmap = @fire_pic
          s.ox = @fire_pic.width / 2
          s.oy = @fire_pic.height / 2
          s.blend_type = 1
          s.z = Z_BEAM
          s.opacity = 0
          [x.to_i, y.to_i, s]
        end
        @opacity = 0
        @disposed = false
        update
      end

      def picture(viewport, name, z)
        return nil unless name
        s = Sprite.new(viewport)
        s.bitmap = Bitmap.new(PICTURES + name.to_s)
        s.z = z
        s.opacity = 0
        return s
      end

      def disposed?
        return @disposed
      end

      def lit?
        return !@disposed && @opacity > 0
      end

      def holes_picture
        return nil unless @holes && !@holes.disposed?
        dx, dy = TownLights.screen_offset
        return [@holes, @entry["hx"].to_i - dx, @entry["hy"].to_i - dy, (@entry["hscale"] || 1).to_f, @opacity]
      end

      def beam_lifts
        dx, dy = TownLights.screen_offset
        return @beams.map do |b, _s, lift|
          [lift, TownLights.beam_cell(b), b["x"].to_i - dx, b["y"].to_i - dy, (b["scale"] || 1).to_f, @opacity]
        end
      end

      # Pitch Black's patches for the fires, flickering, faded with the lights
      def fire_lights
        dx, dy = TownLights.screen_offset
        k = TownLights.flicker
        return @fires.map { |x, y, _s| [x - dx, y - dy, (FIRE_HOLE * (0.97 + 0.03 * k) * @opacity / 255.0).round] }
      end

      def dispose
        return if @disposed
        @fires.each { |_x, _y, s| s.dispose unless s.disposed? }
        @fire_pic.dispose if @fire_pic && !@fire_pic.disposed?
        ([@lit, @glow] + @beams.map { |_b, s, _l| s }).compact.each do |s|
          s.bitmap.dispose if s.bitmap && !s.bitmap.disposed?
          s.dispose
        end
        @beams.each { |_b, _s, lift| lift.dispose unless lift.disposed? }
        @holes.dispose if @holes && !@holes.disposed?
        @disposed = true
      end

      def update
        return if @disposed
        target = TownLights.active? ? 255 : 0
        step = (255.0 / FADE).ceil
        @opacity = @opacity < target ? [@opacity + step, target].min : [@opacity - step, target].max
        dx, dy = TownLights.screen_offset
        [[@lit, "ox", "oy"], [@glow, "gx", "gy"]].each do |s, kx, ky|
          next unless s
          s.opacity = @opacity
          s.visible = @opacity > 0
          s.x = @entry[kx].to_i - dx
          s.y = @entry[ky].to_i - dy
        end
        @beams.each do |b, s, _lift|
          s.opacity = @opacity
          s.visible = @opacity > 0
          next unless s.visible
          s.src_rect = TownLights.beam_cell(b)
          s.x = b["x"].to_i - dx
          s.y = b["y"].to_i - dy
        end
        unless @fires.empty?
          k = TownLights.flicker
          @fires.each do |x, y, s|
            s.opacity = (@opacity * k).round
            s.visible = @opacity > 0
            s.zoom_x = s.zoom_y = 0.97 + 0.03 * k
            s.x = x - dx
            s.y = y - dy
          end
        end
      rescue StandardError => e
        GhostlyPossession.log("The town lights couldn't be drawn: #{e.class}: #{e.message}")
        dispose
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
      # the fires' patches in Pitch Black (none where there's no fire)
      Season.light(:town_fires) { GhostlyPossession::TownLights.fire_lights } if defined?(Season) && Season.respond_to?(:light)
      if defined?(::LightEffect_DayNight) && !::LightEffect_DayNight.ancestors.include?(HideLampGlow)
        ::LightEffect_DayNight.prepend(HideLampGlow)
      end
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
