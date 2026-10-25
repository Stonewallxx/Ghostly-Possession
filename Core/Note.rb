#==============================================================================
# Ghostly Possession: the note
#==============================================================================
# A possessed Pokémon carries a note: which Ghost is in it and how it
# behaves. The Pokémon itself stays as it is outside battle; each battle
# turns it into the fusion and back (Only in Battle, his pick 2026-10-25).
# The note is plain data only (a Hash of Symbols, Integers, true/false and
# nil), so saves, the PC, the Transfer Box and trades never meet a class of
# this mod, and a save still loads with the mod removed.
#
#   :ghost         the Ghost's species (Symbol)
#   :ghost_shiny   true / false
#   :will          0 Calm, 1 Normal, 2 Wild (how often it acts on its own)
#   :stay          0 Short, 1 Normal, 2 Long (how long it stays)
#   :battles_left  battles before it leaves by itself
#   :slot          the move slot the Ghost's move takes in battle
#   :move          the Ghost's move (Symbol)
#   :move_pp       that move's PP left, or nil while it's full
#   :pid           the possessed Pokémon's personal ID (set by write)
#   :wild          true on a wild Pokémon's (Haunted Wilds); nil on yours
#
#   GhostlyPossession::Note.read(pkmn)          the note, or nil
#   GhostlyPossession::Note.write(pkmn, note)   checked, then kept (a copy)
#   GhostlyPossession::Note.clear(pkmn)
#
# A copy of a Pokémon (Pokemon#clone) shares its note's Hash, so a note is
# never changed in place: write keeps a new one. A copy with its own
# personal ID (Shedinja, made when Nincada evolves) isn't possessed: its
# note is the other Pokémon's, and is dropped when read.
#
# What's shared sits on $PokemonGlobal the same way (Shared): who is
# possessed (one Pokémon at a time, by its personal ID), the steps since
# the last possession ended, whether the Channeler has been met, and what
# waits for the map after a battle (a Ghost's own battle, a Possessed! card).
#==============================================================================

module GhostlyPossession
  module Note
    IVAR = :@ghostly_possession
    WILLS = ["Calm", "Normal", "Wild"].freeze
    STAYS = ["Short", "Normal", "Long"].freeze
    # key => what it may hold
    FIELDS = {
      :ghost        => [Symbol],
      :ghost_shiny  => [TrueClass, FalseClass],
      :will         => [Integer],
      :stay         => [Integer],
      :battles_left => [Integer],
      :slot         => [Integer],
      :move         => [Symbol],
      :move_pp      => [Integer, NilClass],
      :pid          => [Integer],
      :wild         => [TrueClass, NilClass]
    }.freeze

    module_function

    # The note, or nil when the Pokémon isn't possessed. A damaged note, or
    # one another Pokémon's (a copy's), is dropped from this Pokémon.
    def read(pkmn)
      return nil unless pkmn && pkmn.instance_variable_defined?(IVAR)
      note = pkmn.instance_variable_get(IVAR)
      return note if valid?(note) && note[:pid] == pid_of(pkmn)
      GhostlyPossession.log("A possession note that wasn't #{pkmn.name rescue "?"}'s was dropped") unless note.nil?
      pkmn.remove_instance_variable(IVAR)
      return nil
    rescue StandardError
      return nil
    end

    def possessed?(pkmn)
      return !read(pkmn).nil?
    end

    # A wild Pokémon's note (Haunted Wilds)
    def wild?(pkmn)
      note = read(pkmn)
      return note && note[:wild] ? true : false
    end

    # Keeps a new copy of the note, made this Pokémon's; false (and nothing
    # kept) when it isn't one.
    def write(pkmn, note)
      return false unless pkmn && note.is_a?(Hash)
      note = note.merge(:pid => pid_of(pkmn))
      return false unless valid?(note)
      # (:wild only on a wild Pokémon's: your own notes keep their shape)
      pkmn.instance_variable_set(IVAR, FIELDS.keys.each_with_object({}) { |k, h| h[k] = note[k] unless k == :wild && !note[k] })
      return true
    end

    def pid_of(pkmn)
      return pkmn.respond_to?(:personalID) ? pkmn.personalID.to_i : 0
    end

    def clear(pkmn)
      pkmn.remove_instance_variable(IVAR) if pkmn && pkmn.instance_variable_defined?(IVAR)
    end

    def valid?(note)
      return false unless note.is_a?(Hash)
      return false unless FIELDS.all? { |k, kinds| kinds.any? { |kind| note[k].is_a?(kind) } }
      return false unless note[:will].between?(0, WILLS.length - 1) && note[:stay].between?(0, STAYS.length - 1)
      return note[:battles_left] >= 0 && note[:slot].between?(0, 3)
    end
  end

  #----------------------------------------------------------------------------
  # What's shared (on $PokemonGlobal, saved with it)
  #----------------------------------------------------------------------------
  module Shared
    IVAR = :@ghostly_possession
    DEFAULTS = { :possessed => nil, :quiet_steps => 0, :channeler => false, :waiting_ghost => nil, :waiting_leapt => nil }.freeze

    module_function

    def data
      g = $PokemonGlobal
      return DEFAULTS.dup unless g
      d = g.instance_variable_defined?(IVAR) ? g.instance_variable_get(IVAR) : nil
      unless d.is_a?(Hash)
        d = DEFAULTS.dup
        g.instance_variable_set(IVAR, d)
      end
      DEFAULTS.each { |k, v| d[k] = v unless d.has_key?(k) }
      return d
    end

    # The personal ID of the possessed Pokémon, or nil.
    def possessed_id
      id = data[:possessed]
      return id.is_a?(Integer) ? id : nil
    end

    def possessed_id=(id)
      data[:possessed] = id.is_a?(Integer) ? id : nil
    end

    def quiet_steps
      return data[:quiet_steps].to_i
    end

    def quiet_steps=(steps)
      data[:quiet_steps] = steps.to_i
    end

    def channeler_met?
      return data[:channeler] ? true : false
    end

    def channeler_met!
      data[:channeler] = true
    end

    # What waits for the map after a battle (Leave.rb), kept here so a save
    # and reload in between doesn't lose it: a cast-out Ghost's own battle
    # [note, level], and the Possessed! card for a Ghost that leaped
    # [personal ID, the wild one's name]. Plain data, cleared once shown.
    def waiting_ghost
      w = data[:waiting_ghost]
      return w.is_a?(Array) && w.length == 2 && w[0].is_a?(Hash) ? w : nil
    end

    def waiting_ghost=(w)
      data[:waiting_ghost] = w
    end

    def waiting_leapt
      w = data[:waiting_leapt]
      return w.is_a?(Array) && w.length == 2 && w[0].is_a?(Integer) ? w : nil
    end

    def waiting_leapt=(w)
      data[:waiting_leapt] = w
    end
  end
end
