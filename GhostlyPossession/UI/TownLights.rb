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
#                  cool and a little brighter (his pick: Cool Clinic Light),
#                  the panes as bright as the bulbs (his ask, 2026-10-25).
#   Over Tiles     Glass, bulbs and glow on a tile the game draws over the
#                  player (a lamp's head, a Center's top: a priority tile)
#                  come in strips, a tile row each (MapNNNpP, MapNNNgpP), at
#                  that row's tiles' own z, so the tile doesn't hide its own
#                  light and a character in front still stands in front.
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
#   Next Door      A map connected to yours that the game has loaded lights
#                  up too, as it comes into view (his ask 2026-10-25:
#                  Viridian's arch lit from Route 1): a layer for each loaded
#                  map with lights, on that map's own sprites and scroll; a
#                  map coming back into view gets its sprites made quietly
#                  (Scene_Map#updateSpritesets), so each frame checks.
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
    @layers = {}          # map id => Layer: the map you're on and the loaded maps next to it

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

    # The lights are on now (any map's)
    def on?
      return wanted? && hours_on?
    end

    # ...and the map you're on has some
    def active?
      return on? && !entry.nil?
    end

    # The map you're on's layer
    def layer
      l = $game_map && @layers[$game_map.map_id]
      return l && !l.disposed? ? l : nil
    end

    def layers
      return @layers.values.reject(&:disposed?)
    end

    # The game's maps loaded now: yours, and the ones connected to it in view
    def loaded_maps
      list = defined?($MapFactory) && $MapFactory && $MapFactory.respond_to?(:maps) ? $MapFactory.maps.compact : []
      list = [$game_map] if list.empty? && $game_map
      return list
    end

    def map_of(id)
      return loaded_maps.find { |m| m.map_id == id }
    end

    # A map with its town lights on now (KIF's own lamp glow hidden there)
    def lit_map?(id)
      l = @layers[id]
      return l && !l.disposed? && on? ? true : false
    end

    def screen_offset(map = $game_map)
      sub = defined?(::Game_Map::X_SUBPIXELS) ? ::Game_Map::X_SUBPIXELS : 4
      return [map.display_x / sub, map.display_y / sub]
    end

    # The z the game's tiles of a map row and priority have now (the
    # TilemapRenderer's refresh_tile_z: its grid starts at the screen's top
    # row; a map next to yours scrolls by whole tiles from it, so its own
    # rows give the same z)
    def tile_z(row, priority, map = $game_map)
      sub = defined?(::Game_Map::Y_SUBPIXELS) ? ::Game_Map::Y_SUBPIXELS : 4
      top = (map.display_y.to_f / sub).round / 32
      return (row - top) * 32 + priority * 32 + 32
    end

    # The light patches (UI/SeasonDark.rb asks each frame): [picture,
    # screen x, y, its scale, how much of it (the lights' fade)], or nil:
    # the map you're on's
    def dark_picture
      l = layer
      return nil unless l && l.lit? && on?
      return l.holes_picture
    end

    # ...every lit map's, yours and the ones next to it
    def dark_pictures
      return [] unless on?
      return layers.select(&:lit?).map(&:holes_picture).compact
    end

    # ...and the lighthouses' beams' lift, each [picture, its cell, screen x,
    # y, scale, how much of it]
    def dark_beams
      return [] unless on?
      return layers.select(&:lit?).flat_map(&:beam_lifts)
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
      return [] unless on?
      return layers.select(&:lit?).flat_map(&:fire_lights)
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
      attr_accessor :set              # the spriteset it's on
      attr_reader :map_id

      def initialize(e, viewport, map_id = ($game_map ? $game_map.map_id : 0))
        @entry = e
        @map_id = map_id
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
        @strips = []          # [its picture's entry, map row, sprite]
        @strip_pics = []
        (e["high"] || []).each { |hp| strips(viewport, hp, false) }
        (e["high_glow"] || []).each { |hp| strips(viewport, hp, true) }
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

      # A priority picture's strips, a tile row each (the picture shared):
      # lit glass as it is, glow added
      def strips(viewport, hp, glow)
        bmp = Bitmap.new(PICTURES + hp["pic"].to_s)
        @strip_pics << bmp
        scale = glow ? (hp["scale"] || 1).to_i : 1
        hp["rows"].each do |row|
          s = Sprite.new(viewport)
          s.bitmap = bmp
          s.src_rect = Rect.new(0, (row.to_i * 32 - hp["y"].to_i) / scale, bmp.width, 32 / scale)
          s.zoom_x = s.zoom_y = scale
          s.blend_type = 1 if glow
          s.opacity = 0
          @strips << [hp, row.to_i, s]
        end
      end

      def disposed?
        return @disposed
      end

      def lit?
        return !@disposed && @opacity > 0 && !map.nil?
      end

      # Its map (the one you're on, or one next to it), or nil once it's gone
      def map
        return TownLights.map_of(@map_id)
      end

      def holes_picture
        m = map
        return nil unless m && @holes && !@holes.disposed?
        dx, dy = TownLights.screen_offset(m)
        return [@holes, @entry["hx"].to_i - dx, @entry["hy"].to_i - dy, (@entry["hscale"] || 1).to_f, @opacity]
      end

      def beam_lifts
        m = map
        return [] unless m
        dx, dy = TownLights.screen_offset(m)
        return @beams.map do |b, _s, lift|
          [lift, TownLights.beam_cell(b), b["x"].to_i - dx, b["y"].to_i - dy, (b["scale"] || 1).to_f, @opacity]
        end
      end

      # Pitch Black's patches for the fires, flickering, faded with the lights
      def fire_lights
        m = map
        return [] unless m
        dx, dy = TownLights.screen_offset(m)
        k = TownLights.flicker
        return @fires.map { |x, y, _s| [x - dx, y - dy, (FIRE_HOLE * (0.97 + 0.03 * k) * @opacity / 255.0).round] }
      end

      def dispose
        return if @disposed
        @fires.each { |_x, _y, s| s.dispose unless s.disposed? }
        @fire_pic.dispose if @fire_pic && !@fire_pic.disposed?
        @strips.each { |_hp, _row, s| s.dispose unless s.disposed? }
        @strip_pics.each { |b| b.dispose unless b.disposed? }
        ([@lit, @glow] + @beams.map { |_b, s, _l| s }).compact.each do |s|
          s.bitmap.dispose if s.bitmap && !s.bitmap.disposed?
          s.dispose
        end
        @beams.each { |_b, _s, lift| lift.dispose unless lift.disposed? }
        @holes.dispose if @holes && !@holes.disposed?
        @disposed = true
      end

      def sprites
        return ([@lit, @glow] + @beams.map { |_b, s, _l| s } + @strips.map { |_hp, _r, s| s } + @fires.map { |_x, _y, s| s }).compact
      end

      def update
        return if @disposed
        m = map
        unless m
          sprites.each { |s| s.visible = false }
          return
        end
        target = TownLights.on? ? 255 : 0
        step = (255.0 / FADE).ceil
        @opacity = @opacity < target ? [@opacity + step, target].min : [@opacity - step, target].max
        dx, dy = TownLights.screen_offset(m)
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
        @strips.each do |hp, row, s|
          s.opacity = @opacity
          s.visible = @opacity > 0
          next unless s.visible
          s.x = hp["x"].to_i - dx
          s.y = row * 32 - dy
          # one over its tiles: at the same z the newer sprite is drawn on
          # top, and KIF's frame rate (C-SYS-01) makes the tiles anew when
          # its in-between drawing starts or stops (a character one row
          # nearer is 32 higher still)
          s.z = TownLights.tile_z(row, hp["p"].to_i, m) + 1
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

    # On every map scene (a new map, one coming into view next to yours, after
    # a battle): a layer for each loaded map with lights, on that map's own
    # spriteset (it goes with it), the ones whose map left taken down
    def attach(scene)
      unless wanted? && scene && scene.respond_to?(:spriteset) && scene.spriteset && defined?(::Spriteset_Map)
        clear
        return
      end
      maps = loaded_maps
      ids = maps.map(&:map_id)
      @layers.delete_if do |id, l|
        gone = l.disposed? || !ids.include?(id)
        l.dispose if gone && !l.disposed?
        gone
      end
      maps.each do |m|
        e = entry(m.map_id)
        next unless e
        set = spriteset_for(scene, m)
        l = @layers[m.map_id]
        next if l && !l.disposed? && l.set.equal?(set)
        l.dispose if l && !l.disposed?
        l = Layer.new(e, ::Spriteset_Map.viewport, m.map_id)
        l.set = set
        set.addUserSprite(l)
        @layers[m.map_id] = l
      end
    end

    # Each frame, after the scene's spritesets update: a map that came into
    # view again gets its spriteset made quietly (no map scene change), so
    # one with lights and no layer on that spriteset gets it put up
    def sync(scene)
      sets = scene.respond_to?(:spritesets) ? scene.spritesets : nil
      return unless sets.is_a?(Hash) && wanted?
      missing = sets.any? do |id, set|
        next false unless set && entry(id)
        l = @layers[id]
        !(l && !l.disposed? && l.set.equal?(set))
      end
      attach(scene) if missing
    rescue StandardError => e
      GhostlyPossession.log("The town lights next door couldn't be put up: #{e.class}: #{e.message}")
    end

    module SceneSync
      def updateSpritesets(*args)
        ret = super
        GhostlyPossession::TownLights.sync(self)
        return ret
      end
    end

    def spriteset_for(scene, map)
      sets = scene.respond_to?(:spritesets) ? scene.spritesets : nil
      set = sets.is_a?(Hash) ? sets[map.map_id] : nil
      return set || scene.spriteset
    end

    def clear
      @layers.each_value { |l| l.dispose unless l.disposed? }
      @layers = {}
    end

    # KIF's own lamp glow (its OutdoorLight events' LE picture) hidden while
    # its map's town lights are on
    module HideLampGlow
      def update
        ret = super
        id = @map ? @map.map_id : ($game_map ? $game_map.map_id : nil)
        @light.opacity = 0 if @light && GhostlyPossession::TownLights.lit_map?(id)
        return ret
      end
    end

    def boot
      # the fires' patches in Pitch Black (none where there's no fire)
      Season.light(:town_fires) { GhostlyPossession::TownLights.fire_lights } if defined?(Season) && Season.respond_to?(:light)
      if defined?(::LightEffect_DayNight) && !::LightEffect_DayNight.ancestors.include?(HideLampGlow)
        ::LightEffect_DayNight.prepend(HideLampGlow)
      end
      if defined?(::Scene_Map) && ::Scene_Map.method_defined?(:updateSpritesets) && !::Scene_Map.ancestors.include?(SceneSync)
        ::Scene_Map.prepend(SceneSync)
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
