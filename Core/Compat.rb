#==============================================================================
# Ghostly Possession: with other mods
#==============================================================================
# Hoenn Overworld Encounters (hoenn_native_kif; his picks 2026-10-24): wild
# Pokémon walk the routes, so Haunted Wilds happen there.
#
#   At spawn        Hoenn's route, cave and surf spawns (HoennNativeKIF.
#                   spawn_one) roll as an encounter does (Wilds.rb): not its
#                   town wildlife or water, Poké Radar patches, alphas or
#                   disguised ones. The map shows it (UI/MapAura.rb).
#   Flickers        It roams as its kind, but now and then fades out and
#                   back in two or three tiles away, on its own kind of
#                   ground (As Its Kind, but Flickers); never while you're
#                   within two tiles, it's noticed you, a battle's gathering,
#                   or it's about to fuse.
#   Alone Only      Its battle is always one on one: it never joins
#                   another's battle and none join its (OverworldPokemonEvent
#                   #update_behavior / #overworldPokemonBattle, before
#                   Hoenn's own), and after any wild battle the walking
#                   wilds wait a second before starting another.
#   Fusing          Two walking wilds that fuse on the map: the new one
#                   keeps the Ghost (The Fusion Keeps the Ghost; its move
#                   and slot fit its new host); two possessed never fuse.
#
# Alpha Encounters (alpha_encounters): Never Both. A wild alpha is never
# possessed (Wilds.candidate). A possessed walking wild that turns alpha as
# its battle starts (Both, Keep the Alpha, his pick 2026-10-24) stays both:
# in battle only the Echo shows (UI/BattleLook.rb), and caught, the alpha is
# kept and the Ghost goes free (WildBattle.rb). The Ghost's own battle may
# turn alpha, as any wild battle.
#
# Hooked only when those mods are there (mod.json loads this mod after them).
#==============================================================================

