#==============================================================================
# Ghostly Possession: the Ghost takes control
#==============================================================================
# Now and then the Ghost inside acts on its own (Power With a Will, his pick
# 2026-10-24): after the player has chosen, each turn, a possessed Pokémon
# that was to use a move may use the Ghost's move instead. The chance is its
# Will: Calm 10%, Normal 20%, Wild 35%.
#
#   Not when it was going to use the Ghost's move anyway, nor while it's
#   locked into a move (a two-turn move, Encore, Struggle), nor when the
#   Ghost's move can't be used (no PP, Disable, Taunt...). Switching, items
#   and running are the player's.
#
# When it moves, before its move: the sprite flashes purple and the Ghost
# shows through, "The Gastly inside Pikachu took control!"
# (UI/BattleLook.rb).
#==============================================================================

module GhostlyPossession
  module Control
    WILL_CHANCE = [10, 20, 35].freeze   # % a turn, by Will (Calm, Normal, Wild)
    IVAR = :@ghostly_control              # on the battle: battler indexes it took this turn

    module_function

    # The Ghost's move's slot on this battler, or nil
    def ghost_slot(battler)
      pkmn = battler && battler.pokemon
      snap = pkmn && Engine.snapshot(pkmn)
      return nil unless snap && snap[:ghost_move] && snap[:slot]
      move = battler.moves[snap[:slot]]
      return move && move.id == snap[:ghost_move].id ? snap[:slot] : nil
    rescue StandardError
      return nil
    end

    # After the player has chosen: each of their possessed Pokémon may be
    # taken over
    def roll(battle)
      return unless battle.decision == 0 && Battle.eligible?(battle)
      battle.battlers.each_with_index do |b, i|
        next unless b && !b.fainted? && battle.pbOwnedByPlayer?(i)
        next unless take?(battle, b, i)
        taken = battle.instance_variable_get(IVAR) || {}
        taken[i] = true
        battle.instance_variable_set(IVAR, taken)
        GhostlyPossession.log("The #{Note.read(b.pokemon)[:ghost]} inside #{b.name} takes control this turn")
      end
    end

    def take?(battle, b, i)
      slot = ghost_slot(b)
      return false unless slot
      note = Note.read(b.pokemon)
      return false unless note
      choice = battle.choices[i]
      return false unless choice && choice[0] == :UseMove && choice[1].is_a?(Integer) && choice[1] >= 0
      return false if choice[1] == slot
      return false if b.usingMultiTurnAttack?
      return false if defined?(::PBEffects::Encore) && b.effects[::PBEffects::Encore].to_i > 0
      return false unless rand(100) < (WILL_CHANCE[note[:will]] || WILL_CHANCE[1])
      return battle.pbRegisterMove(i, slot, false) ? true : false
    end

    # As it moves: whether it was taken over this turn (asked once)
    def taken?(battle, idx)
      taken = battle.instance_variable_get(IVAR)
      return taken ? !taken.delete(idx).nil? : false
    end

    #--------------------------------------------------------------------------
    # PokeBattle_Battle / PokeBattle_Battler
    #--------------------------------------------------------------------------
    module BattleHooks
      def pbCommandPhase(*args)
        instance_variable_set(GhostlyPossession::Control::IVAR, nil)
        ret = super
        GhostlyPossession::Battle.safely("The Ghost's turn") { GhostlyPossession::Control.roll(self) }
        return ret
      end
    end

    module BattlerHooks
      def pbProcessTurn(*args)
        if GhostlyPossession::Control.taken?(@battle, @index)
          GhostlyPossession::Battle.safely("The Ghost taking control") { GhostlyPossession::BattleLook.took_control(@battle, self) }
        end
        return super
      end
    end

    def boot
      ::PokeBattle_Battle.prepend(BattleHooks) unless ::PokeBattle_Battle.ancestors.include?(BattleHooks)
      if defined?(::PokeBattle_Battler) && !::PokeBattle_Battler.ancestors.include?(BattlerHooks)
        ::PokeBattle_Battler.prepend(BattlerHooks)
      end
      return true
    end
  end
end
