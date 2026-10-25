#==============================================================================
# Ghostly Possession: the Spooky Season's night
#==============================================================================
# With Spooky Season On and a Darkness (his picks 2026-10-24), nights on
# outdoor maps turn violet and darker than KIF's own:
#
#   Deepest Violet   Tone(-114, -166, -70, 120)  (a new save's)
#   Midnight Violet  Tone(-150, -202, -106, 120) (his ask 2026-10-25: halfway
#                    from Deepest Violet to Pitch Black's dark, which takes
#                    another 71 off: 28% of white)
#   Pitch Black      Deepest Violet under a smooth dark round you, every
#                    light cutting its own patch (UI/SeasonDark.rb)
#
# The night comes in as KIF's own evening until 8 pm, halfway at 9 pm, the
# season's from 10 pm to 3 am, halfway at 4 am, KIF's morning from 5 (the
# game blends minute by minute between hours; PBDayNight.getToneInternal).
# EBDX's battle backdrops take the same night (BattleSceneRoom#daylightTint).
# The Darkrai darkness still wins: while it's on, nothing here changes.
#
# Lights in the dark: anything that gives light says where, for Pitch Black
# (one light, or a list of them).
#   GhostlyPossession::Season.light(:wisp) { [screen_x, screen_y, radius] }
#   GhostlyPossession::Season.unlight(:wisp)
#==============================================================================

