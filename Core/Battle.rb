#==============================================================================
# Ghostly Possession: battles
#==============================================================================
# Where a battle meets the engine (Core/Engine.rb):
#
#   pbStartBattle    Haunted Wilds rolls for the lone wild Pokémon
#                    (Core/Wilds.rb), before KIF's Nuzlocke judges it
#   pbSetUpSides     possessed Pokémon become the fusion before the battle
#                    builds its battlers from them (yours and, in a wild
#                    battle, a lone wild one)
#   pbEndOfBattle    back to themselves after the battle has ended, and
#                    the battle counted (Core/Leave.rb)
#   pbStartBattle    ...and if a battle stops early (an aborted battle
#                    skips pbEndOfBattle)
#   pbSendOut        who of yours was sent out, for the count
#   pbSetSeen        the Pokédex learns the host, not the fusion
#   pbLearnMove      a level-up move goes in among its own moves; the
#                    Ghost's move keeps its slot
#   pbCanMegaEvolve? never while possessed (Megas would keep the fusion)
#   Kernel.tryAutosave  held while anything is the fusion, and made once
#                    they're back (a win's autosave runs inside
#                    pbEndOfBattle), so a save never holds a fusion
#
# Not in battles that aren't really the player's: the Bug Contest, recorded
# and Battle Frontier battles, Self-Battle copies, and multiplayer battles.
# Every hook runs the game's own code even when Ghostly Possession's part
# fails (logged).
#==============================================================================

