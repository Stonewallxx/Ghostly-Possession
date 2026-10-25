#==============================================================================
# Ghostly Possession: leaving and casting out
#==============================================================================
# A Ghost stays for a number of battles (its Stay), then leaves by itself;
# a Cleanse Tag or the Channeler casts it out sooner (his picks 2026-10-24).
#
#   Battles count down: after each battle a possessed teammate took part in
#   (sent out at least once), one fewer. In the PC or the Day Care nothing
#   counts.
#   It leaves: back on the map, once nothing else is going on, the Ghost
#   drifts out (A Card After the Battle): mostly it fades away (The Gastly
#   Left); 20% of the time it lingers and wants to fight (The Gastly
#   Lingers!, then its own wild battle).
#   Cast out: the cold flash and the Ghost torn out, the Cast-Out card, and
#   always its own wild battle (to catch it; in KIF's Nuzlocke only to beat
#   it). From the Bag (the Cleanse Tag closes the menus
#   and acts on the map), from the Possession popup (the menus close
#   themselves first), or from the Channeler.
#
#   GhostlyPossession::Leave.count(battle)          after a battle (Battle.rb)
#   GhostlyPossession::Leave.request(pkmn)          Cast It Out from the popup
#   GhostlyPossession::Leave.cast_out(pkmn, how)    :bag / :popup / :channeler
#   GhostlyPossession::GhostBattle.start(note, level)
#   GhostlyPossession::Leave.queue_ghost(note, level)  a wild one's Ghost cast
#                                                   out in battle: its own
#                                                   battle once on the map
#   GhostlyPossession::Leave.queue_leapt(host, from)   a wild one's Ghost
#                                                   leaped into yours: the
#                                                   Possessed! card on the map
#   (both wait in the saved data, Shared, so a save and reload between the
#   battle and the map doesn't lose them)
#
# Afterwards the Pokémon is itself again (its own move back too: the Ghost's
# move only ever sat in its slot during battles), nobody is possessed, and
# the 500 quiet steps start over.
#==============================================================================

