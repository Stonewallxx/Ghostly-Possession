#==============================================================================
# Ghostly Possession: Pitch Black
#==============================================================================
# The Darkness setting's darkest (his picks 2026-10-24): the caves' darkness
# brought outdoors at night, with more room (the Wider Circle: 96 px round
# you, 176 after Flash or KIF's Lantern, as in caves), drawn smooth (Smooth
# Light: a soft fall-off, no rings), and every light cutting its own patch:
# the map's own lamps (its OutdoorLight / Light events) and anything that
# says it gives light (Season.light: wisps, the trail's ball, graves).
# Midnight Violet's tint is under it (Core/Season.rb).
#
# While it's up it's the game's darkness sprite ($PokemonTemp.darknessSprite),
# so Flash and the Lantern widen it with the game's own code, and Flash may
# be used where it is. A Flash lasts until you leave the map (the game resets
# it whenever the map scene changes on a map that isn't dark, so it's put
# back after a battle). It fades in from 9 pm and out at 4 am, with the night.
#
# It's a subtracting sprite: white where it's dark (taking everything down to
# black), with a soft black stamp at each light (taking nothing away there).
# Each frame is one fill and a stamp per light.
#==============================================================================

module GhostlyPossession
  module SeasonDark
    RADIUS = 96          # round you (the Wider Circle)
    RADIUS_MAX = 176     # after Flash or the Lantern
    LAMP = 110           # round a lamp
    STAMP = 128          # the stamp's own radius; every light is stretched from it
    INNER = 0.55         # fully lit within this share of a light's radius
    FALL = 2.0           # how gently it fades past that (a subtracting sprite takes dim
                         # pixels to black sooner than the mockups' overlay: these match it)
    Z = 99_998           # the game's darkness sprite's

    @dark = nil
    @flash_map = nil
    @lamps = nil

    module_function

    def dark
      return @dark
    end

    def up?
      return @dark && !@dark.disposed? ? true : false
    end

    def wanted?
      return false unless Season.pitch_black? && $game_map
      return Season.outdoor? && !Season.dark_map? && !Season.dark_effect?
    end

    # 0 by day, half at 9 pm and 4 am, full at night (minute by minute)
    def strength
      return Season.share_now
    end

    # On every map scene (a new map, after a battle or a menu that rebuilt it)
    def attach(scene)
      map_id = $game_map ? $game_map.map_id : nil
      @flash_map = nil if @flash_map && @flash_map != map_id
      @lamps = nil
      unless wanted? && scene && scene.respond_to?(:spriteset) && scene.spriteset
        take_down
        return
      end
      unless up?
        @dark = Dark.new
        scene.spriteset.addUserSprite(@dark)
      end
      $PokemonTemp.darknessSprite = @dark if $PokemonTemp
      if @flash_map && @flash_map == map_id && $PokemonGlobal
        $PokemonGlobal.flashUsed = true
        @dark.radius = RADIUS_MAX
      end
    end

    def take_down
      return unless @dark
      $PokemonTemp.darknessSprite = nil if $PokemonTemp && $PokemonTemp.darknessSprite.equal?(@dark)
      @dark.dispose unless @dark.disposed?
      @dark = nil
    end

    # (Flash or the Lantern was used on this map: kept for it)
    def note_flash
      @flash_map = $game_map.map_id if $PokemonGlobal && $PokemonGlobal.flashUsed && $game_map
    end

    def lamps
      @lamps ||= ($game_map ? $game_map.events.values.select { |ev| ev.name.to_s[/\A(outdoor)?light/i] } : [])
      return @lamps
    end

    # [[x, y, radius], ...] on the screen: you, the map's lamps, the rest
    def lights(radius)
      list = [[$game_player.screen_x, $game_player.screen_y - 16, radius]]
      lamps.each { |ev| list << [ev.screen_x, ev.screen_y - 16, LAMP] }
      return list + Season.lights
    end

    def white
      @white ||= Color.new(255, 255, 255)
      return @white
    end

    # A soft black disc: opaque within INNER of its radius, fading out to its edge
    def stamp
      return @stamp if @stamp && !@stamp.disposed?
      size = STAMP * 2
      @stamp = Bitmap.new(size, size)
      shades = {}
      size.times do |y|
        size.times do |x|
          d = Math.hypot(x + 0.5 - STAMP, y + 0.5 - STAMP) / STAMP
          next if d >= 1.0
          t = [[(d - INNER) / (1.0 - INNER), 0.0].max, 1.0].min
          a = (255 * (1.0 - t**FALL)).round
          next if a <= 0
          @stamp.set_pixel(x, y, shades[a] ||= Color.new(0, 0, 0, a))
        end
      end
      return @stamp
    end

    #--------------------------------------------------------------------------
    # The sprite (the spriteset updates it each frame and disposes it with itself)
    #--------------------------------------------------------------------------
    class Dark
      attr_reader :radius

      def initialize
        @sprite = Sprite.new
        @sprite.z = Z
        @sprite.blend_type = 2
        @sprite.bitmap = Bitmap.new(Graphics.width, Graphics.height)
        @radius = RADIUS
        @disposed = false
        update
      end

      def radiusMin
        return RADIUS
      end

      def radiusMax
        return RADIUS_MAX
      end

      # (Flash and the Lantern grow it a step a frame)
      def radius=(value)
        @radius = value
        refresh unless @disposed
      end

      def disposed?
        return @disposed
      end

      def dispose
        return if @disposed
        @sprite.bitmap.dispose if @sprite.bitmap && !@sprite.bitmap.disposed?
        @sprite.dispose
        @disposed = true
      end

      def update
        return if @disposed
        s = SeasonDark.strength
        @sprite.visible = s > 0
        return if s <= 0
        @sprite.opacity = (255 * s).round
        SeasonDark.note_flash
        refresh
      rescue StandardError => e
        GhostlyPossession.log("Pitch Black couldn't be drawn: #{e.class}: #{e.message}")
        dispose
      end

      def refresh
        b = @sprite.bitmap
        b.fill_rect(0, 0, b.width, b.height, SeasonDark.white)
        st = SeasonDark.stamp
        SeasonDark.lights(@radius).each do |x, y, r|
          r = r.to_i
          next if r <= 0 || x + r < 0 || y + r < 0 || x - r > b.width || y - r > b.height
          b.stretch_blt(Rect.new(x.to_i - r, y.to_i - r, r * 2, r * 2), st, st.rect)
        end
      end
    end

    #--------------------------------------------------------------------------
    # Flash may be used where Pitch Black is up (the game allows it only on
    # dark maps); everywhere else the game's own check
    #--------------------------------------------------------------------------
    def allow_flash
      return if @flash_wrapped || !defined?(::HiddenMoveHandlers::CanUseMove)
      old = ::HiddenMoveHandlers::CanUseMove[:FLASH]
      return unless old
      ::HiddenMoveHandlers::CanUseMove.add(:FLASH, proc { |move, pkmn, showmsg|
        if GhostlyPossession::SeasonDark.up? && !($PokemonGlobal && $PokemonGlobal.flashUsed)
          next pbCheckHiddenMoveBadge(::Settings::BADGE_FOR_FLASH, showmsg) ? true : false
        end
        next old.call(move, pkmn, showmsg)
      })
      @flash_wrapped = true
    end

    def boot
      return false unless defined?(::Events) && ::Events.respond_to?(:onMapSceneChange)
      unless @booted
        ::Events.onMapSceneChange += proc { |_sender, e|
          begin
            GhostlyPossession::SeasonDark.attach(e[0])
          rescue StandardError => ex
            GhostlyPossession.log("Pitch Black couldn't be put up: #{ex.class}: #{ex.message}")
          end
        }
        @booted = true
      end
      allow_flash
      return true
    end
  end
end
