#==============================================================================
# Ghostly Possession: the engine
#==============================================================================
# Turns a possessed Pokémon into the fusion for a battle and back again
# (Only in Battle, his pick 2026-10-25). The Ghost is the head, the host the
# body: the fusion of a plain host is B<host>H<ghost>; a host that's already
# a fusion keeps its body and the Ghost takes the head's place. Nothing of
# PIF's fusing is used (no pbFuse, no unfusing): the species is changed in
# place and put back from a snapshot kept in memory only, never saved.
#
#   GhostlyPossession::Engine.apply(pkmn)     the fusion, from its note
#   GhostlyPossession::Engine.restore(pkmn)   back to itself
#   GhostlyPossession::Engine.applied?(pkmn) / any_applied? / restore_all
#   GhostlyPossession::Engine.display(pkmn)   a copy that looks like the
#                                             fusion (for pictures)
#
# Its first type is always Ghost (ghost_first: a Ghost whose first type
# isn't Ghost still makes it Ghost first).
# Its stats are the best of both (his pick 2026-10-24): each the higher of
# the host's own and the fusion's, so it's never weaker and stronger where
# the Ghost is (the host's worked out by the game's own calc_stats on a
# copy of it, so every rule of KIF's applies; again after a level-up).
# While applied: its name, level, growth and the moves it learns by level
# stay its own (Pokemon#name, #growth_rate and #getMoveList answer for the
# host), it never evolves (check_evolution_internal), and the Ghost's move sits in
# its slot (Note :slot; on a Pokémon with fewer moves, after the last one).
# Restoring keeps what the battle did (HP as a share of the total, status,
# EXP, level-ups, PP, held item) and puts everything else back exactly. The
# Ghost's move's PP goes back into the note; a full PP heal (a Pokémon
# Center) refills it.
#==============================================================================

