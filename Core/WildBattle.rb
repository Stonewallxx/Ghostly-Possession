#==============================================================================
# Ghostly Possession: a possessed wild Pokémon's battle
#==============================================================================
# A possessed wild Pokémon battles as the fusion (Battle.rb), with the aura
# and the ghost mark (UI/BattleLook.rb). Here, what its battle says and does
# (A Possessed Wild Appears = Aura and a Mark, his pick 2026-10-24):
#
#   The intro       "A possessed Rattata appeared!" (or "The possessed
#                   Rattata was caught off guard!") in place of the game's
#   Caught          Balls work on it (his change 2026-10-24: Catch and
#                   Choose). Where the game stores a caught Pokémon (before
#                   the Pokédex and the nickname), Keep Which? (UI/Keep.rb):
#                   the host or the Ghost stays, the other goes free. The
#                   kept Ghost is a new Pokémon at the host's level (the
#                   stage that suits it, its shininess) in the same ball;
#                   both are seen in the Pokédex. In KIF's Nuzlocke the kept
#                   one is the route's catch; with the Dupes Clause a line
#                   you have can't be kept, and the encounter counts if
#                   either line is new. One that turned alpha as its battle
#                   started (Alpha Encounters): the alpha is kept, no
#                   question.
#   The slip       In the red (a quarter of its HP), the Ghost's grip
#                   slips (The Mark Turns Gold, his pick 2026-10-24): the
#                   mark turns gold, the aura thins (UI/BattleLook.rb), and
#                   once: "The Gastly's grip is slipping! Cast it out: Dark
#                   or Ghost moves, or a Cleanse Tag."
#   Cast out        A Dark- or Ghost-type hit that leaves it in the red
#                   (after that turn), or a Cleanse Tag used on it from the
#                   battle's Bag (Core/CleanseTag.rb): the Ghost bursts out
#                   (Its Own Battle Next): a cold white light, the Ghost
#                   rising away; it's itself again, as it is: "The Gastly
#                   burst out of Rattata and fled! Rattata is itself again:
#                   Catch it!" 10% of the time it holds a Cleanse Tag. Its
#                   move this turn follows its own moves. After the battle
#                   (won, run from or caught), on the map, the Ghost's own
#                   battle: "The angry Gastly came back to fight! Catch it
#                   while you can!" (Leave.rb; in KIF's Nuzlocke only to
#                   fight it). In KIF's Nuzlocke, a freed host whose line
#                   you have is a dupe again.
#   The Leap        Knocked out with the Ghost still in (Mid-Battle, Card
#                   After, his pick 2026-10-24): half the time the angry
#                   Ghost leaps into your Pokémon that knocked it out (else
#                   another of yours in the battle that may be possessed),
#                   with Team Possession On and nobody possessed yet: "Its
#                   angry Gastly leaped at Pikachu!", the Gastly rising out
#                   of the fainted one and leaping across to Pikachu, a
#                   purple flash as it goes in, it's the fusion, "The
#                   Gastly possessed Pikachu!"; after the
#                   battle, on the map, the Possessed! card telling how. The
#                   same Ghost (its kind, its shininess); its move, Will and
#                   stay as a Ghost that wanders in. Otherwise: "The Gastly
#                   inside it slipped away..."
#==============================================================================

