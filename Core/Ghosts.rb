#==============================================================================
# Ghostly Possession: which Ghost, which teammate
#==============================================================================
# What a possession is made of (The Area's Own; Random, No Ghosts or Eggs:
# his picks 2026-10-24):
#
#   GhostlyPossession::Ghosts.pick                  a Ghost for here (species)
#   GhostlyPossession::Ghosts.hosts(party)          who it may possess
#   GhostlyPossession::Ghosts.note_for(host, ghost) a new note: the Ghost at
#                                                   the host's level, its
#                                                   move, Will and stay
#
# The Ghost: one of this area's own wild Ghosts (whatever table the game
# uses here: Classic, Remix or randomized), else one from the classic list,
# which grows with the badges (his picks 2026-10-25: the Gastly line counts
# three times, every other line once). It comes at the host's level, as the stage
# that suits it: from its first stage up, a level evolution at its level,
# any other kind (a stone, a trade) from level 40 unless KIF gives it a
# level too. Never a legendary or Shedinja. Any Ghost may possess: one whose
# first type isn't Ghost still makes the possessed Pokémon Ghost first
# (Engine.ghost_first).
# Its move: the newest Ghost-type attack it knows at that level (its
# earlier stages' too, up to when they evolved) that the host doesn't, else
# a Ghost-type move of any kind, else Lick or the like.
# It takes a random move slot (an empty one while the host has fewer than
# four moves).
# The host: a teammate that can still battle, not an Egg, not a Ghost (by
# type, so a fusion with a Ghost half too), not a triple fusion or a Shadow
# Pokémon, and a fusion with the Ghost must exist for it.
# The Ghost's Will and how long it stays are rolled 30 / 50 / 20.
#==============================================================================