module GhostlyPossession
  module Battle
    module_function

    def eligible?(battle)
      return false unless battle.internalBattle
      return false if defined?(::PokeBattle_BugContestBattle) && battle.is_a?(::PokeBattle_BugContestBattle)
      return false if defined?(::PokeBattle_RecordedBattle) && battle.is_a?(::PokeBattle_RecordedBattle)
      return false if defined?(::KIF::SelfBattle) && ::KIF::SelfBattle.instance_variable_get(:@active)
      return false if defined?(::CoopBattleState) && ::CoopBattleState.respond_to?(:in_coop_battle?) && ::CoopBattleState.in_coop_battle?
      return false if defined?(::PvPBattleState) && ::PvPBattleState.respond_to?(:in_pvp_battle?) && ::PvPBattleState.in_pvp_battle?
      return true
    rescue StandardError
      return false
    end

    # The battle's possessed Pokémon become the fusion: the player's own
    # (by identity, so a partner's never are) and, in a wild battle, a lone
    # wild one (Alone Only: with others it battles as itself)
    def apply_all(battle)
      return unless eligible?(battle)
      party = $Trainer ? $Trainer.party : []
      Array(battle.pbParty(0)).each do |pkmn|
        Engine.apply(pkmn) if pkmn && party.any? { |p| p.equal?(pkmn) } && Note.possessed?(pkmn) && !Note.wild?(pkmn)
      end
      return unless battle.wildBattle?
      foes = Array(battle.pbParty(1)).compact
      Engine.apply(foes[0]) if foes.length == 1 && Note.possessed?(foes[0])
    end

    # Back to themselves, then the autosave that waited (if any)
    def restore_all
      Engine.restore_all
      autosave_now
    end

    def autosave_now
      return unless @autosave_waiting
      @autosave_waiting = false
      ::Kernel.tryAutosave
    end

    # Who of the player's side was sent out (the game's own usedInBattle is
    # by place on the field, not by Pokémon)
    def sent_out(battle, send_outs)
      sent = battle.instance_variable_get(:@gp_sent)
      sent = battle.instance_variable_set(:@gp_sent, {}.compare_by_identity) unless sent
      Array(send_outs).each { |b| sent[b[1]] = true if b && b[1] && b[0].to_i.even? }
    end

    def sent_out?(battle, pkmn)
      sent = battle.instance_variable_get(:@gp_sent)
      return sent ? sent.has_key?(pkmn) : false
    end

    def hold_autosave
      @autosave_waiting = true
    end

    def safely(what)
      yield
    rescue StandardError => e
      GhostlyPossession.log("#{what}: #{e.class}: #{e.message}")
    end

    #--------------------------------------------------------------------------
    # PokeBattle_Battle
    #--------------------------------------------------------------------------
    module Hooks
      def pbSetUpSides
        GhostlyPossession::Battle.safely("Possession at the battle's start") { GhostlyPossession::Battle.apply_all(self) }
        return super
      end

      def pbStartBattle(*args)
        GhostlyPossession::Battle.safely("Haunted Wilds") { GhostlyPossession::Wilds.roll(self) }
        return super
      ensure
        GhostlyPossession::Battle.safely("Possession after the battle") { GhostlyPossession::Battle.restore_all }
      end

      # (counted before the autosave that waited, so the save has it)
      def pbEndOfBattle(*args)
        ret = super
        GhostlyPossession::Battle.safely("Possession after the battle") { GhostlyPossession::Engine.restore_all }
        GhostlyPossession::Battle.safely("Counting the battle") { GhostlyPossession::Leave.count(self) }
        GhostlyPossession::Battle.safely("The autosave after the battle") { GhostlyPossession::Battle.autosave_now }
        return ret
      end

      def pbSendOut(sendOuts, *args)
        GhostlyPossession::Battle.safely("Who was sent out") { GhostlyPossession::Battle.sent_out(self, sendOuts) }
        return super
      end

      def pbSetSeen(battler)
        pkmn = battler && battler.respond_to?(:pokemon) ? battler.pokemon : nil
        snap = pkmn && GhostlyPossession::Engine.snapshot(pkmn)
        return super unless snap
        return if !@internalBattle
        host = snap[:ivars][:@species] ? snap[:ivars][:@species][0] : pkmn.species
        form = [:@forced_form, :@form].map { |iv| snap[:ivars][iv] && snap[:ivars][iv][0] }.compact.first
        pbPlayer.pokedex.register(host, battler.displayGender, form.to_i)
      end

      def pbLearnMove(idxParty, newMove)
        pkmn = pbParty(0)[idxParty]
        snap = pkmn && GhostlyPossession::Engine.snapshot(pkmn)
        return super unless snap && snap[:ghost_move]
        GhostlyPossession::Engine.with_own_moves(pkmn, self, pbFindBattler(idxParty)) { super }
      end

      def pbCanMegaEvolve?(idxBattler)
        b = @battlers[idxBattler]
        return false if b && b.pokemon && GhostlyPossession::Engine.applied?(b.pokemon)
        return super
      end
    end

    # Kernel.tryAutosave: held while anything is the fusion
    module Autosave
      def tryAutosave(*args)
        if GhostlyPossession::Engine.any_applied?
          GhostlyPossession::Battle.hold_autosave
          return
        end
        return super
      end
    end

    def boot
      ::PokeBattle_Battle.prepend(Hooks) unless ::PokeBattle_Battle.ancestors.include?(Hooks)
      if ::Kernel.respond_to?(:tryAutosave) && !::Kernel.singleton_class.ancestors.include?(Autosave)
        ::Kernel.singleton_class.prepend(Autosave)
      end
      return true
    end
  end

  module Engine
    module_function

    # A level-up move goes in among the Pokémon's own moves: its own move
    # (or no move) is back in the Ghost's slot while the game teaches it, then
    # the Ghost's move goes back in that slot (or after the last move), on
    # the Pokémon and on its battler.
    def with_own_moves(pkmn, battle, battler)
      snap = snapshot(pkmn)
      slot = snap[:slot]
      ghost = snap[:ghost_move]
      return yield unless pkmn.moves[slot].equal?(ghost)
      snap[:old_move] ? pkmn.moves[slot] = snap[:old_move] : pkmn.moves.delete_at(slot)
      if battler
        battler.moves[slot] = ::PokeBattle_Move.from_pokemon_move(battle, snap[:old_move]) if snap[:old_move]
        battler.moves.delete_at(slot) unless snap[:old_move]
      end
      begin
        return yield
      ensure
        if snap[:old_move] || pkmn.moves.length >= ::Pokemon::MAX_MOVES
          # the move now in the slot is its own (four of its own: the Ghost's takes the slot)
          snap[:old_move] = pkmn.moves[slot]
        else
          slot = snap[:slot] = pkmn.moves.length
        end
        pkmn.moves[slot] = ghost
        battler.moves[slot] = ::PokeBattle_Move.from_pokemon_move(battle, ghost) if battler
      end
    end
  end
end