module GhostlyPossession
  module WildBattle
    SLIP = 4                       # its grip slips at this share of its HP (a quarter: the red)
    TAG_CHANCE = 10                # % a freed host holds a Cleanse Tag (his pick 2026-10-24)
    LEAP_CHANCE = 50               # % a knocked-out one's Ghost leaps into your team
    CAST_TYPES = [:DARK, :GHOST].freeze

    module_function

    # The battle's lone wild Pokémon, while it's the possessed fusion
    def possessed_foe(battle)
      return nil unless battle.wildBattle?
      foes = Array(battle.pbParty(1)).compact
      return nil unless foes.length == 1 && Engine.applied?(foes[0]) && Note.wild?(foes[0])
      return foes[0]
    end

    def ghost_name(note)
      return ::GameData::Species.get(note[:ghost]).name
    rescue StandardError
      return note[:ghost].to_s.capitalize
    end

    # [the game's intro, ours] for this battle, or nil
    def intro(battle)
      came_back = GhostBattle.came_back
      if came_back
        foes = Array(battle.pbParty(1)).compact
        return nil unless foes.length == 1
        name = foes[0].name
        words = GhostBattle.catchable?(came_back) ? _INTL("The angry {1} came back to fight! Catch it while you can!", name) :
                                                    _INTL("The angry {1} came back to fight!", name)
        return [_INTL("Oh! A wild {1} appeared!", name), words]
      end
      foe = possessed_foe(battle)
      return nil unless foe
      if battle.instance_variable_get(:@caughtOffGuard)
        return [_INTL("The wild {1} was caught off guard!", foe.name), _INTL("The possessed {1} was caught off guard!", foe.name)]
      end
      return [_INTL("Oh! A wild {1} appeared!", foe.name), _INTL("A possessed {1} appeared!", foe.name)]
    end

    #--------------------------------------------------------------------------
    # The slip, and casting the Ghost out in battle
    #--------------------------------------------------------------------------
    # A wild one's grip is slipping: in the red, still standing
    def slipping?(pkmn)
      return false unless pkmn && Engine.applied?(pkmn) && Note.wild?(pkmn)
      return pkmn.hp > 0 && pkmn.hp <= pkmn.totalhp / SLIP
    end

    def battler_of(battle, pkmn)
      return Array(battle.battlers).find { |b| b && b.pokemon.equal?(pkmn) }
    end

    # After a battler's turn and at the round's end: a leap waiting (even as
    # the battle ends), a cast-out waiting, then the slip's words (once a
    # battle)
    def after_turn(battle)
      return unless battle.wildBattle?
      flush_leap(battle)
      return unless battle.decision == 0
      flush(battle)
      tell_slip(battle)
    end

    #--------------------------------------------------------------------------
    # The Leap
    #--------------------------------------------------------------------------
    # A possessed wild one fainted with its Ghost still in: the leap waits
    # for the turn's end
    def fainted(battle, battler)
      pkmn = battler && battler.pokemon
      return unless pkmn && Engine.applied?(pkmn) && Note.wild?(pkmn)
      return if battle.instance_variable_get(:@gp_leap_done)
      battle.instance_variable_set(:@gp_leap_done, true)
      battle.instance_variable_set(:@gp_leap, [Note.read(pkmn), battler.index])
    end

    def flush_leap(battle)
      note, from = battle.instance_variable_get(:@gp_leap)
      return unless note
      battle.instance_variable_set(:@gp_leap, nil)
      leap(battle, note, from)
    end

    # Yours that it may leap into: in the battle, standing, really in your
    # party, a host for this Ghost; the one that knocked it out first
    def leap_target(battle, ghost)
      party = $Trainer ? $Trainer.party : []
      mine = Array(battle.battlers).each_with_index.select do |b, i|
        b && !b.fainted? && b.pokemon && battle.pbOwnedByPlayer?(i) && party.any? { |p| p.equal?(b.pokemon) } &&
          !Engine.applied?(b.pokemon) && Ghosts.host?(b.pokemon, ghost) &&
          !(defined?(::PBEffects::Transform) && b.effects[::PBEffects::Transform])
      end.map(&:first)
      last = battle.respond_to?(:lastMoveUser) ? battle.lastMoveUser : nil
      return mine.find { |b| b.index == last } || mine.first
    end

    # from: the fainted one's battler index (the Ghost leaps out of its place)
    def leap(battle, note, from = nil)
      ghost = ghost_name(note)
      target = Settings.team? && !Team.possessed_somewhere? ? leap_target(battle, note[:ghost]) : nil
      unless target && rand(100) < LEAP_CHANCE
        battle.pbDisplayPaused(_INTL("The {1} inside it slipped away...", ghost))
        return false
      end
      host = target.pokemon
      # the same Ghost (its kind, its shininess); its move, Will and stay as one that wanders in
      fresh = Ghosts.note_for(host, note[:ghost], note[:ghost_shiny])
      fresh = fresh.merge(:ghost => note[:ghost], :move => Ghosts.move_for(note[:ghost], host.level, host))
      return false unless Note.write(host, fresh)
      Shared.possessed_id = Note.pid_of(host)
      battle.instance_variable_set(:@gp_leapt, host)
      battle.pbDisplayPaused(_INTL("Its angry {1} leaped at {2}!", ghost, host.name))
      change = proc do
        Engine.apply(host)
        refresh(battle, target)
      end
      if defined?(BattleLook) && BattleLook.respond_to?(:leapt)
        BattleLook.leapt(battle, target, from, note, &change)
      else
        change.call
      end
      Leave.queue_leapt(host, leap_from(battle))
      kept = Note.read(host)
      GhostlyPossession.log("A wild one's #{kept[:ghost]} leaped into #{host.name} (#{Note::WILLS[kept[:will]]} Will, " \
                            "#{kept[:battles_left]} battles, #{kept[:move]} in slot #{kept[:slot] + 1})")
      battle.pbDisplayPaused(_INTL("The {1} possessed {2}!", ghost, host.name))
      return true
    end

    # The fainted one's name (the possessed wild one)
    def leap_from(battle)
      foe = Array(battle.pbParty(1)).compact.first
      return foe ? foe.name : ""
    end

    def tell_slip(battle)
      return if battle.instance_variable_get(:@gp_slip_told)
      foe = possessed_foe(battle)
      return unless foe && slipping?(foe)
      b = battler_of(battle, foe)
      return unless b && !b.fainted?
      battle.instance_variable_set(:@gp_slip_told, true)
      battle.scene.pbRefreshOne(b.index) if battle.scene.respond_to?(:pbRefreshOne)
      battle.pbDisplayPaused(_INTL("The {1}'s grip is slipping! Cast it out: Dark or Ghost moves, or a Cleanse Tag.",
                                   ghost_name(Note.read(foe))))
    end

    # A Dark- or Ghost-type hit that leaves it in the red: cast out once
    # the turn is over (never in the middle of a move)
    def hit(battle, move, target)
      return unless target && !target.fainted? && slipping?(target.pokemon)
      type = (move.calcType rescue nil) || (move.type rescue nil)
      return unless CAST_TYPES.include?(type)
      battle.instance_variable_set(:@gp_cast, target.index)
    end

    def flush(battle)
      idx = battle.instance_variable_get(:@gp_cast)
      return unless idx
      battle.instance_variable_set(:@gp_cast, nil)
      b = battle.battlers[idx]
      cast_out(battle, b, :hit) if b && !b.fainted? && slipping?(b.pokemon)
    end

    # The Ghost bursts out: the host is itself again, as it is, to catch; the
    # Ghost's own battle comes after this one
    def cast_out(battle, battler, how)
      pkmn = battler.pokemon
      note = Note.read(pkmn)
      return false unless note && note[:wild] && Engine.applied?(pkmn)
      return false if defined?(::PBEffects::Transform) && battler.effects[::PBEffects::Transform]
      change = proc do
        Engine.restore(pkmn)
        Note.clear(pkmn)
        # (on its battler too, so Thief or Knock Off sees it)
        if !pkmn.item && !battler.item && rand(100) < TAG_CHANCE && CleanseTag.exists?
          battler.item = CleanseTag::ITEM
          GhostlyPossession.log("The freed #{pkmn.name} holds a Cleanse Tag")
        end
        refresh(battle, battler)
      end
      if defined?(BattleLook) && BattleLook.respond_to?(:burst)
        BattleLook.burst(battle, battler, note, &change)
      else
        change.call
      end
      battle.instance_variable_set(:@gp_ghost_after, [note, pkmn.level])
      nuzlocke_dupe_again(battle, pkmn)
      GhostlyPossession.log("The #{note[:ghost]} was cast out of the wild #{pkmn.name} (#{how})")
      battle.pbDisplayPaused(_INTL("The {1} burst out of {2} and fled! {2} is itself again: Catch it!", ghost_name(note), pkmn.name))
      return true
    end

    # The battler follows its Pokémon after a change of species mid-battle
    # (as the game's own form changes do): species, name, stats, types,
    # ability and moves; its move this turn the one now in that slot
    def refresh(battle, battler)
      pkmn = battler.pokemon
      old_ability = battler.ability_id
      battler.instance_variable_set(:@species, pkmn.species)
      battler.instance_variable_set(:@form, pkmn.form)
      battler.instance_variable_set(:@name, pkmn.name)
      battler.instance_variable_set(:@gender, pkmn.gender)
      battler.pbUpdate(true)
      battler.moves = pkmn.moves.map { |m| ::PokeBattle_Move.from_pokemon_move(battle, m) }
      choice = (battle.choices[battler.index] rescue nil)
      if choice && choice[0] == :UseMove
        if choice[1].is_a?(Integer) && choice[1] >= 0 && battler.moves[choice[1]]
          choice[2] = battler.moves[choice[1]]
        elsif battle.respond_to?(:pbAutoChooseMove)
          battle.pbAutoChooseMove(battler.index, false)
        end
      end
      battler.pbOnAbilityChanged(old_ability) if old_ability != battler.ability_id && battler.respond_to?(:pbOnAbilityChanged)
      scene = battle.scene
      scene.pbChangePokemon(battler, pkmn) if scene.respond_to?(:pbChangePokemon)
      scene.pbRefreshOne(battler.index) if scene.respond_to?(:pbRefreshOne)
    end

    # KIF's Nuzlocke: an encounter that counted for the Ghost inside (the
    # Dupes Clause) doesn't once it's out and the host's line is one you have
    def nuzlocke_dupe_again(battle, host)
      return unless nuzlocke_on? && battle.respond_to?(:kif_nz) && battle.kif_nz == :first
      return unless $PokemonSystem.respond_to?(:ch_nz_dupes) && $PokemonSystem.ch_nz_dupes == 1
      owned = ::KIF::Nuzlocke.owned_lines
      return unless ::KIF::Nuzlocke.lines(host).all? { |l| owned[l] }
      battle.instance_variable_set(:@kif_nz, :dupe)
      ::KIF::Nuzlocke.pending = nil if ::KIF::Nuzlocke.respond_to?(:pending=)
    rescue StandardError
      nil
    end

    # After the battle: the Ghost's own battle, on the map (won, run from or caught)
    def after_battle(battle)
      after = battle.instance_variable_get(:@gp_ghost_after)
      return unless after
      battle.instance_variable_set(:@gp_ghost_after, nil)
      Leave.queue_ghost(after[0], after[1]) if [1, 3, 4].include?(battle.decision)
    end

    #--------------------------------------------------------------------------
    # Caught: Keep Which?
    #--------------------------------------------------------------------------
    def keep_which(battle)
      caught = battle.instance_variable_get(:@caughtPokemon)
      return unless caught.is_a?(Array)
      caught.each_with_index do |pkmn, i|
        note = Note.read(pkmn)
        next unless note
        unless note[:wild] && Engine.applied?(pkmn)
          # a note that never battled possessed (Alone Only): it's gone
          Engine.restore(pkmn)
          Note.clear(pkmn)
          next
        end
        Engine.restore(pkmn)
        Note.clear(pkmn)
        # its first moves its own (the catch recorded them with the Ghost's
        # move in its slot: the Move Relearner would offer it)
        pkmn.record_first_moves if pkmn.respond_to?(:record_first_moves)
        ghost = caught_ghost(note, pkmn)
        battle.pbPlayer.pokedex.register(ghost) rescue nil
        # an alpha (it turned alpha as its battle started): the alpha's kept
        # (Both, Keep the Alpha, his pick 2026-10-24)
        pick = Wilds.alpha?(pkmn) ? 0 : Keep.ask(battle, pkmn, ghost, note, dupes(pkmn, ghost))
        if pick == 1
          caught[i] = ghost
          nuzlocke_swap(pkmn, ghost)
          GhostlyPossession.log("Kept the #{ghost.species} from inside #{pkmn.name}")
          battle.pbDisplayPaused(_INTL("The {1} ran off.", pkmn.name))
        else
          GhostlyPossession.log("Kept #{pkmn.name}; the #{ghost.species} went free")
          battle.pbDisplayPaused(_INTL("The {1} drifted away.", ghost.name))
        end
      end
    end

    # The Ghost as a Pokémon of its own, caught in the host's ball
    def caught_ghost(note, host)
      ghost = ::Pokemon.new(note[:ghost], host.level)
      ghost.shiny = note[:ghost_shiny] ? true : false
      ghost.poke_ball = host.poke_ball if host.respond_to?(:poke_ball)
      ghost.record_first_moves if ghost.respond_to?(:record_first_moves)
      return ghost
    end

    def nuzlocke_on?
      return defined?(::KIF::Nuzlocke) && ::KIF::Nuzlocke.respond_to?(:on?) && ::KIF::Nuzlocke.on? ? true : false
    rescue StandardError
      return false
    end

    # KIF's Nuzlocke Dupes Clause: which can't be kept (0 the host, 1 the
    # Ghost); never both
    def dupes(host, ghost)
      return [] unless nuzlocke_on? && $PokemonSystem.respond_to?(:ch_nz_dupes) && $PokemonSystem.ch_nz_dupes == 1
      owned = ::KIF::Nuzlocke.owned_lines
      out = []
      out << 0 if ::KIF::Nuzlocke.lines(host).all? { |l| owned[l] }
      out << 1 if ::KIF::Nuzlocke.lines(ghost).all? { |l| owned[l] }
      return out.length == 2 ? [] : out
    rescue StandardError
      return []
    end

    # ...and the encounter counts when the Ghost inside is a new line
    def new_line_inside?(foes)
      owned = nil
      return Array(foes).any? do |pkmn|
        note = Note.read(pkmn)
        next false unless note && note[:wild] && !Wilds.alpha?(pkmn)   # an alpha's Ghost can't be kept
        owned ||= ::KIF::Nuzlocke.owned_lines
        ::KIF::Nuzlocke.lines(::Pokemon.new(note[:ghost], [pkmn.level, 1].max)).any? { |l| !owned[l] }
      end
    rescue StandardError
      return false
    end

    # KIF's Nuzlocke records the route's catch: the Ghost, when it's kept
    def nuzlocke_swap(host, ghost)
      return unless defined?(::KIF::Nuzlocke) && ::KIF::Nuzlocke.respond_to?(:pending)
      pending = ::KIF::Nuzlocke.pending
      return unless pending.is_a?(Array) && pending[1].is_a?(Array)
      j = pending[1].index { |p| p.equal?(host) }
      pending[1][j] = ghost if j
    rescue StandardError
      nil
    end

    #--------------------------------------------------------------------------
    # PokeBattle_Battle
    #--------------------------------------------------------------------------
    module Hooks
      def pbStartBattleSendOut(*args)
        @gp_intro = nil
        GhostlyPossession::Battle.safely("The possessed intro") { @gp_intro = GhostlyPossession::WildBattle.intro(self) }
        return super
      ensure
        @gp_intro = nil
      end

      # the game's intro line, swapped once
      def pbDisplayPaused(msg, &block)
        if @gp_intro && msg == @gp_intro[0]
          msg = @gp_intro[1]
          @gp_intro = nil
        end
        return super(msg, &block)
      end

      def pbRecordAndStoreCaughtPokemon(*args)
        GhostlyPossession::Battle.safely("Keep Which?") { GhostlyPossession::WildBattle.keep_which(self) }
        return super
      end

      def pbEndOfRoundPhase(*args)
        ret = super
        GhostlyPossession::Battle.safely("The Ghost's grip") { GhostlyPossession::WildBattle.after_turn(self) }
        return ret
      end

      def pbEndOfBattle(*args)
        GhostlyPossession::Battle.safely("The Leap") { GhostlyPossession::WildBattle.flush_leap(self) }
        ret = super
        GhostlyPossession::Battle.safely("The Ghost's own battle") { GhostlyPossession::WildBattle.after_battle(self) }
        GhostlyPossession::Battle.safely("The walking wilds' wait") { GhostlyPossession::Compat.hold! } if wildBattle?
        return ret
      end
    end

    # PokeBattle_Battler
    module BattlerHooks
      def pbEffectsOnMakingHit(move, user, target)
        ret = super
        GhostlyPossession::Battle.safely("A hit on a possessed one") { GhostlyPossession::WildBattle.hit(@battle, move, target) }
        return ret
      end

      def pbProcessTurn(*args)
        ret = super
        GhostlyPossession::Battle.safely("The Ghost's grip") { GhostlyPossession::WildBattle.after_turn(@battle) }
        return ret
      end

      def pbFaint(*args)
        ret = super
        GhostlyPossession::Battle.safely("The Leap") { GhostlyPossession::WildBattle.fainted(@battle, self) if fainted? }
        return ret
      end
    end

    def boot
      ::PokeBattle_Battle.prepend(Hooks) unless ::PokeBattle_Battle.ancestors.include?(Hooks)
      ::PokeBattle_Battler.prepend(BattlerHooks) if defined?(::PokeBattle_Battler) && !::PokeBattle_Battler.ancestors.include?(BattlerHooks)
      return true
    end
  end
end
