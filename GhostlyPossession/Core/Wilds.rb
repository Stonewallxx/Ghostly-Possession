#==============================================================================
# Ghostly Possession: Haunted Wilds
#==============================================================================
# Some wild Pokémon have a Ghost inside (Same Rule as Your Team, his pick
# 2026-10-24). Per encounter, with Haunted Wilds On:
#
#   - only a random encounter: walking in grass, a cave or on water, or
#     fishing (no event's battle: legendaries, statics, Headbutt, Rock
#     Smash; no roamer, Poké Radar chain, Safari Zone or Bug Contest)
#   - only a lone wild Pokémon (Alone Only, his pick 2026-10-24: never in a
#     double, a 1v2 or 1v3, or a Horde), never an alpha (Never Both)
#   - a chance of 1 in 100 / 50 (How Often: Normal / Often), twice that at
#     night, four times that in haunted places (Team.rb's)
#   - the host as for your team (Ghosts.host?: not a Ghost, an Egg, a
#     triple fusion or a Shadow Pokémon; fusions too), the Ghost this area's
#     own or the classic list's, at the host's level (Ghosts.rb)
#
# Rolled as the battle starts (PokeBattle_Battle#pbStartBattle, before KIF's
# Nuzlocke judges the encounter); the note is marked :wild. The battle then
# makes it the fusion as it does your own (Battle.rb).
#
#   GhostlyPossession::Wilds.roll(battle)    the encounter's chance
#   GhostlyPossession::Wilds.haunt(pkmn)     a wild Pokémon gets a Ghost
#
# The Debug menu's Haunt the Next Wild Pokémon skips the chance and the kind
# of encounter (Core/Debug.rb).
#==============================================================================

module GhostlyPossession
  module Wilds
    RATES = [100, 50].freeze      # 1 in this many encounters: Normal, Often

    module_function

    # [times, out of]: the chance for this encounter
    def odds(map_id = nil)
      map_id ||= $game_map ? $game_map.map_id : 0
      times = 1
      times *= Team::NIGHT if Team.night?
      times *= Team::HAUNTED if Team::HAUNTED_MAPS.include?(map_id)
      return [times, RATES[Settings.wilds_rate] || RATES[0]]
    end

    # A random encounter's battle (walking or fishing), not an event's
    def random_encounter?
      t = $PokemonTemp
      return false unless t && t.respond_to?(:encounterType) && t.encounterType
      return false if $PokemonGlobal && $PokemonGlobal.respond_to?(:roamEncounter) && $PokemonGlobal.roamEncounter
      return false if t.respond_to?(:pokeradar) && t.pokeradar
      return false if defined?(pbInSafari?) && pbInSafari?
      return false if defined?(pbInBugContest?) && pbInBugContest?
      return !(defined?(pbMapInterpreterRunning?) && pbMapInterpreterRunning?)
    end

    # Alpha Encounters' alphas
    def alpha?(pkmn)
      return pkmn.respond_to?(:alpha?) && pkmn.alpha? ? true : false
    rescue StandardError
      return false
    end

    # The battle's lone wild Pokémon, if it may have a Ghost inside
    def candidate(battle)
      return nil unless battle.wildBattle? && Battle.eligible?(battle)
      return nil if GhostBattle.active?
      foes = Array(battle.pbParty(1)).compact
      return nil unless foes.length == 1
      foe = foes[0]
      return nil if Note.possessed?(foe) || alpha?(foe)
      return foe
    end

    def roll(battle)
      forced = Debug.wild_forced?
      return unless forced || Settings.wilds?
      foe = candidate(battle)
      return unless foe
      unless forced
        return unless random_encounter?
        times, out_of = odds
        return unless rand(out_of) < times
      end
      Debug.wild_forced = false if haunt(foe)
    end

    # The Ghost (this area's own, at its level) goes in; false if it can't
    def haunt(pkmn)
      # (the Debug Menu's Ghost, if it fits this one)
      wanted = Debug.wild_forced? ? Debug.wild_ghost : nil
      ghost = wanted && Ghosts.host?(pkmn, wanted) ? wanted : Ghosts.pick
      return false unless ghost && Ghosts.host?(pkmn, ghost)
      return false unless Note.write(pkmn, Ghosts.note_for(pkmn, ghost).merge(:wild => true))
      note = Note.read(pkmn)
      GhostlyPossession.log("A wild #{pkmn.name} has a #{note[:ghost]} inside (#{note[:move]} in slot #{note[:slot] + 1})")
      return true
    end
  end
end
