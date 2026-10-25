#==============================================================================
# Ghostly Possession: the Spooky Season's extras
#==============================================================================
# With Spooky Season On (his picks 2026-10-24):
#
#   Fog              At night in the haunted places (Lavender Town, the
#                    Pokémon Tower, the Pokémon Mansion, Ecruteak's Burned
#                    and Bell Towers), the game's own fog (Graphics/Weather/
#                    fog_tile), thin and shaded grey-violet (the game doesn't
#                    tint fog at night), drifting slowly. Never over the
#                    map's own weather (Lavender's rain). Its own layer on
#                    the map, never the map's saved fog.
#   Haunted Music    Its own row. On routes at night, one of Lavender Town,
#                    the Pokémon Tower remix, the Strange House or the
#                    Mansion remix, a different one each night. Towns and
#                    places with their own themes keep them; only the map's
#                    own music is ever swapped (never a battle's, an event's
#                    or a rival's).
#   Witchy Hat       On 31 October the Poké Mart clerk hands you the Witchy
#                    Hat once, as PIF's clerk hands out the Santa hat at
#                    Christmas (give_date_specific_hats).
#   Night Ghosts     At night on routes and in caves, 1 in 10 encounters is a
#                    Ghost instead: the area's own, else a classic one by your
#                    badges (Ghosts.rb), the stage that suits the encounter's
#                    level. Not with the Poké Radar, in the Safari Zone or the
#                    Bug Contest.
#==============================================================================