module GhostlyPossession
  module Engine
    # What the snapshot keeps and puts back (KIF's lazy caches included, so
    # each answers for the host again: gender, ability, shiny parts...)
    FIELDS = [:@species, :@form, :@forced_form, :@ability, :@ability_index, :@ability2, :@gender, :@shiny,
              :@natural_shiny, :@debug_shiny, :@head_shiny, :@body_shiny, :@pif_sprite, :@type1, :@type2,
              :@typeoverwrite, :@type1kuray, :@type2kuray, :@exp_gained_since_fused].freeze
    @applied = {}.compare_by_identity

    module_function

    def applied?(pkmn)
      return @applied.has_key?(pkmn)
    end

    def any_applied?
      return !@applied.empty?
    end

    def applied
      return @applied.keys
    end

    def snapshot(pkmn)
      return @applied[pkmn]
    end

    # The fusion's species: the Ghost's head on the host's body
    def fused_species(pkmn, ghost)
      head = GameData::Species.get(ghost).id_number
      body = pkmn.isFusion? ? get_body_id_from_symbol(pkmn.species) : pkmn.species_data.id_number
      return :"B#{body}H#{head}"
    end

    def apply(pkmn)
      return false if !pkmn || applied?(pkmn)
      note = Note.read(pkmn)
      return false unless note && GameData::Species.exists?(note[:ghost]) && GameData::Move.exists?(note[:move])
      return false if pkmn.egg? || pkmn.isTripleFusion? || (pkmn.respond_to?(:shadowPokemon?) && pkmn.shadowPokemon?)
      data = pkmn.species_data
      snap = { :ivars => {}, :growth => data.growth_rate, :moves => data.moves.map { |m| m.dup },
               :real_fusion => pkmn.isFusion?, :name => pkmn.name }
      FIELDS.each { |iv| snap[:ivars][iv] = pkmn.instance_variable_defined?(iv) ? [pkmn.instance_variable_get(iv)] : nil }
      # then the lazy caches answer for the host, so the fusion keeps its
      # gender, ability, shininess and nature (restore puts back what was)
      pkmn.gender
      pkmn.ability_index
      host_ability = pkmn.ability_id
      host_shiny = pkmn.shiny? ? true : false
      pkmn.nature
      fused = fused_species(pkmn, note[:ghost])
      fainted = pkmn.hp <= 0
      ratio = pkmn.totalhp > 0 ? pkmn.hp.to_f / pkmn.totalhp : 0.0
      @applied[pkmn] = snap
      begin
        pkmn.instance_variable_set(:@species, fused)
        pkmn.instance_variable_set(:@species_data, nil)
        pkmn.instance_variable_set(:@level, nil)
        pkmn.instance_variable_set(:@ability, host_ability)
        pkmn.instance_variable_set(:@type1, nil)
        pkmn.instance_variable_set(:@type2, nil)
        pkmn.instance_variable_set(:@typeoverwrite, false)
        Engine.ghost_first(pkmn)
        pkmn.instance_variable_set(:@pif_sprite, nil)
        # both shiny parts set, so KIF doesn't roll them
        pkmn.instance_variable_set(:@body_shiny, host_shiny)
        pkmn.instance_variable_set(:@head_shiny, note[:ghost_shiny])
        pkmn.instance_variable_set(:@shiny, host_shiny || note[:ghost_shiny])
        pkmn.calc_stats                      # the best of both (PokemonWhileApplied#calc_stats)
        set_hp(pkmn, fainted, ratio)
        # the Ghost's move in its slot
        slot = [note[:slot], pkmn.moves.length].min
        ghost_move = Pokemon::Move.new(note[:move])
        ghost_move.pp = note[:move_pp] if note[:move_pp]
        snap[:slot] = slot
        snap[:old_move] = pkmn.moves[slot]
        snap[:learned] = Array(pkmn.learned_moves).include?(ghost_move.id)
        snap[:ghost_move] = ghost_move
        pkmn.moves[slot] = ghost_move
      rescue StandardError
        restore(pkmn)
        raise
      end
      return true
    rescue StandardError => e
      GhostlyPossession.log("Couldn't make #{pkmn.name rescue "?"} the fusion: #{e.class}: #{e.message}")
      return false
    end

    def restore(pkmn)
      snap = @applied[pkmn]
      return false unless snap
      fainted = pkmn.hp <= 0
      ratio = pkmn.totalhp > 0 ? pkmn.hp.to_f / pkmn.totalhp : 0.0
      ghost_pp = nil
      # the Ghost's move out of its slot, its PP kept for the note
      slot = snap[:slot]
      ghost_move = snap[:ghost_move]
      if slot && ghost_move
        if pkmn.moves[slot].equal?(ghost_move)
          ghost_pp = ghost_move.pp
          snap[:old_move] ? pkmn.moves[slot] = snap[:old_move] : pkmn.moves.delete_at(slot)
        elsif (i = pkmn.moves.index { |m| m.equal?(ghost_move) })
          ghost_pp = ghost_move.pp
          snap[:old_move] ? pkmn.moves[i] = snap[:old_move] : pkmn.moves.delete_at(i)
        end
        # (kept when the Pokémon learned the same move itself in the battle)
        learned = pkmn.learned_moves
        if learned.is_a?(Array) && !snap[:learned] && pkmn.moves.none? { |m| m && m.id == ghost_move.id }
          learned.delete(ghost_move.id)
        end
      end
      # a real fusion's EXP since it was fused is its own (it keeps gaining)
      gained = pkmn.instance_variable_get(:@exp_gained_since_fused)
      snap[:ivars].each do |iv, kept|
        if kept
          pkmn.instance_variable_set(iv, kept[0])
        elsif pkmn.instance_variable_defined?(iv)
          pkmn.remove_instance_variable(iv)
        end
      end
      pkmn.instance_variable_set(:@exp_gained_since_fused, gained) if snap[:real_fusion]
      @applied.delete(pkmn)
      pkmn.instance_variable_set(:@species_data, nil)
      pkmn.instance_variable_set(:@level, nil)
      pkmn.calc_stats
      set_hp(pkmn, fainted, ratio)
      if ghost_move && (note = Note.read(pkmn))
        Note.write(pkmn, note.merge(:move_pp => ghost_pp && ghost_pp < ghost_move.total_pp ? ghost_pp : nil))
      end
      return true
    rescue StandardError => e
      @applied.delete(pkmn)
      GhostlyPossession.log("Couldn't turn #{pkmn.name rescue "?"} back fully: #{e.class}: #{e.message}")
      return false
    end

    def restore_all
      @applied.keys.each { |pkmn| restore(pkmn) }
    end

    # A copy that looks like the fusion, for a picture outside battle (its
    # species, shiny parts and types; nothing else is worked out). nil when
    # the Pokémon isn't possessed or can't be.
    def display(pkmn)
      note = Note.read(pkmn)
      return nil unless note && GameData::Species.exists?(note[:ghost])
      return nil if pkmn.egg? || pkmn.isTripleFusion?
      host_shiny = pkmn.shiny? ? true : false
      copy = pkmn.clone
      copy.instance_variable_set(:@species, fused_species(pkmn, note[:ghost]))
      [:@species_data, :@type1, :@type2, :@pif_sprite, :@spriteform_head].each { |iv| copy.instance_variable_set(iv, nil) }
      copy.instance_variable_set(:@typeoverwrite, false)
      ghost_first(copy)
      copy.instance_variable_set(:@body_shiny, host_shiny)
      copy.instance_variable_set(:@head_shiny, note[:ghost_shiny])
      copy.instance_variable_set(:@shiny, host_shiny || note[:ghost_shiny])
      return copy
    rescue StandardError => e
      GhostlyPossession.log("#{pkmn.name rescue "?"}'s possessed look couldn't be made: #{e.class}: #{e.message}")
      return nil
    end

    # Possession keeps it Ghost first (his pick 2026-10-25): a Ghost whose
    # first type isn't Ghost (Sableye, Honedge, Rotom...) would give the
    # fusion its other type by KIF's fusion rules, so its first type is made
    # Ghost with KIF's own type override (TypeOverride: battles, the Summary
    # and hasType? follow it). Its second type stays the fusion's.
    def ghost_first(pkmn)
      return if pkmn.species_data.type1 == :GHOST
      if pkmn.respond_to?(:type1kuray=)
        pkmn.instance_variable_set(:@typeoverwrite, true)
        pkmn.instance_variable_set(:@type1kuray, :GHOST)
        pkmn.instance_variable_set(:@type2kuray, nil)
      else
        pkmn.instance_variable_set(:@type1, :GHOST)
      end
    end

    STAT_IVARS = [:@totalhp, :@attack, :@defense, :@spatk, :@spdef, :@speed].freeze

    # The host's own stats now (total HP first), from a copy of it as itself
    def host_stats(pkmn)
      snap = snapshot(pkmn)
      copy = pkmn.clone
      snap[:ivars].each do |iv, kept|
        if kept
          copy.instance_variable_set(iv, kept[0])
        elsif copy.instance_variable_defined?(iv)
          copy.remove_instance_variable(iv)
        end
      end
      copy.instance_variable_set(:@species_data, nil)
      copy.instance_variable_set(:@level, nil)
      copy.calc_stats
      return STAT_IVARS.map { |iv| copy.instance_variable_get(iv).to_i }
    end

    # Each stat the higher of the fusion's and the host's own
    def best_of_both(pkmn)
      return unless snapshot(pkmn)
      host = host_stats(pkmn)
      STAT_IVARS.each_with_index do |iv, i|
        pkmn.instance_variable_set(iv, host[i]) if host[i] > pkmn.instance_variable_get(iv).to_i
      end
    rescue StandardError => e
      GhostlyPossession.log("#{pkmn.name rescue "?"}'s best stats couldn't be worked out: #{e.class}: #{e.message}")
    end

    # How a possessed Pokémon is in battle, for screens (the Summary, his
    # pick: Show It Possessed): [the fusion, the stats possession raises
    # (0 total HP .. 5 Speed), the Ghost's move's slot]. Outside battle a copy
    # with its own move list is made the fusion and let go of at once, so the
    # Pokémon itself is never touched and nothing stays applied (autosaves
    # wait while anything is); in battle it's already the fusion.
    def battle_view(pkmn)
      return nil unless pkmn && !pkmn.egg? && Note.possessed?(pkmn)
      if applied?(pkmn)
        host = host_stats(pkmn)
        raised = (0...6).select { |i| pkmn.instance_variable_get(STAT_IVARS[i]).to_i > host[i] }
        return [pkmn, raised, snapshot(pkmn)[:slot]]
      end
      own = STAT_IVARS.map { |iv| pkmn.instance_variable_get(iv).to_i }
      copy = pkmn.clone
      copy.instance_variable_set(:@moves, pkmn.moves.map { |m| m.clone })
      return nil unless apply(copy)
      slot = snapshot(copy)[:slot]
      @applied.delete(copy)
      copy.instance_variable_set(:@name, pkmn.name)      # (its own name: the fusion's otherwise)
      raised = (0...6).select { |i| copy.instance_variable_get(STAT_IVARS[i]).to_i > own[i] }
      return [copy, raised, slot]
    rescue StandardError => e
      @applied.delete(copy) if copy
      GhostlyPossession.log("#{pkmn.name rescue "?"}'s battle view couldn't be made: #{e.class}: #{e.message}")
      return nil
    end

    # HP keeps the damage it had against the new total (the game's calc_stats
    # works it out against the fusion's own total, which can be smaller and
    # left it at 0); a fainted one stays at 0, a living one keeps at least 1
    def keep_damage(pkmn, total_was, hp_was)
      total = pkmn.instance_variable_get(:@totalhp).to_i
      hp = hp_was <= 0 ? 0 : (total - (total_was - hp_was)).clamp(1, [total, 1].max)
      pkmn.instance_variable_set(:@hp, hp)
    end

    # HP as the same share of the new total; a fainted one stays at 0 (KIF's
    # Nuzlocke keeps the dead at 0), a living one keeps at least 1
    def set_hp(pkmn, fainted, ratio)
      total = pkmn.totalhp
      pkmn.instance_variable_set(:@hp, fainted ? 0 : [(ratio * total).round, 1].max.clamp(1, total))
    end

    # The Ghost's move back to full PP (while applied it's on the Pokémon,
    # and healed with its own moves)
    def refill_ghost_move(pkmn)
      return if applied?(pkmn)
      note = Note.read(pkmn)
      Note.write(pkmn, note.merge(:move_pp => nil)) if note && note[:move_pp]
    rescue StandardError => e
      GhostlyPossession.log("#{pkmn.name rescue "?"}'s Ghost's move couldn't be refilled: #{e.class}: #{e.message}")
    end

    #--------------------------------------------------------------------------
    # The Pokémon while applied
    #--------------------------------------------------------------------------
    module PokemonWhileApplied
      # its own name (a Pikachu with no nickname is still "Pikachu", not the
      # fusion's name)
      def name
        snap = GhostlyPossession::Engine.snapshot(self)
        return snap ? snap[:name] : super
      end

      # its own growth: its level and EXP stay as they are
      def growth_rate
        snap = GhostlyPossession::Engine.snapshot(self)
        return snap ? GameData::GrowthRate.get(snap[:growth]) : super
      end

      # it learns its own moves by level, not the Ghost's (an alpha's extra
      # moves too, as alpha_encounters adds them: [0, move])
      def getMoveList
        snap = GhostlyPossession::Engine.snapshot(self)
        return super unless snap
        extra = instance_variable_defined?(:@alpha_moves) ? Array(@alpha_moves) : []
        return snap[:moves] + extra.map { |m| [0, m] }
      end

      # its stats the best of both, again after a level-up
      def calc_stats(*args)
        return super unless GhostlyPossession::Engine.applied?(self)
        total_was = @totalhp.to_i
        hp_was = @hp.to_i
        ret = super
        GhostlyPossession::Engine.best_of_both(self)
        GhostlyPossession::Engine.keep_damage(self, total_was, hp_was)
        return ret
      end

      # a full PP heal (a Pokémon Center, healing the team) refills the
      # Ghost's move too (outside battle its PP waits in the note)
      def heal_PP(move_index = -1)
        ret = super
        GhostlyPossession::Engine.refill_ghost_move(self) if move_index < 0
        return ret
      end

      # it doesn't evolve as the fusion
      def check_evolution_internal(*args, &block)
        return nil if GhostlyPossession::Engine.applied?(self)
        return super
      end
    end

    def boot
      ::Pokemon.prepend(PokemonWhileApplied) unless ::Pokemon.ancestors.include?(PokemonWhileApplied)
      return true
    end
  end
end