module GhostlyPossession
  module Compat
    HOLD = 60                          # frames the walking wilds wait after a battle (a second)
    FLICKER_WAIT = [300, 600].freeze   # frames between flickers
    FLICKER_FADE = 30                  # frames to fade out, and back in (his ask 2026-10-25: slower; was 10)
    FLICKER_GONE = 45                  # frames it stays gone before it shows again (his ask: a little longer)
    FLICKER_NEAR = 2                   # never while you're this close (tiles)
    FLICKER_HOP = (2..3).freeze        # how far it reappears (tiles)

    class << self
      attr_accessor :fusing            # the fusions Hoenn's about to make with a possessed parent
    end

    module_function

    def hoenn?
      return defined?(::HoennNativeKIF) && defined?(::OverworldPokemonEvent) ? true : false
    end

    # A walking wild with a Ghost inside
    def possessed_ow?(ev)
      return false unless ev && ev.respond_to?(:pokemon)
      pkmn = ev.pokemon
      return pkmn ? Note.wild?(pkmn) : false
    rescue StandardError
      return false
    end

    # Still on the map (Hoenn's despawned ones linger, erased)
    def on_map?(ev)
      return false if ev.instance_variable_get(:@erased)
      map = ev.respond_to?(:map) && ev.map ? ev.map : $game_map
      return map && map.events[ev.id].equal?(ev) ? true : false
    rescue StandardError
      return false
    end

    #--------------------------------------------------------------------------
    # At spawn
    #--------------------------------------------------------------------------
    def spawned(ev)
      return unless ev && defined?(::OverworldPokemonEvent) && ev.is_a?(::OverworldPokemonEvent)
      pkmn = ev.pokemon
      return unless pkmn && !ev.instance_variable_get(:@erased)
      return if defined?(::HoennNativeKIFRadar) && ::HoennNativeKIFRadar.respond_to?(:active?) && ::HoennNativeKIFRadar.active?
      return if Wilds.alpha?(pkmn) || Note.possessed?(pkmn)
      return if ::OverworldPokemonEvent::DISGUISED_POKEMON.include?(ev.species)
      forced = Debug.wild_forced?
      return unless forced || Settings.wilds?
      unless forced
        times, out_of = Wilds.odds
        return unless rand(out_of) < times
      end
      Debug.wild_forced = false if Wilds.haunt(pkmn)
    rescue StandardError => e
      GhostlyPossession.log("A walking wild couldn't be checked for a Ghost: #{e.class}: #{e.message}")
    end

    #--------------------------------------------------------------------------
    # Alone Only, and the wait after a battle
    #--------------------------------------------------------------------------
    # A battle's gathering, and this one's not to be in it
    def alone_blocked?(ev)
      parts = $PokemonTemp && $PokemonTemp.respond_to?(:overworld_wild_battle_participants) ? $PokemonTemp.overworld_wild_battle_participants : nil
      return false if parts.nil? || parts.empty? || parts.include?(ev)
      return possessed_ow?(ev) || parts.any? { |e| possessed_ow?(e) }
    end

    def hold!
      @hold_until = ::Graphics.frame_count + HOLD if defined?(::Graphics)
    end

    def held?
      return @hold_until && ::Graphics.frame_count < @hold_until ? true : false
    end

    #--------------------------------------------------------------------------
    # Flickering (kept on the event as plain values: [:wait, frame], [:out,
    # x, y], [:gone, frame], [:in])
    #--------------------------------------------------------------------------
    def flicker(ev)
      return unless possessed_ow?(ev)
      st = ev.instance_variable_get(:@gp_flicker)
      unless flicker_ok?(ev)
        # cut short mid-fade (or saved mid-fade): seen again at once (only
        # its own fades: Hoenn's are left alone)
        if st && st[0] != :wait
          ev.opacity = 255
          ev.instance_variable_set(:@gp_flicker, [:wait, Graphics.frame_count + wait_frames])
        end
        return
      end
      now = Graphics.frame_count
      st ||= [:wait, now + wait_frames]
      case st[0]
      when :wait
        if now >= st[1] && !ev.moving? && !ev.jumping?
          spot = flicker_spot(ev)
          st = spot ? [:out, spot[0], spot[1]] : [:wait, now + wait_frames]
        end
      when :out
        ev.opacity = [ev.opacity - 255 / FLICKER_FADE, 0].max
        if ev.opacity == 0 && !ev.moving? && !ev.jumping?
          ev.moveto(st[1], st[2]) if free_spot?(ev, st[1], st[2])
          st = [:gone, now + FLICKER_GONE]
        end
      when :gone
        ev.opacity = 0
        # (a clock that jumped, as after loading, doesn't keep it gone)
        st = [:in] if now >= st[1] || st[1] - now > FLICKER_GONE
      when :in
        ev.opacity = [ev.opacity + 255 / FLICKER_FADE, 255].min
        st = [:wait, now + wait_frames] if ev.opacity >= 255
      end
      ev.instance_variable_set(:@gp_flicker, st)
    rescue StandardError => e
      ev.opacity = 255 rescue nil
      ev.instance_variable_set(:@gp_flicker, nil) rescue nil
      GhostlyPossession.log("A walking wild couldn't flicker: #{e.class}: #{e.message}")
    end

    def wait_frames
      return FLICKER_WAIT[0] + rand(FLICKER_WAIT[1] - FLICKER_WAIT[0])
    end

    # Roaming, on the map, nothing else going on, you not close by
    def flicker_ok?(ev)
      return false unless ev.instance_variable_get(:@setup_complete) && on_map?(ev)
      return false unless $scene.is_a?(::Scene_Map) && $game_temp && $game_player
      t = $game_temp
      return false if t.in_menu || t.in_battle || t.message_window_showing
      return false if $PokemonTemp && $PokemonTemp.respond_to?(:miniupdate) && $PokemonTemp.miniupdate
      return false if defined?(pbMapInterpreterRunning?) && pbMapInterpreterRunning?
      parts = $PokemonTemp.respond_to?(:overworld_wild_battle_participants) ? $PokemonTemp.overworld_wild_battle_participants : nil
      return false if (parts && !parts.empty?) || ($PokemonTemp.respond_to?(:overworld_wild_battle_triggered) && $PokemonTemp.overworld_wild_battle_triggered)
      return false if ev.instance_variable_get(:@_triggered) || ev.instance_variable_get(:@move_route_forcing)
      return false if ev.instance_variable_get(:@kif_fusion_pending) || ev.instance_variable_get(:@hno_radar_stationary)
      return false unless ev.current_state == :ROAMING
      return (ev.x - $game_player.x).abs + (ev.y - $game_player.y).abs > FLICKER_NEAR
    end

    # A tile two or three away, on its own kind of ground, free, away from you
    def flicker_spot(ev)
      spots = []
      (-FLICKER_HOP.max..FLICKER_HOP.max).each do |dx|
        (-FLICKER_HOP.max..FLICKER_HOP.max).each do |dy|
          next unless FLICKER_HOP.include?(dx.abs + dy.abs)
          spots << [ev.x + dx, ev.y + dy] if free_spot?(ev, ev.x + dx, ev.y + dy)
        end
      end
      return spots.empty? ? nil : spots[rand(spots.length)]
    end

    def free_spot?(ev, x, y)
      map = $game_map
      return false unless map.valid?(x, y)
      return false if (x - $game_player.x).abs + (y - $game_player.y).abs <= FLICKER_NEAR
      followers = $PokemonTemp && $PokemonTemp.respond_to?(:dependentEvents) && $PokemonTemp.dependentEvents ? $PokemonTemp.dependentEvents : nil
      return false if followers && followers.respond_to?(:realEvents) && followers.realEvents.any? { |e| e.x == x && e.y == y }
      case ev.instance_variable_get(:@terrain)
      when :Water
        return defined?(::HoennNativeKIF) && ::HoennNativeKIF.respond_to?(:open_water_tile?) ? ::HoennNativeKIF.open_water_tile?(x, y) : false
      when :Cave
        return map.OWPokemonPassable?(x, y, 0) && [2, 4, 6, 8].all? { |d| map.passable?(x, y, d) }
      else
        return map.terrain_tag(x, y).land_wild_encounters && map.OWPokemonPassable?(x, y, 0)
      end
    rescue StandardError
      return false
    end

    #--------------------------------------------------------------------------
    # Fusing on the map: the new one keeps the Ghost
    #--------------------------------------------------------------------------
    # Hoenn's about to fuse these (due now): [possessed parent, fused species, x, y]
    def due_fusions(pending, frame)
      return Array(pending).select { |a, b, _f, due, _m| frame >= due && (possessed_ow?(a) || possessed_ow?(b)) }
                           .map { |a, b, fused, _due, _m| [possessed_ow?(a) ? a : b, fused, a.x, a.y] }
    end

    def child(ev, wild, position)
      list = Compat.fusing
      return unless list && ev && ev.respond_to?(:pokemon) && ev.pokemon
      entry = list.find { |_p, fused, x, y| Array(wild)[0] == fused && Array(position) == [x, y] }
      return unless entry
      note = Note.read(entry[0].pokemon)
      pkmn = ev.pokemon
      return unless note && Ghosts.host?(pkmn, note[:ghost])
      fresh = Ghosts.note_for(pkmn, note[:ghost], note[:ghost_shiny])
      fresh = fresh.merge(:ghost => note[:ghost], :move => Ghosts.move_for(note[:ghost], pkmn.level, pkmn), :wild => true)
      GhostlyPossession.log("A walking #{pkmn.name} fused on the map keeps its #{note[:ghost]}") if Note.write(pkmn, fresh)
    rescue StandardError => e
      GhostlyPossession.log("A fused walking wild couldn't keep its Ghost: #{e.class}: #{e.message}")
    end

    #--------------------------------------------------------------------------
    # The hooks
    #--------------------------------------------------------------------------
    module SpawnHook                   # HoennNativeKIF (singleton)
      def spawn_one(*args)
        ev = super
        GhostlyPossession::Compat.spawned(ev)
        return ev
      end
    end

    module EventHooks                  # OverworldPokemonEvent
      def update_behavior(*args)
        return if GhostlyPossession::Compat.held? || GhostlyPossession::Compat.alone_blocked?(self)
        return super
      end

      def overworldPokemonBattle(*args)
        return if GhostlyPossession::Compat.alone_blocked?(self)
        return super
      end

      def update(*args)
        ret = super
        GhostlyPossession::Compat.flicker(self)
        return ret
      end
    end

    module SocialHooks                 # HoennNativeKIFSocial (singleton)
      def maybe_queue_fusion(a, b, frame)
        return if GhostlyPossession::Compat.possessed_ow?(a) && GhostlyPossession::Compat.possessed_ow?(b)
        return super
      end

      def update_fusions(frame)
        GhostlyPossession::Compat.fusing = GhostlyPossession::Compat.due_fusions(instance_variable_get(:@pending_fusions), frame)
        return super
      ensure
        GhostlyPossession::Compat.fusing = nil
      end
    end

    module SpawnChild                  # Object (spawn_overworld_pokemon is the game's, top level)
      def spawn_overworld_pokemon(wild, position, *rest)
        ev = super
        GhostlyPossession::Compat.child(ev, wild, position) if GhostlyPossession::Compat.fusing
        return ev
      end
    end

    def boot
      return true unless hoenn?
      ::HoennNativeKIF.singleton_class.prepend(SpawnHook) unless ::HoennNativeKIF.singleton_class.ancestors.include?(SpawnHook)
      ::OverworldPokemonEvent.prepend(EventHooks) unless ::OverworldPokemonEvent.ancestors.include?(EventHooks)
      if defined?(::HoennNativeKIFSocial) && !::HoennNativeKIFSocial.singleton_class.ancestors.include?(SocialHooks)
        ::HoennNativeKIFSocial.singleton_class.prepend(SocialHooks)
      end
      ::Object.prepend(SpawnChild) unless ::Object.ancestors.include?(SpawnChild)
      GhostlyPossession.log("Hoenn Overworld Encounters: its walking wilds may have a Ghost inside")
      return true
    end
  end
end
