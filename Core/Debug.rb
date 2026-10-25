#==============================================================================
# Ghostly Possession: the Debug menu
#==============================================================================
# For testing, in the game's Debug menu (KIF's Debug option): Ghostly
# Possession...
#
#   Possess on the Next Step   the next quiet step, a Ghost takes one of the
#                              team (no chance, no 500 quiet steps, even with
#                              Team Possession Off)
#   Clear Possession           every possessed Pokémon is itself again, and
#                              the next one can come at once
#   Leave After the Next Battle  the possessed one's Ghost has one battle
#                              left (then it leaves, or lingers)
#   Get a Cleanse Tag          one more in the Bag
#   Haunt the Next Wild Pokémon  the next lone wild Pokémon has a Ghost
#                              inside (no chance, any kind of battle, even
#                              with Haunted Wilds Off)
#
# With the Kanto Reloaded Debug mod, its Ghostly Possession and Spooky
# Season pages (its Pages/GhostlyPossession.rb) take these over in its
# Debug Menu, with more: each command's work is here, its words returned
# (the *_words methods), and the picks it can set:
#
#   Debug.pick          the next possession's host (personal ID), Ghost,
#                       Will and Stay (nil: rolled)
#   Debug.wild_ghost    the next haunted wild one's Ghost (nil: rolled)
#   Debug.night_ghost   the next route or cave encounter is a Ghost (any
#                       time, no chance: the Spooky Season's Night Ghosts)
#   Debug.halloween     it's 31 October for the Witchy Hat
#   Debug.track         tonight's haunted track (nil: the night's own)
#==============================================================================