module GhostlyPossession
  module Leave
    LINGER = 20                    # % a Ghost that leaves by itself stays to fight

    module_function

    # After a battle: each possessed teammate that took part has a battle fewer
    def count(battle)
      return unless Battle.eligible?(battle)
      party = $Trainer ? $Trainer.party : []
      leapt = battle.instance_variable_get(:@gp_leapt)   # possessed in this battle (the Leap): not counted
      Array(battle.pbParty(0)).each do |pkmn|
        next unless pkmn && Battle.sent_out?(battle, pkmn) && party.any? { |p| p.equal?(pkmn) } && !pkmn.equal?(leapt)
        note = Note.read(pkmn)
        next unless note
        Note.write(pkmn, note.merge(:battles_left => [note[:battles_left] - 1, 0].max))
        GhostlyPossession.log("#{pkmn.name}'s #{note[:ghost]}: #{[note[:battles_left] - 1, 0].max} battles left")
      end
    end

    # A teammate whose Ghost has no battles left
    def due
      return nil unless Shared.possessed_id && $Trainer
      return $Trainer.party.find { |p| p && (n = Note.read(p)) && n[:battles_left] <= 0 }
    end

    # Cast It Out from the Possession popup: the menus close themselves,
    # then it happens on the map
    def request(pkmn)
      @pending = [Note.pid_of(pkmn), :popup]
    end

    # A wild one's Ghost cast out in battle (WildBattle.rb): its own battle,
    # on the map, once the battle's over
    def queue_ghost(note, level)
      Shared.waiting_ghost = [note.dup, level.to_i]
    end

    # A wild one's Ghost leaped into one of yours (WildBattle.rb): the
    # Possessed! card, on the map, once the battle's over
    def queue_leapt(host, from)
      Shared.waiting_leapt = [Note.pid_of(host), from.to_s]
    end

    # (never in a battle that started before the map's turn came: its party
    # screens work as ever, and the cast-out waits for the map after it)
    def closing?
      return false if $game_temp && $game_temp.in_battle
      return @pending ? true : false
    end

    #--------------------------------------------------------------------------
    # On the map (Events.onMapUpdate): only on a full update with nothing
    # else going on (the game fires the event from menus and messages too)
    #--------------------------------------------------------------------------
    def update
      scrub_wild
      leapt = Shared.waiting_leapt
      ghost = Shared.waiting_ghost
      return unless @pending || ghost || leapt || (Shared.possessed_id && due)
      return unless ready?
      if leapt
        pid, from = leapt
        Shared.waiting_leapt = nil
        host = $Trainer.party.find { |p| p && Note.pid_of(p) == pid && Note.possessed?(p) }
        UI.possessed(host, from) if host
        return
      end
      if ghost
        note, level = ghost
        Shared.waiting_ghost = nil
        GhostBattle.start(note, level, true)
        return
      end
      if @pending
        pid, how = @pending
        @pending = nil
        pkmn = $Trainer.party.find { |p| p && Note.pid_of(p) == pid && Note.possessed?(p) }
        cast_out(pkmn, how) if pkmn
        return
      end
      pkmn = due
      leave(pkmn) if pkmn
    rescue StandardError => e
      @pending = nil
      Shared.waiting_ghost = nil
      Shared.waiting_leapt = nil
      GhostlyPossession.log("Leaving or casting out failed: #{e.class}: #{e.message}")
    end

    # A wild Pokémon's note never stays on one of yours (Keep Which? clears
    # it; this catches one that slipped through)
    def scrub_wild
      return unless $Trainer
      $Trainer.party.each do |pkmn|
        next unless pkmn && Note.wild?(pkmn)
        Note.clear(pkmn)
        GhostlyPossession.log("A wild Pokémon's possession note was cleared from #{pkmn.name}")
      end
    end

    def ready?
      return false unless $scene.is_a?(::Scene_Map) && $game_temp && $game_player && $game_map && $Trainer
      return false if $PokemonTemp && $PokemonTemp.respond_to?(:miniupdate) && $PokemonTemp.miniupdate
      t = $game_temp
      return false if t.in_menu || t.in_battle || t.message_window_showing || t.player_transferring
      return false if pbIsFaded? || pbMapInterpreterRunning? || $game_player.moving?
      return !$game_map.events.values.any? { |e| e.starting }
    end

    #--------------------------------------------------------------------------
    # Leaving by itself, casting out
    #--------------------------------------------------------------------------
    def leave(pkmn)
      note = Note.read(pkmn)
      return false unless note
      lingers = rand(100) < LINGER
      look = Engine.display(pkmn)
      free(pkmn)
      GhostlyPossession.log("The #{note[:ghost]} left #{pkmn.name}#{lingers ? " and lingers" : ""}")
      UI.left(pkmn, note, look, lingers)
      GhostBattle.start(note, pkmn.level) if lingers
      return true
    end

    # how: :bag (the Bag uses the tag up), :popup (one tag used here),
    # :channeler (free)
    def cast_out(pkmn, how)
      note = Note.read(pkmn)
      return false unless note
      if how == :popup
        return false unless CleanseTag.count > 0
        $PokemonBag.pbDeleteItem(CleanseTag::ITEM)
      end
      look = Engine.display(pkmn)
      free(pkmn)
      GhostlyPossession.log("The #{note[:ghost]} was cast out of #{pkmn.name} (#{how})")
      UI.cast_out(pkmn, note, look, how)
      GhostBattle.start(note, pkmn.level)
      return true
    end

    # itself again, nobody possessed, the quiet steps start over
    def free(pkmn)
      Note.clear(pkmn)
      Shared.possessed_id = nil
      Shared.quiet_steps = 0
    end

    #--------------------------------------------------------------------------
    # The menus closing themselves (after Cast It Out in the popup)
    #--------------------------------------------------------------------------
    module PartyClose
      def pbChoosePokemon(*args)
        return -1 if GhostlyPossession::Leave.closing?
        return super
      end
    end

    module KRPartyClose
      def kr_choose_pokemon(*args)
        return -1 if GhostlyPossession::Leave.closing?
        return super
      end
    end

    module MenuClose
      def pbShowCommands(*args)
        return -1 if GhostlyPossession::Leave.closing?
        return super
      end
    end

    def boot
      ::PokemonParty_Scene.prepend(PartyClose) if defined?(::PokemonParty_Scene) && !::PokemonParty_Scene.ancestors.include?(PartyClose)
      if defined?(::Reloaded::PartyScene) && ::Reloaded::PartyScene.method_defined?(:kr_choose_pokemon) &&
         !::Reloaded::PartyScene.ancestors.include?(KRPartyClose)
        ::Reloaded::PartyScene.prepend(KRPartyClose)
      end
      if defined?(::PokemonPauseMenu_Scene) && !::PokemonPauseMenu_Scene.ancestors.include?(MenuClose)
        ::PokemonPauseMenu_Scene.prepend(MenuClose)
      end
      unless @booted
        ::Events.onMapUpdate += proc { |_sender, _e| GhostlyPossession::Leave.update }
        @booted = true
      end
      return true
    end
  end

  #----------------------------------------------------------------------------
  # The Ghost's own battle (after it's cast out, or lingers)
  #----------------------------------------------------------------------------
  module GhostBattle
    module_function

    def active?
      return @active ? true : false
    end

    # In KIF's Nuzlocke the Ghost can't be caught (his call 2026-10-24): it
    # still fights, Balls are blocked, and the route's encounter isn't used
    # up. A shiny one follows KIF's Shiny Clause.
    def nuzlocke?
      return defined?(::KIF::Nuzlocke) && ::KIF::Nuzlocke.respond_to?(:on?) && ::KIF::Nuzlocke.on? ? true : false
    rescue StandardError
      return false
    end

    def shiny_clause?
      return $PokemonSystem.respond_to?(:ch_nz_shiny) && $PokemonSystem.ch_nz_shiny == 1
    end

    def catchable?(note)
      return true unless nuzlocke?
      return note && note[:ghost_shiny] && shiny_clause? ? true : false
    end

    # A wild one's Ghost that came back after it was cast out in battle (its
    # note, while its battle runs): the battle's intro says so (WildBattle.rb)
    def came_back
      return @came_back
    end

    # The Ghost at the host's level, wild (never possessed itself)
    def start(note, level, came_back = false)
      pkmn = ::Pokemon.new(note[:ghost], [level.to_i, 1].max)
      pkmn.shiny = note[:ghost_shiny] ? true : false
      @active = true
      @came_back = came_back ? note : nil
      begin
        return pbWildBattleCore(pkmn)
      ensure
        @active = false
        @came_back = nil
      end
    end

    # KIF's verdict for the Ghost's battle: :free (the Shiny Clause: catchable,
    # the route kept) or :ghost (not catchable, the route kept). A possessed
    # wild Pokémon's (Keep Which?): the Dupes Clause lets it be caught when
    # the Ghost inside is a new line.
    module NuzlockeJudge
      def judge(*args)
        ret = super
        return ret unless ret.is_a?(Array)
        return [ret[0], ret[1] == :free ? :free : :ghost] if GhostlyPossession::GhostBattle.active?
        return [ret[0], :first] if ret[1] == :dupe && GhostlyPossession::WildBattle.new_line_inside?(args[0])
        return ret
      end
    end

    # Balls are blocked in a :ghost battle, with KIF's kind of message
    module NuzlockeBalls
      def triggerCanUseInBattle(item, pkmn, battler, move, firstAction, battle, scene, showMessages = true, *rest)
        if battle.respond_to?(:kif_nz) && battle.kif_nz == :ghost && ::GameData::Item.get(item).is_poke_ball?
          if showMessages
            foe = (battle.pbParty(1).compact.first rescue nil)
            scene.pbDisplay(_INTL("Nuzlocke: The {1} can't be caught.", foe ? foe.name : _INTL("Ghost")))
          end
          return false
        end
        return super
      end
    end

    def boot
      if defined?(::KIF::Nuzlocke) && ::KIF::Nuzlocke.respond_to?(:judge) &&
         !::KIF::Nuzlocke.singleton_class.ancestors.include?(NuzlockeJudge)
        ::KIF::Nuzlocke.singleton_class.prepend(NuzlockeJudge)
      end
      if defined?(::ItemHandlers) && ::ItemHandlers.respond_to?(:triggerCanUseInBattle) &&
         !::ItemHandlers.singleton_class.ancestors.include?(NuzlockeBalls)
        ::ItemHandlers.singleton_class.prepend(NuzlockeBalls)
      end
      return true
    end
  end
end