module GhostlyPossession
  module Ghosts
    # [badges needed, Ghosts]
    CLASSIC = [[0, [:GASTLY]],
               [2, [:MISDREAVUS, :DUSKULL, :SHUPPET, :DRIFLOON]],
               [4, [:LITWICK, :YAMASK, :PHANTUMP, :PUMPKABOO, :SABLEYE]],
               [6, [:SPIRITOMB, :HONEDGE, :GOLETT, :SANDYGAST, :ROTOM, :MIMIKYU, :DHELMISE, :FROSLASS, :ORICORIO_4]]].freeze
    # how many times a line counts when the classic list is used (else once)
    WEIGHTS = { :GASTLY => 3 }.freeze
    NEVER = [:SHEDINJA].freeze
    OTHER_EVOLUTION_LEVEL = 40          # a stone or trade evolution counts from here
    FALLBACK_MOVES = [:LICK, :ASTONISH, :NIGHTSHADE, :SHADOWSNEAK].freeze
    ROLL = [30, 50, 20].freeze          # Calm / Normal / Wild, Short / Normal / Long
    STAY_BATTLES = [5, 10, 15].freeze   # battles before it leaves, by stay (his ask: multiples of 5)
    STAY_HINTS = [5, 10].freeze         # the Stay hint by battles left: up to 5 "won't stay long", up to 10 "a while", 11+ "settling in"

    module_function

    #--------------------------------------------------------------------------
    # The Ghost
    #--------------------------------------------------------------------------
    def pick
      list = area_ghosts
      list = classic_ghosts.flat_map { |s| [s] * (WEIGHTS[s] || 1) } if list.empty?
      return list.empty? ? nil : list[rand(list.length)]
    end

    # This area's wild Ghosts, in every kind of encounter it has
    def area_ghosts
      return [] unless $PokemonEncounters && defined?(::GameData::EncounterType)
      found = []
      ::GameData::EncounterType.each do |type|
        next unless $PokemonEncounters.has_encounter_type?(type.id)
        Array(listPokemonInCurrentRoute(type.id)).each do |s|
          data = ::GameData::Species.try_get(s)
          found << data.id if data && ghost?(data)
        end
      end
      return found.uniq
    rescue StandardError => e
      GhostlyPossession.log("This area's Ghosts couldn't be listed: #{e.class}: #{e.message}")
      return []
    end

    def classic_ghosts(badges = nil)
      badges ||= $Trainer ? $Trainer.badge_count.to_i : 0
      list = CLASSIC.select { |need, _| badges >= need }.flat_map { |_, ghosts| ghosts }
      return list.select { |s| (data = ::GameData::Species.try_get(s)) && ghost?(data) }
    end

    # A Ghost that may possess: Ghost-type, not a fusion, not a legendary
    def ghost?(data)
      return false if data.id_number > ::Settings::NB_POKEMON || NEVER.include?(data.id)
      return false unless data.type1 == :GHOST || data.type2 == :GHOST
      return !Array(data.egg_groups).include?(:Undiscovered)
    rescue StandardError
      return false
    end

    # The stage of the Ghost's line that suits this level
    def suited(species, level)
      current = first_stage(species)
      8.times do
        options = evolutions(current).select { |_to, at| level >= at }.map { |to, _at| to }
        break if options.empty?
        current = options[rand(options.length)]
      end
      return current
    end

    # [[the Ghost it evolves into, from what level]]: a level evolution at its
    # level, any other kind (a stone, a trade) from level 40; where KIF gives
    # one a level too (Haunter, Dusclops), the level
    def evolutions(species)
      found = {}
      ::GameData::Species.get(species).get_evolutions(true).each do |to, method, param|
        data = ::GameData::Species.try_get(to)
        next unless data && ghost?(data)
        at = method.to_s.start_with?("Level") && param.is_a?(Integer) ? param : nil
        found[data.id] = [found[data.id], at].compact.min if at
        found[data.id] ||= nil
      end
      return found.map { |to, at| [to, at || OTHER_EVOLUTION_LEVEL] }
    end

    # Back through the Ghosts it evolved from (KIF's get_baby_species is
    # private and can't follow a line of more than two)
    def first_stage(species)
      current = ::GameData::Species.get(species).id
      8.times do
        prev = previous(current)
        break unless prev
        current = prev
      end
      return current
    end

    # The Ghost it evolved from, or nil
    def previous(species)
      evos = ::GameData::Species.get(species).instance_variable_get(:@evolutions) || []
      prev = evos.find { |e| e[3] }
      data = prev && ::GameData::Species.try_get(prev[0])
      return data && ghost?(data) ? data.id : nil
    end

    # The newest Ghost-type attack it knows at this level that the host
    # doesn't: its own level-up moves, and its earlier stages' up to the level
    # they evolved at (a Mismagius keeps the Hex it learned as a Misdreavus).
    # An attack before a status move, the stronger of two learned at the same
    # level; else a fallback.
    def move_for(ghost, level, host)
      known = host.moves.map { |m| m.id }
      learned = []
      stage = ::GameData::Species.get(ghost).id
      cap = level
      8.times do
        learned.concat(::GameData::Species.get(stage).moves.select { |lv, m| lv <= cap && ::GameData::Move.exists?(m) })
        prev = previous(stage)
        break unless prev
        at = evolutions(prev).find { |to, _at| to == stage }
        cap = [cap, at ? at[1] : cap].min
        stage = prev
      end
      ordered = learned.sort_by { |lv, m| [-lv, -::GameData::Move.get(m).base_damage.to_i] }
                       .map { |_lv, m| ::GameData::Move.get(m).id }.uniq
      spooky = ordered.select { |m| ::GameData::Move.get(m).type == :GHOST && !known.include?(m) }
      attack = spooky.find { |m| ::GameData::Move.get(m).category != 2 }
      return attack || spooky.first ||
             FALLBACK_MOVES.find { |m| ::GameData::Move.exists?(m) && !known.include?(m) } || FALLBACK_MOVES.first
    end

    def shiny_roll
      return rand(65_536) < ::Settings::SHINY_POKEMON_CHANCE.to_i
    rescue StandardError
      return false
    end

    #--------------------------------------------------------------------------
    # The host
    #--------------------------------------------------------------------------
    def hosts(party = nil, ghost = nil)
      party ||= $Trainer ? $Trainer.party : []
      return Array(party).select { |pkmn| host?(pkmn, ghost) }
    end

    def host?(pkmn, ghost = nil)
      return false if !pkmn || pkmn.egg? || pkmn.hp <= 0
      return false if pkmn.hasType?(:GHOST) || pkmn.isTripleFusion?
      return false if pkmn.respond_to?(:shadowPokemon?) && pkmn.shadowPokemon?
      return false if Note.possessed?(pkmn)
      return true unless ghost
      return !(::GameData::Species.get(Engine.fused_species(pkmn, ghost)) rescue nil).nil?
    rescue StandardError
      return false
    end

    #--------------------------------------------------------------------------
    # The note
    #--------------------------------------------------------------------------
    # A new note for this host and Ghost (the Ghost made the stage that suits
    # the host's level); shiny rolled unless given
    def note_for(host, ghost, shiny = nil)
      level = host.level
      ghost = suited(ghost, level)
      will = weighted(ROLL)
      stay = weighted(ROLL)
      count = host.moves.length
      slot = count < ::Pokemon::MAX_MOVES ? count : rand(::Pokemon::MAX_MOVES)
      return { :ghost => ghost, :ghost_shiny => shiny.nil? ? shiny_roll : (shiny ? true : false),
               :will => will, :stay => stay, :battles_left => STAY_BATTLES[stay], :slot => slot,
               :move => move_for(ghost, level, host), :move_pp => nil }
    end

    # An index, by weights
    def weighted(weights)
      r = rand(weights.sum)
      weights.each_with_index do |w, i|
        return i if r < w
        r -= w
      end
      return weights.length - 1
    end
  end
end
