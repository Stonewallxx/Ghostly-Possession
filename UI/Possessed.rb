#==============================================================================
# Ghostly Possession: telling the player
#==============================================================================
# One place for what's said, in either look: Kanto Reloaded's card when
# Kanto Reloaded is there (checked as it shows), else the game's own windows.
#
#   GhostlyPossession::UI.possessed(host)   the moment and Possessed!
#   GhostlyPossession::UI.possessed(host, leapt_from)  after the Leap: the
#                                           card only, telling how
#   GhostlyPossession::UI.left(pkmn, note, look, lingers)
#                                           it leaves: The Gastly Left, or
#                                           The Gastly Lingers! (gold)
#   GhostlyPossession::UI.cast_out(pkmn, note, look, how)
#                                           Cast Out! (gold): by the Cleanse
#                                           Tag, or the Channeler
#   (look: the fusion's look, made before the note was cleared)
#==============================================================================

module GhostlyPossession
  module UI
    module_function

    def kr?
      return Card.ready?
    end

    # Possessed!: the chill and the Ghost drifting in, then the card. After
    # the Leap (leapt_from: the wild one it was in), the card only, telling
    # how (Mid-Battle, Card After, his pick 2026-10-24).
    def possessed(host, leapt_from = nil)
      note = Note.read(host)
      return unless note
      show = proc do
        if kr?
          ghost = ghost_name(note)
          body = if leapt_from
                   _INTL("When {1} fainted, its angry {2} leaped into {3}. It's stronger for now, but the {2} acts on its own at times.",
                         leapt_from, ghost, host.name)
                 else
                   _INTL("{1} {2} has possessed {3}. It's stronger for now, but the {2} acts on its own at times.",
                         article(ghost), ghost, host.name)
                 end
          Card.show(:title => _INTL("Possessed!"), :rgb => Card::GHOST_RGB, :buttons => [_INTL("OK")],
                    :before => host, :after => Engine.display(host), :ghost => ghost_pokemon(note, host.level),
                    :body => body, :note => _INTL("It leaves after a while. A Cleanse Tag casts it out."))
        else
          Alone.possessed(host, note, leapt_from)
        end
      end
      leapt_from ? show.call : Moment.possessed(note, &show)
    rescue StandardError => e
      GhostlyPossession.log("Possessed! couldn't be shown: #{e.class}: #{e.message}")
    end

    GOLD = [240, 200, 80].freeze

    # It leaves by itself: the moment, then what happened
    def left(pkmn, note, look, lingers)
      ghost = ghost_name(note)
      can_catch = GhostBattle.catchable?(note)
      Moment.leaving(note, lingers) do
        if kr? && lingers
          body = can_catch ? _INTL("It drifted out of {1}, but it's still here, and it wants to fight. Here's your chance to catch it!", pkmn.name) :
                             _INTL("It drifted out of {1}, but it's still here, and it wants to fight.", pkmn.name)
          Card.show(:title => _INTL("The {1} Lingers!", ghost), :rgb => GOLD, :buttons => [_INTL("Battle!")],
                    :before => look, :after => pkmn, :ghost => ghost_pokemon(note, pkmn.level), :changed => :before,
                    :pills => false, :before_name => pkmn.name, :body => body)
        elsif kr?
          Card.show(:title => _INTL("The {1} Left", ghost), :rgb => Card::GHOST_RGB, :buttons => [_INTL("OK")],
                    :before => look, :after => pkmn, :changed => :before, :pills => false, :before_name => pkmn.name,
                    :body => _INTL("It drifted out of {1} and faded away. {1} is itself again.", pkmn.name))
        elsif lingers
          pbMessage(_INTL("The {1} drifted out of {2}...\\nIt wants to fight!", ghost, pkmn.name))
        else
          pbMessage(_INTL("The {1} drifted out of {2} and faded away.", ghost, pkmn.name))
        end
      end
    rescue StandardError => e
      GhostlyPossession.log("It Leaves couldn't be shown: #{e.class}: #{e.message}")
    end

    # Cast out (how: :bag / :popup, a Cleanse Tag; :channeler). In KIF's
    # Nuzlocke the Ghost only fights (Leave.rb).
    def cast_out(pkmn, note, look, how)
      ghost = ghost_name(note)
      by_tag = how != :channeler
      can_catch = GhostBattle.catchable?(note)
      Moment.cast_out(note) do
        if kr?
          body = if by_tag
                   can_catch ? _INTL("The Cleanse Tag drove the {1} out of {2}! It's angry, and it's yours to catch.", ghost, pkmn.name) :
                               _INTL("The Cleanse Tag drove the {1} out of {2}! It's angry, and it wants to fight.", ghost, pkmn.name)
                 else
                   can_catch ? _INTL("The Channeler drove the {1} out of {2}! It's angry, and it's yours to catch.", ghost, pkmn.name) :
                               _INTL("The Channeler drove the {1} out of {2}! It's angry, and it wants to fight.", ghost, pkmn.name)
                 end
          Card.show(:title => _INTL("Cast Out!"), :rgb => GOLD, :buttons => [_INTL("Battle!")],
                    :before => look, :after => pkmn, :changed => :before, :pills => false, :before_name => pkmn.name,
                    :ghost => by_tag ? nil : ghost_pokemon(note, pkmn.level),
                    :middle => by_tag ? CleanseTag.icon_path : nil, :body => body)
        elsif by_tag
          pbMessage(can_catch ? _INTL("The Cleanse Tag drove the {1} out of {2}!\\nIt's angry, and it's yours to catch!", ghost, pkmn.name) :
                                _INTL("The Cleanse Tag drove the {1} out of {2}!\\nIt's angry, and it wants to fight!", ghost, pkmn.name))
        else
          pbMessage(can_catch ? _INTL("The {1} was driven out of {2}!\\nIt's angry, and it's yours to catch!", ghost, pkmn.name) :
                                _INTL("The {1} was driven out of {2}!\\nIt's angry, and it wants to fight!", ghost, pkmn.name))
        end
      end
    rescue StandardError => e
      GhostlyPossession.log("Cast Out! couldn't be shown: #{e.class}: #{e.message}")
    end

    # The Ghost's name ("Gastly")
    def ghost_name(note)
      return ::GameData::Species.get(note[:ghost]).name
    rescue StandardError
      return note[:ghost].to_s.capitalize
    end

    def article(name)
      return name.to_s =~ /\A[AEIOU]/i ? _INTL("An") : _INTL("A")
    end

    # The Ghost as a Pokémon, for its picture
    def ghost_pokemon(note, level)
      pkmn = ::Pokemon.new(note[:ghost], [level.to_i, 1].max)
      pkmn.shiny = note[:ghost_shiny] ? true : false
      return pkmn
    rescue StandardError
      return nil
    end
  end
end
