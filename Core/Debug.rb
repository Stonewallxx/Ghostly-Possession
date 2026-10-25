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
#==============================================================================

module GhostlyPossession
  module Debug
    module_function

    def forced?
      return @forced ? true : false
    end

    def forced=(value)
      @forced = value ? true : false
    end

    def wild_forced?
      return @wild_forced ? true : false
    end

    def wild_forced=(value)
      @wild_forced = value ? true : false
    end

    def haunt_next
      self.wild_forced = true
      pbMessage(_INTL("The next lone wild Pokémon will have a Ghost inside."))
    end

    def possess_next
      if Team.possessed_somewhere?
        pbMessage(_INTL("One of your Pokémon is possessed already. Clear it first."))
      elsif Ghosts.hosts.empty?
        pbMessage(_INTL("None of your team can be possessed (Ghosts, Eggs and fainted Pokémon can't)."))
      else
        self.forced = true
        pbMessage(_INTL("The next step, a Ghost will possess one of your team."))
      end
    end

    def leave_soon
      pkmn = Team.owned.find { |p| Note.possessed?(p) }
      unless pkmn
        pbMessage(_INTL("None of your Pokémon is possessed."))
        return
      end
      Note.write(pkmn, Note.read(pkmn).merge(:battles_left => 1))
      pbMessage(_INTL("{1}'s Ghost leaves after its next battle.", pkmn.name))
    end

    def give_tag
      unless $PokemonBag && $PokemonBag.pbStoreItem(CleanseTag::ITEM, 1)
        pbMessage(_INTL("There's no room in the Bag for a Cleanse Tag."))
        return
      end
      pbMessage(_INTL("You got a Cleanse Tag. You have {1} now.", CleanseTag.count))
    end

    # The clock to an hour (the game's own UnrealTime.advance_to), the map's tone at once
    def time_to(hour)
      unless defined?(::UnrealTime) && ::UnrealTime.respond_to?(:advance_to)
        pbMessage(_INTL("The game's clock can't be moved here."))
        return
      end
      ::UnrealTime.advance_to(hour)
      Season.refresh if defined?(Season)
      pbMessage(_INTL("It's {1}:00 now.", hour))
    end

    def clear
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
      pbMessage(_INTL("{1} possessed Pokémon cleared.", count))
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