module GhostlyPossession
  module Season
    # [red, green, blue, gray] by Darkness (Pitch Black's night is Deepest
    # Violet, its own dark over it)
    TONES = { 1 => [-114, -166, -70, 120], 2 => [-150, -202, -106, 120], 3 => [-114, -166, -70, 120] }.freeze
    # Battles have no dark of their own: Pitch Black's are Midnight Violet
    BATTLE = { 1 => 1, 2 => 2, 3 => 2 }.freeze
    EBDX_NIGHT = [-120, -100, -60, 0].freeze      # EBDX's own night backdrop
    @lights = {}

    module_function

    def darkness
      return Settings.darkness
    end

    def on?
      return darkness > 0
    end

    def pitch_black?
      return darkness == 3
    end

    # How far into the season's night an hour is: none, half or full
    def share(hour)
      hour = hour.to_i % 24
      return 1.0 if hour >= 22 || hour <= 3
      return 0.5 if hour == 21 || hour == 4
      return 0.0
    end

    # The same, minute by minute (the game's own blending)
    def share_now
      minutes = ::PBDayNight.pbGetDayNightMinutes
      hour, minute = minutes / 60, minutes % 60
      a, b = share(hour), share(hour + 1)
      return a + (b - a) * minute / 60.0
    rescue StandardError
      return 0.0
    end

    def mix(a, b, k)
      return a.each_index.map { |i| a[i] + (b[i] - a[i]) * k }
    end

    def tone_array(tone)
      return [tone.red, tone.green, tone.blue, tone.gray]
    end

    # An hour's tone as [r, g, b, gray]: KIF's own when the season's night isn't on
    def tone_at(hour, kif)
      s = share(hour)
      return kif if !on? || s <= 0
      return mix(kif, TONES[darkness], s)
    end

    # The Darkrai darkness (or a map it darkens) wins
    def dark_effect?
      return true if $game_switches && defined?(::SWITCH_KANTO_DARKNESS) && $game_switches[::SWITCH_KANTO_DARKNESS]
      return defined?(darknessEffectOnCurrentMap) && darknessEffectOnCurrentMap() ? true : false
    rescue StandardError
      return false
    end

    def outdoor?(map_id = ($game_map ? $game_map.map_id : 0))
      meta = ::GameData::MapMetadata.try_get(map_id) rescue nil
      return meta && meta.outdoor_map ? true : false
    end

    def dark_map?(map_id = ($game_map ? $game_map.map_id : 0))
      meta = ::GameData::MapMetadata.try_get(map_id) rescue nil
      return meta && meta.dark_map ? true : false
    end

    #--------------------------------------------------------------------------
    # The map's tone: the game's own, recomputed with the season's night
    #--------------------------------------------------------------------------
    def retone(cached)
      return unless cached && on? && !dark_effect?
      minutes = ::PBDayNight.pbGetDayNightMinutes
      hour, minute = minutes / 60, minutes % 60
      hourly = ::PBDayNight::HourlyTones
      a = tone_at(hour, tone_array(hourly[hour]))
      b = tone_at((hour + 1) % 24, tone_array(hourly[(hour + 1) % 24]))
      k = minute / 60.0
      cached.red = a[0] + (b[0] - a[0]) * k
      cached.green = a[1] + (b[1] - a[1]) * k
      cached.blue = a[2] + (b[2] - a[2]) * k
      cached.gray = a[3] + (b[3] - a[3]) * k
    end

    # After a setting changes: the tone again on the next frame, and Pitch
    # Black put up or taken down
    def refresh
      ::PBDayNight.sheduleToneRefresh if defined?(::PBDayNight) && ::PBDayNight.respond_to?(:sheduleToneRefresh)
      SeasonDark.attach($scene) if defined?(SeasonDark) && defined?(::Scene_Map) && $scene.is_a?(::Scene_Map)
    rescue StandardError => e
      GhostlyPossession.log("The season's night couldn't be refreshed: #{e.class}: #{e.message}")
    end

    module ToneHook
      def getToneInternal
        ret = super
        GhostlyPossession::Season.retone(@cachedTone)
        return ret
      rescue StandardError => e
        GhostlyPossession.log("The season's night tone couldn't be worked out: #{e.class}: #{e.message}")
        return ret
      end
    end

    #--------------------------------------------------------------------------
    # EBDX's backdrops: the same night (a mix of EBDX's own night and the
    # season's, by the hour); Pitch Black battles are Midnight Violet
    #--------------------------------------------------------------------------
    def ebdx(room)
      return unless on? && !dark_effect?
      s = share_now
      return if s <= 0
      data = room.instance_variable_get(:@data)
      sprites = room.instance_variable_get(:@sprites)
      return unless data && sprites
      return if !data["outdoor"] && !data["sky"]
      return if room.instance_variable_get(:@sunny)
      tone = Tone.new(*mix(EBDX_NIGHT, TONES[BATTLE[darkness]], s))
      room.instance_variable_set(:@daylightTone, tone)
      sprites.each_key do |key|
        next unless sprites[key]
        k = key.to_s
        next if k.include?("trainer") || k.include?("battler") || k.include?("pokemon")
        next if k.include?("sky") || k.include?("sun") || k.include?("star") || k.include?("cloud") || k.include?("Light")
        next if data[key].is_a?(Hash) && data[key].has_key?(:shading) && !data[key][:shading]
        sprites[key].tone = tone.clone
      end
    end

    module EBDXTint
      def daylightTint
        ret = super
        GhostlyPossession::Season.ebdx(self)
        return ret
      rescue StandardError => e
        GhostlyPossession.log("EBDX's backdrop couldn't take the season's night: #{e.class}: #{e.message}")
        return ret
      end
    end

    #--------------------------------------------------------------------------
    # Lights in the dark
    #--------------------------------------------------------------------------
    def light(id, &block)
      @lights[id] = block
    end

    def unlight(id)
      @lights.delete(id)
    end

    # [[screen_x, screen_y, radius], ...] of the lights out now (a block may
    # give one light, or a list of them: the town's lights)
    def lights
      out = []
      @lights.each_value do |b|
        l = (b.call rescue nil)
        next unless l.is_a?(Array)
        if l.first.is_a?(Array)
          l.each { |one| out << one if one.is_a?(Array) && one.length >= 3 }
        elsif l.length >= 3
          out << l
        end
      end
      return out
    end

    def boot
      ::PBDayNight.singleton_class.prepend(ToneHook) if defined?(::PBDayNight) &&
                                                       !::PBDayNight.singleton_class.ancestors.include?(ToneHook)
      ::BattleSceneRoom.prepend(EBDXTint) if defined?(::BattleSceneRoom) && ::BattleSceneRoom.method_defined?(:daylightTint) &&
                                              !::BattleSceneRoom.ancestors.include?(EBDXTint)
      return true
    end
  end
end
