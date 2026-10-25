#==============================================================================
# Ghostly Possession: a Ghost wanders in
#==============================================================================
# Now and then, as the player walks, a Ghost possesses one of the team
# (Wanders In, his pick 2026-10-24). Per step (Team Possession On):
#
#   - none for 500 steps after the last possession ended (and from the
#     start), and none while someone is possessed (one at a time: in the
#     PC or the Day Care it's still possessed)
#   - a chance of 1 in 4000 / 2000 (How Often: Normal / Often), twice
#     that at night, four times that in haunted places
#     (Lavender Town, the Pokémon Tower, Ecruteak and its towers, the Hidden
#     Tomb, the Pokémon Mansion, and dark places: Dark Cave, the Moonlit
#     Forest, the Ruins of Alph, the Sinjoh Ruins)
#   - only on a quiet step: on the map, nothing running, no message, menu,
#     transfer, fade, sliding, Safari Zone or Bug Contest, not an autosave
#     step; the step then starts no wild battle
#
#   GhostlyPossession::Team.possess(host, note)   possesses (the leap uses it too)
#
# The Debug menu's Possess on the Next Step skips the chance and the wait
# (Core/Debug.rb).
#
# Which Ghost and which teammate: Core/Ghosts.rb. What's shown: UI/.
#==============================================================================

