#==============================================================================
# Ghostly Possession: no fusing or unfusing while possessed
#==============================================================================
# A possessed Pokémon can't be fused or unfused (his pick 2026-10-25: Block
# While Possessed). The game's fusing keeps copies of the two halves when
# they fuse and gives those copies back when they unfuse, so a Ghost inside
# would vanish, come back with its count reset, turn up twice, or move to
# the other half.
#
#   Fusing     Every way the game fuses asks selectFusion first (the party's
#              Splicers, the PC, fusing a newly caught Pokémon): with either
#              one possessed it says so and answers "cancelled".
#   Unfusing   Every unfuse goes through pbUnfuse (the party, the PC, the
#              Splicers on a fusion): it says so and doesn't.
#   Reversing  Still works: it's the same Pokémon, and the Ghost stays inside.
#
# Kanto Reloaded's Reloaded PC runs the game's own fusing, so the same.
#==============================================================================

module GhostlyPossession
  module Fusing
    module_function

    def possessed?(pkmn)
      return pkmn.is_a?(::Pokemon) && !pkmn.egg? && Note.possessed?(pkmn) ? true : false
    rescue StandardError
      return false
    end

    def words(pkmn, unfusing)
      return _INTL("A Ghost is inside {1}. It can't be unfused while it's possessed.", pkmn.name) if unfusing
      return _INTL("A Ghost is inside {1}. It can't be fused while it's possessed.", pkmn.name)
    end

    module Hooks
      private

      def selectFusion(pokemon, poke2, *args)
        who = [pokemon, poke2].find { |p| GhostlyPossession::Fusing.possessed?(p) }
        return super unless who
        pbMessage(GhostlyPossession::Fusing.words(who, false))
        return -1, nil
      end

      def pbUnfuse(pokemon, scene, *args)
        return super unless GhostlyPossession::Fusing.possessed?(pokemon)
        msg = GhostlyPossession::Fusing.words(pokemon, true)
        scene && scene.respond_to?(:pbDisplay) ? scene.pbDisplay(msg) : pbMessage(msg)
        return false
      end
    end

    def boot
      return true if ::Object.ancestors.include?(Hooks)
      known = [:selectFusion, :pbUnfuse].all? { |m| ::Object.private_method_defined?(m) || ::Object.method_defined?(m) }
      if known
        ::Object.prepend(Hooks)
      else
        GhostlyPossession.log("The game's fusing has changed: possessed Pokémon aren't kept from fusing")
      end
      return true
    end
  end
end