module GhostlyPossession
  module SeasonExtras
    FOG_MAPS = [50,                                    # Lavender Town
                142, *400..403, *467..469, 556,        # the Pokémon Tower
                173, 174, 181, 187,                    # the Pokémon Mansion
                611, 696, 697, 704,                    # the Burned Tower
                585, *649..653].freeze                 # the Bell Tower
    FOG_PICTURE = "fog_tile"
    FOG_OPACITY = 107                                  # about 0.42, as the mockup
    FOG_TONE = [-105, -115, -77, 0].freeze             # white fog shaded to (150, 140, 178)
    FOG_DRIFT = 0.25                                   # pixels a frame, leftward
    FOG_FADE = 40                                      # frames to fade in or out
    FOG_Z = 3000                                       # the game's own fog's
    TRACKS = ["Lavender Town", "Lavender_Town_Pokemon_Tower_Remix", "strange-house",
              "Powerplant & Pokemon Mansion Remix"].freeze
    HAT = "witchyhat"
    GHOST_CHANCE = 10                                  # 1 in this many night encounters
    ROUTE_KINDS = [:land, :cave].freeze

    @fog = nil

    module_function

    def season?
      return Settings.season?
    end

    def night?
      return defined?(::PBDayNight) && ::PBDayNight.isNight? ? true : false
    rescue StandardError
      return false
    end

    def map_id
      return $game_map ? $game_map.map_id : 0
    end

    #--------------------------------------------------------------------------
    # Fog
    #--------------------------------------------------------------------------
    def fog_wanted?
      return false unless season? && night? && FOG_MAPS.include?(map_id)
      weather = $game_screen && $game_screen.respond_to?(:weather_type) ? $game_screen.weather_type : :None
      return weather.nil? || weather == :None
    end

    class Fog
      def initialize(viewport)
        @plane = Plane.new(viewport)
        @plane.bitmap = RPG::Cache.load_bitmap("Graphics/Weather/", FOG_PICTURE)
        @plane.z = FOG_Z
        @plane.tone = Tone.new(*FOG_TONE)
        @plane.opacity = 0
        @drift = 0.0
        @disposed = false
        update
      end

      def disposed?
        return @disposed
      end

      def dispose
        return if @disposed
        @plane.dispose
        @disposed = true
      end

      def update
        return if @disposed
        target = SeasonExtras.fog_wanted? ? FOG_OPACITY : 0
        step = (FOG_OPACITY / FOG_FADE.to_f).ceil
        o = @plane.opacity
        @plane.opacity = o < target ? [o + step, target].min : [o - step, target].max
        return if @plane.opacity <= 0
        @drift += FOG_DRIFT
        sub = defined?(::Game_Map::X_SUBPIXELS) ? ::Game_Map::X_SUBPIXELS : 4
        @plane.ox = ($game_map.display_x / sub + @drift).round
        @plane.oy = ($game_map.display_y / sub).round
      rescue StandardError => e
        GhostlyPossession.log("The fog couldn't be drawn: #{e.class}: #{e.message}")
        dispose
      end
    end

    # On every map scene: a fog layer on the haunted places (it shows only at night)
    def attach_fog(scene)
      @fog.dispose if @fog && !@fog.disposed?
      @fog = nil
      return unless season? && FOG_MAPS.include?(map_id)
      return unless scene && scene.respond_to?(:spriteset) && scene.spriteset && defined?(::Spriteset_Map)
      @fog = Fog.new(::Spriteset_Map.viewport)
      scene.spriteset.addUserSprite(@fog)
    end

    #--------------------------------------------------------------------------
    # Haunted Music
    #--------------------------------------------------------------------------
    def route?(id = map_id)
      return false unless Season.outdoor?(id)
      version = ($PokemonGlobal.encounter_version rescue 0) || 0
      enc = ::GameData::Encounter.get(id, version) rescue nil
      return false unless enc && enc.types
      return enc.types.keys.any? { |t| (::GameData::EncounterType.get(t).type rescue nil) == :land }
    end

    # This night's track (the night that began before 5 am counts as the evening before)
    def track
      return Debug.track if Debug.track && TRACKS.include?(Debug.track)
      now = pbGetTimeNow
      day = now.yday + now.year * 366
      day -= 1 if now.hour < 5
      return TRACKS[day % TRACKS.length]
    end

    def music_wanted?(id = map_id)
      return Settings.haunted_music? && night? && route?(id)
    end

    # What plays on this map now: the haunted track, or nil for the map's own
    def haunted_track(id = map_id)
      return nil unless music_wanted?(id)
      name = track
      return FileTest.audio_exist?("Audio/BGM/" + name) ? name : nil
    rescue StandardError
      return nil
    end

    # Only the map's own music (or a haunted track) is ever swapped
    def own_music_playing?
      playing = $game_system && $game_system.playing_bgm
      return true unless playing && playing.name.to_s != ""
      name = playing.name.to_s
      own = $game_map && $game_map.respond_to?(:bgm_name) ? $game_map.bgm_name.to_s : nil
      own ||= ($game_map.instance_variable_get(:@map).bgm.name.to_s rescue "")
      return TRACKS.include?(name) || name == own || name == own + "_n"
    end

    # A minute's check while on the map: night coming or going swaps it
    def check_music
      return unless $game_map && $game_system
      @music_tick = (@music_tick || 0) + 1
      return unless @music_tick % 60 == 0
      return unless own_music_playing?
      want = haunted_track
      playing = $game_system.playing_bgm ? $game_system.playing_bgm.name.to_s : ""
      if want
        pbBGMPlay(want) if playing != want
      elsif TRACKS.include?(playing)
        $game_map.autoplay
      end
    rescue StandardError => e
      GhostlyPossession.log("The haunted music couldn't be checked: #{e.class}: #{e.message}")
    end

    module MapMusic
      def autoplay
        name = GhostlyPossession::SeasonExtras.haunted_track(@map_id)
        return super unless name
        pbBGMPlay(name)
        pbBGSPlay(@map.bgs) if @map.autoplay_bgs
      rescue StandardError => e
        GhostlyPossession.log("The haunted music couldn't play: #{e.class}: #{e.message}")
        return super
      end
    end

    #--------------------------------------------------------------------------
    # The Witchy Hat
    #--------------------------------------------------------------------------
    def halloween?(now = Time.now)
      return true if Debug.halloween?
      return now.month == 10 && now.day == 31
    end

    def give_hat(event_id)
      return unless season? && halloween? && $Trainer && $Trainer.respond_to?(:unlocked_hats)
      return if $Trainer.unlocked_hats.include?(HAT)
      pbCallBub(2, event_id, true) rescue nil
      pbMessage(_INTL("Happy Halloween! We're giving out a special hat today. Enjoy!"))
      obtainHat(HAT)
    rescue StandardError => e
      GhostlyPossession.log("The Witchy Hat couldn't be given: #{e.class}: #{e.message}")
    end

    module MartHats
      def give_date_specific_hats(*args)
        ret = super
        GhostlyPossession::SeasonExtras.give_hat(@event_id)
        return ret
      end
    end

    #--------------------------------------------------------------------------
    # Night Ghosts
    #--------------------------------------------------------------------------
    # (the Debug Menu's A Ghost on the Next Encounter: any time, no chance, once)
    def ghost_encounter?(enc_type, chance_rolls)
      forced = Debug.night_ghost?
      return false unless season? && (night? || forced) && chance_rolls.to_i <= 1
      kind = (::GameData::EncounterType.get(enc_type).type rescue nil)
      return false unless ROUTE_KINDS.include?(kind)
      return false if $PokemonTemp && $PokemonTemp.respond_to?(:pokeradar) && $PokemonTemp.pokeradar
      return false if (pbInSafari? rescue false) || (pbInBugContest? rescue false)
      if forced
        Debug.night_ghost = false
        return true
      end
      return rand(GHOST_CHANCE) == 0
    end

    # [species, level]: the encounter's level, a Ghost that suits it
    def ghost_for(encounter)
      level = encounter[1]
      list = Ghosts.area_ghosts
      list = Ghosts.classic_ghosts.flat_map { |s| [s] * (Ghosts::WEIGHTS[s] || 1) } if list.empty?
      return encounter if list.empty?
      ghost = Ghosts.suited(list[rand(list.length)], level)
      return ghost ? [ghost, level] : encounter
    end

    module NightGhosts
      def choose_wild_pokemon(enc_type, chance_rolls = 1, *rest)
        ret = super
        return ret unless ret.is_a?(Array) && GhostlyPossession::SeasonExtras.ghost_encounter?(enc_type, chance_rolls)
        return GhostlyPossession::SeasonExtras.ghost_for(ret)
      rescue StandardError => e
        GhostlyPossession.log("A night Ghost couldn't be chosen: #{e.class}: #{e.message}")
        return ret
      end
    end

    def boot
      ::Game_Map.prepend(MapMusic) if defined?(::Game_Map) && !::Game_Map.ancestors.include?(MapMusic)
      ::Object.prepend(MartHats) unless ::Object.ancestors.include?(MartHats)
      if defined?(::PokemonEncounters) && !::PokemonEncounters.ancestors.include?(NightGhosts)
        ::PokemonEncounters.prepend(NightGhosts)
      end
      if defined?(::Events) && !@booted
        ::Events.onMapSceneChange += proc { |_sender, e|
          begin
            GhostlyPossession::SeasonExtras.attach_fog(e[0])
          rescue StandardError => ex
            GhostlyPossession.log("The fog couldn't be put up: #{ex.class}: #{ex.message}")
          end
        } if ::Events.respond_to?(:onMapSceneChange)
        ::Events.onMapUpdate += proc { |_sender, _e| GhostlyPossession::SeasonExtras.check_music } if ::Events.respond_to?(:onMapUpdate)
        @booted = true
      end
      return true
    end
  end
end