module GhostlyPossession
  module Team
    RATES = [4000, 2000].freeze   # 1 in this many steps: Normal, Often
    NIGHT = 2
    HAUNTED = 4
    COOLDOWN = 500
    # (his pick 2026-10-25: these, Ecruteak and the Mansion, and the dark places)
    HAUNTED_MAPS = [50, *416..421,                        # Lavender Town and its houses
                    142, *400..403, *467..469, 556,       # the Pokémon Tower
                    359, 648,                             # Ecruteak City and Morty's Ghost Gym
                    611, 696, 697, 704,                   # the Burned Tower
                    585, *649..653,                       # the Bell Tower
                    109,                                  # the Hidden Tomb
                    173, 174, 181, 187,                   # the Pokémon Mansion
                    364,                                  # Dark Cave
                    822, 824,                             # the Moonlit Forest
                    235, 342, 346, 354,                   # the Ruins of Alph
                    589, 590, 591].freeze                 # the Sinjoh Ruins

    module_function

    # [times, out of]: the chance on this step
    def odds(map_id = nil)
      map_id ||= $game_map ? $game_map.map_id : 0
      times = 1
      times *= NIGHT if night?
      times *= HAUNTED if HAUNTED_MAPS.include?(map_id)
      return [times, RATES[Settings.team_rate] || RATES[0]]
    end

    def night?
      return defined?(::PBDayNight) && ::PBDayNight.isNight? ? true : false
    rescue StandardError
      return false
    end

    def step(handled)
      return if handled[0]
      adopt unless Shared.possessed_id
      # the Debug menu's Possess on the Next Step: no chance, no wait
      forced = Debug.forced?
      unless forced
        return unless Settings.team?
        unless Shared.possessed_id
          Shared.quiet_steps = Shared.quiet_steps + 1 if Shared.quiet_steps < COOLDOWN
          return if Shared.quiet_steps < COOLDOWN
        end
        times, out_of = odds
        return unless rand(out_of) < times
      end
      # (a quiet step first: in the Bug Contest the rest of the team is away,
      # and the one possessed would look gone)
      return unless quiet_step?
      return if possessed_somewhere?
      pick = forced ? Debug.pick : nil
      ghost = pick && pick[:ghost] || Ghosts.pick
      return unless ghost
      hosts = Ghosts.hosts(nil, ghost)
      hosts = hosts.select { |p| Note.pid_of(p) == pick[:host] } if pick && pick[:host]
      return if hosts.empty?
      host = hosts[rand(hosts.length)]
      note = Ghosts.note_for(host, ghost)
      if pick
        note[:will] = pick[:will] if pick[:will]
        note[:stay], note[:battles_left] = pick[:stay], Ghosts::STAY_BATTLES[pick[:stay]] if pick[:stay]
      end
      return unless possess(host, note)
      handled[0] = true
      Debug.forced = false
    end

    # The Ghost takes the host: its note, who's possessed, then the moment
    def possess(host, note)
      return false unless Note.write(host, note)
      Shared.possessed_id = Note.pid_of(host)
      kept = Note.read(host)
      GhostlyPossession.log("#{kept[:ghost]} possessed #{host.name} (#{Note::WILLS[kept[:will]]} Will, " \
                            "#{kept[:battles_left]} battles, #{kept[:move]} in slot #{kept[:slot] + 1})")
      UI.possessed(host)
      return true
    end

    # Someone is still possessed: in the party, the PC or the Day Care (one
    # released or traded away isn't, and lets go)
    def possessed_somewhere?
      id = Shared.possessed_id
      return false unless id
      found = owned.any? { |pkmn| Note.pid_of(pkmn) == id && Note.possessed?(pkmn) }
      Shared.possessed_id = nil unless found
      return found
    end

    def owned
      list = $Trainer ? $Trainer.party.compact : []
      if $PokemonStorage
        $PokemonStorage.maxBoxes.times do |box|
          $PokemonStorage.maxPokemon(box).times do |i|
            pkmn = $PokemonStorage[box, i]
            list << pkmn if pkmn
          end
        end
      end
      daycare = $PokemonGlobal && $PokemonGlobal.respond_to?(:daycare) ? $PokemonGlobal.daycare : nil
      Array(daycare).each { |slot| list << slot[0] if slot.is_a?(Array) && slot[0] }
      # the team waiting while the Bug Contest is on
      contest = $PokemonGlobal && $PokemonGlobal.respond_to?(:bugContestState) ? $PokemonGlobal.bugContestState : nil
      away = contest ? contest.instance_variable_get(:@otherparty) : nil
      Array(away).each { |pkmn| list << pkmn if pkmn }
      return list
    end

    # One of the team still possessed while nobody's known to be (a team
    # that was away, like the Bug Contest's): it's the one again
    def adopt
      return unless $Trainer
      pkmn = $Trainer.party.find { |p| p && Note.possessed?(p) && !Note.wild?(p) }
      return unless pkmn
      Shared.possessed_id = Note.pid_of(pkmn)
      GhostlyPossession.log("#{pkmn.name} is the possessed one again")
    end

    # A step the moment can play on
    def quiet_step?
      return false unless $scene.is_a?(::Scene_Map) && $game_player && $game_map && $game_temp && $PokemonGlobal
      return false if pbIsFaded? || pbMapInterpreterRunning?
      t = $game_temp
      return false if t.in_menu || t.in_battle || t.message_window_showing || t.player_transferring
      return false if $game_player.move_route_forcing
      return false if $game_map.events.values.any? { |e| e.starting }
      return false if $PokemonGlobal.respond_to?(:sliding) && $PokemonGlobal.sliding
      return false if defined?(pbInSafari?) && pbInSafari?
      return false if defined?(pbInBugContest?) && pbInBugContest?
      return !autosave_step?
    end

    # The step the game autosaves on (Autosave every so many steps)
    def autosave_step?
      return false unless defined?(::AUTOSAVE_STEPS_SWITCH) && defined?(::AUTOSAVE_STEPS_VAR)
      return false unless $game_switches && $game_switches[::AUTOSAVE_STEPS_SWITCH]
      n = pbGet(::AUTOSAVE_STEPS_VAR).to_i
      return n > 0 && $PokemonGlobal.stepcount % n == 0
    rescue StandardError
      return false
    end

    def boot
      return true if @booted
      ::Events.onStepTakenTransferPossible += proc { |_sender, e|
        begin
          GhostlyPossession::Team.step(e[0])
        rescue StandardError => err
          GhostlyPossession.log("A step's possession check failed: #{err.class}: #{err.message}")
        end
      }
      @booted = true
      return true
    end
  end
end
