#==============================================================================
# Ghostly Possession: the Channeler
#==============================================================================
# A Channeler in Lavender Town's Volunteer House (Mr. Fuji's; map 418), free
# (his picks 2026-10-24). She stands in the corner by the cribs (13, 10),
# facing left: talk to her from (12, 10) or (13, 9). Added with KIF's map
# patches as the map loads (KIF::MapPatches): the map's file isn't changed,
# and a save made there gets her after the map is next loaded. Her talk is
# the game's own messages, in either look.
#
#   With a possessed teammate: "I sense a Gastly inside your Pikachu...
#   Shall I set it free?" Yes casts it out (the Cast-Out card, then its own
#   battle).
#   The first time, she gives a Cleanse Tag.
#
# The event only calls in if Ghostly Possession is there (defined?): maps
# are kept in saves, so a save still loads with the mod removed.
#==============================================================================

module GhostlyPossession
  module Channeler
    MAP = 418
    X = 13
    Y = 10
    SPRITE = "BW (40)"             # KIF's Channeler

    module_function

    def talk
      first = !Shared.channeler_met?
      pkmn = CleanseTag.possessed_in_party
      if pkmn
        note = Note.read(pkmn)
        if pbConfirmMessage(_INTL("I sense a {1} inside your {2}...\\nShall I set it free?", UI.ghost_name(note), pkmn.name))
          Leave.cast_out(pkmn, :channeler)
          give_tag(true) if first
        else
          pbMessage(_INTL("Come back if you change your mind."))
          give_tag(true) if first
        end
      elsif Team.possessed_somewhere?
        pbMessage(_INTL("I sense a spirit clinging to one of your Pokémon...\\nBut it isn't here with you."))
        give_tag(false) if first
      else
        pbMessage(_INTL("Spirits drift through this town...\\nIf one ever takes hold of your Pokémon, come to me."))
        give_tag(false) if first
      end
    rescue StandardError => e
      GhostlyPossession.log("The Channeler's talk failed: #{e.class}: #{e.message}")
    end

    def give_tag(too)
      Shared.channeler_met!
      return unless CleanseTag.exists?
      pbMessage(too ? _INTL("Take this Cleanse Tag, too.\\nHold it up to a possessed Pokémon to cast it out.") :
                      _INTL("Take this Cleanse Tag.\\nHold it up to a possessed Pokémon to cast it out."))
      pbReceiveItem(CleanseTag::ITEM)
    end

    # The event, as the map loads
    def add(map)
      return if map.events.values.any? { |ev| ev.name == "GhostlyChanneler" }
      id = ::KIF::MapPatches.free_id(map, 30)
      map.events[id] = ::KIF::MapPatches.event(id, {
        :x => X, :y => Y, :name => "GhostlyChanneler",
        :pages => [{
          :cond => {}, :gfx => { :character_name => SPRITE, :direction => 4 }, :trigger => 0,
          :list => [[355, 0, ["GhostlyPossession::Channeler.talk if defined?(GhostlyPossession)"]], [0, 0, []]]
        }]
      })
    end

    def boot
      return true unless defined?(::KIF::MapPatches)
      return true if @booted
      ::KIF::MapPatches.add(MAP, "Ghostly Possession: the Channeler") { |map| GhostlyPossession::Channeler.add(map) }
      @booted = true
      return true
    end
  end
end