module GhostlyPossession
  module Debug
    module_function

    def forced?
      return @forced ? true : false
    end

    def forced=(value)
      @forced = value ? true : false
      @pick = nil unless @forced
    end

    def wild_forced?
      return @wild_forced ? true : false
    end

    def wild_forced=(value)
      @wild_forced = value ? true : false
      @wild_ghost = nil unless @wild_forced
    end

    # {:host => personal ID, :ghost, :will, :stay}, each nil for rolled
    def pick
      return @pick
    end

    def wild_ghost
      return @wild_ghost
    end

    def night_ghost?
      return @night_ghost ? true : false
    end

    def night_ghost=(value)
      @night_ghost = value ? true : false
    end

    def halloween?
      return @halloween ? true : false
    end

    def halloween=(value)
      @halloween = value ? true : false
    end

    def track
      return @track
    end

    def track=(name)
      @track = name
    end

    #--------------------------------------------------------------------------
    # The commands (each one's words returned)
    #--------------------------------------------------------------------------
    def haunt_next
      pbMessage(haunt_words)
    end

    def haunt_words(ghost = nil)
      self.wild_forced = true
      @wild_ghost = ghost
      return _INTL("The next lone wild Pokémon will have a Ghost inside.") unless ghost
      return _INTL("The next lone wild Pokémon will have a {1} inside (else a Ghost that fits).", species_name(ghost))
    end

    def possess_next
      pbMessage(possess_words)
    end

    # pick: {:host, :ghost, :will, :stay} (see Debug.pick)
    def possess_words(pick = nil)
      return _INTL("One of your Pokémon is possessed already. Clear it first.") if Team.possessed_somewhere?
      ghost = pick && pick[:ghost]
      hosts = Ghosts.hosts(nil, ghost)
      hosts = hosts.select { |p| Note.pid_of(p) == pick[:host] } if pick && pick[:host]
      if hosts.empty?
        return _INTL("None of your team can be possessed (Ghosts, Eggs and fainted Pokémon can't).") unless pick && (pick[:host] || ghost)
        return _INTL("That one can't take a {1}: There's no such fusion. Pick another.", species_name(ghost)) if ghost
        return _INTL("That one can't be possessed (Ghosts, Eggs and fainted Pokémon can't).")
      end
      self.forced = true
      @pick = pick && pick.values.any? ? pick : nil
      return _INTL("The next step, a Ghost will possess one of your team.") unless @pick
      who = pick[:host] ? hosts.first.name : _INTL("one of your team")
      return _INTL("The next step, a {1} will possess {2}.", ghost ? species_name(ghost) : _INTL("Ghost"), who)
    end

    def leave_soon
      pbMessage(leave_words)
    end

    def leave_words
      pkmn = Team.owned.find { |p| Note.possessed?(p) }
      return _INTL("None of your Pokémon is possessed.") unless pkmn
      Note.write(pkmn, Note.read(pkmn).merge(:battles_left => 1))
      return _INTL("{1}'s Ghost leaves after its next battle.", pkmn.name)
    end

    def give_tag
      pbMessage(tag_words)
    end

    def tag_words(count = 1)
      unless $PokemonBag && $PokemonBag.pbStoreItem(CleanseTag::ITEM, count)
        return _INTL("There's no room in the Bag for a Cleanse Tag.")
      end
      return _INTL("You got a Cleanse Tag. You have {1} now.", CleanseTag.count) if count == 1
      return _INTL("You got {1} Cleanse Tags. You have {2} now.", count, CleanseTag.count)
    end

    # The clock to an hour (the game's own UnrealTime.advance_to), the map's tone at once
    def time_to(hour)
      pbMessage(time_words(hour))
    end

    def time_words(hour, minute = 0)
      return _INTL("The game's clock can't be moved here.") unless defined?(::UnrealTime) && ::UnrealTime.respond_to?(:advance_to)
      ::UnrealTime.advance_to(hour, minute)
      Season.refresh if defined?(Season)
      return _INTL("It's {1}:{2} now.", hour, format("%02d", minute))
    end

    def clear
      pbMessage(clear_words)
    end

    def clear_words
      count = 0
      Team.owned.each do |pkmn|
        next unless Note.possessed?(pkmn)
        Note.clear(pkmn)
        count += 1
      end
      Shared.possessed_id = nil
      Shared.quiet_steps = Team::COOLDOWN
      self.forced = false
      self.wild_forced = false
      return _INTL("{1} possessed Pokémon cleared.", count)
    end

    def species_name(species)
      return (::GameData::Species.get(species).name rescue species.to_s)
    end

    def boot
      return true unless defined?(::DebugMenuCommands)
      ::DebugMenuCommands.register("ghostly_possession", {
        "parent"      => "main",
        "name"        => _INTL("Ghostly Possession..."),
        "description" => _INTL("Make a Ghost possess one of your team or a wild Pokémon, get a Cleanse Tag, clear a possession, or move the clock for the Spooky Season.")
      })
      ::DebugMenuCommands.register("ghostly_possession_next", {
        "parent"      => "ghostly_possession",
        "name"        => _INTL("Possess on the Next Step"),
        "description" => _INTL("The next quiet step, a Ghost possesses one of your team (no chance, no wait)."),
        "effect"      => proc { GhostlyPossession::Debug.possess_next }
      })
      ::DebugMenuCommands.register("ghostly_possession_leave", {
        "parent"      => "ghostly_possession",
        "name"        => _INTL("Leave After the Next Battle"),
        "description" => _INTL("The possessed Pokémon's Ghost has one battle left: then it leaves, or lingers to fight."),
        "effect"      => proc { GhostlyPossession::Debug.leave_soon }
      })
      ::DebugMenuCommands.register("ghostly_possession_tag", {
        "parent"      => "ghostly_possession",
        "name"        => _INTL("Get a Cleanse Tag"),
        "description" => _INTL("Put a Cleanse Tag in the Bag, to cast a Ghost out."),
        "effect"      => proc { GhostlyPossession::Debug.give_tag }
      })
      ::DebugMenuCommands.register("ghostly_possession_wild", {
        "parent"      => "ghostly_possession",
        "name"        => _INTL("Haunt the Next Wild Pokémon"),
        "description" => _INTL("The next lone wild Pokémon you battle has a Ghost inside (no chance)."),
        "effect"      => proc { GhostlyPossession::Debug.haunt_next }
      })
      ::DebugMenuCommands.register("ghostly_possession_clear", {
        "parent"      => "ghostly_possession",
        "name"        => _INTL("Clear Possession"),
        "description" => _INTL("Every possessed Pokémon is itself again, and the next possession can come at once."),
        "effect"      => proc { GhostlyPossession::Debug.clear }
      })
      ::DebugMenuCommands.register("ghostly_possession_night", {
        "parent"      => "ghostly_possession",
        "name"        => _INTL("Night Now"),
        "description" => _INTL("The clock to 11 pm: the Spooky Season's night, wisps and town lights."),
        "effect"      => proc { GhostlyPossession::Debug.time_to(23) }
      })
      ::DebugMenuCommands.register("ghostly_possession_evening", {
        "parent"      => "ghostly_possession",
        "name"        => _INTL("Evening Now"),
        "description" => _INTL("The clock to 8 pm, to watch the night come in."),
        "effect"      => proc { GhostlyPossession::Debug.time_to(20) }
      })
      ::DebugMenuCommands.register("ghostly_possession_morning", {
        "parent"      => "ghostly_possession",
        "name"        => _INTL("Morning Now"),
        "description" => _INTL("The clock to 7 am: day again."),
        "effect"      => proc { GhostlyPossession::Debug.time_to(7) }
      })
      return true
    end
  end
end
