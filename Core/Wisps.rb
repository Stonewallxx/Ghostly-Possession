#==============================================================================
# Ghostly Possession: Will-o'-Wisp Trails
#==============================================================================
# At night a will-o'-wisp now and then appears a few tiles from the player
# and leads them somewhere (his picks 2026-10-24):
#
#   When     any night, all year, no setting; on routes (outdoor with a land
#            table), in caves (a cave table) and in haunted places (Team's
#            list); never on a dark map (its darkness would hide it) or in a
#            place too small to lead anyone (60 tiles you can walk to)
#   How often  1 in 5,000 quiet steps, twice that in haunted places; one at a
#            time; then 300 steps before the next
#   It shows a few tiles from you, on screen, with a soft chime (and with
#            Kanto Reloaded a toast: "A strange light flickers nearby...")
#   The trail  Toward a Hidden Spot: a quiet spot you can walk to, further on,
#            on your map or one connected to it (his ask 2026-10-25: across
#            one connection; the end well in from its map's edges)
#            (2 to 4 hops). Come within 4 tiles and it fades slowly away while
#            its motes fly on along the trail, and fades in again 10 to 14
#            tiles further along from you, on screen or not (his asks
#            2026-10-25: much slower, further away; Lead the Way).
#            Lost if you walk well away, leave its maps, the night ends, or
#            it waits an in-game hour at a spot for you (his pick 2026-10-25:
#            An Hour at Each Spot; map time only, battles and menus aside).
#   Its end  55 Treasure / 30 Possessed Wild / 10 Possession / 5 Grave (a
#            grave only with Restless Spirits, Core/Spirits.rb; an end that
#            can't happen is a treasure instead). At the end it sinks into
#            the ground and:
#              Treasure        an item ball (the game's own) with a purple
#                              glow and the wisp's motes; gone by morning
#              Possessed Wild  the map's own wild Pokémon, at its usual
#                              levels, with a Ghost inside: the battle starts
#                              there; with Hoenn Overworld Encounters on, it
#                              walks there instead
#              Possession      Team Possession's moment (with it On and
#                              nobody possessed)
#              Grave           GhostlyPossession::Spirits.place_grave(x, y)
#
# The ball is a plain Game_Event made here (never a class of this mod's, so
# a save loads without it); it's lifted out of every save while the save is
# written, and kept as plain data on $PokemonGlobal instead (Shared), so it's
# made again on the map after a load. Its look: UI/WispLook.rb.
#
#   GhostlyPossession::Wisps.step(handled)     a step's chance (the step hook)
#   GhostlyPossession::Wisps.update            each map update (the runner)
#   GhostlyPossession::Wisps.view              what the wisp shows now (UI)
#   GhostlyPossession::Wisps.treasure(rare)    a treasure roll (Restless
#                                              Spirits' gift too: rare 2)
#==============================================================================

module GhostlyPossession
  module Wisps
    RATE = 5000                    # 1 in this many quiet steps
    HAUNTED = 2                    # twice that in haunted places
    COOLDOWN = 300                 # quiet steps before the next
    MIN_AREA = 60                  # tiles you can walk to, or no wisp
    BOX = 32                       # the search's reach each way (tiles)
    FIRST = (5..6).freeze          # how far ahead it first shows, on screen (nearer only when that's off it)
    HOPS = (2..4).freeze           # hops to the end
    HOP = (10..14).freeze          # tiles each hop, on screen or not (fewer only when the trail turns back)
    NEAR = 4                       # come this close and it fades on ahead
    LOST = 22                      # walk this far from it and it's lost
    FADE_OUT = 60                  # frames to fade away, its motes flying on (his ask 2026-10-25: much slower; was 12)
    FADE_IN = 16                   # frames to show again
    END_EDGE = NEAR + 1            # the trail's end this far in from its map's edges (near it, you're on its map)
    WAIT = 60 * 40                 # steps it waits at a spot for you: an in-game hour (KIF's clock runs 60x; 40 steps a second)
    SINK = 30                      # frames to sink into the ground at the end
    ENDS = [[:treasure, 55], [:wild, 30], [:possession, 10], [:grave, 5]].freeze
    # [item, how many, weight]: Ghostly Items most, Ghost Hunting Gear often,
    # Valuables sometimes, a Rare Find about 1 in 10 (his picks 2026-10-24)
    GHOSTLY = [[:SPELLTAG, 1, 14], [:REAPERCLOTH, 1, 12], [:DUSKSTONE, 1, 12], [:SPOOKYPLATE, 1, 12]].freeze
    GEAR = [[:CLEANSETAG, 1, 13], [:DUSKBALL, 3, 12]].freeze
    VALUABLES = [[:NUGGET, 1, 5], [:STARPIECE, 1, 5], [:BIGPEARL, 1, 5]].freeze
    RARE = [[:RARECANDY, 1, 5], [:PPUP, 1, 4], [:ABILITYCAPSULE, 1, 1]].freeze
    BALL = "GPWispBall"            # the ball's event name (a shadow, like the game's balls)
    SCRIPT = "GhostlyPossession::Wisps.touch(@event_id) if defined?(GhostlyPossession::Wisps)"
    DIRS = [[2, 0, 1], [4, -1, 0], [6, 1, 0], [8, 0, -1]].freeze

    module_function

    #--------------------------------------------------------------------------
    # The chance
    #--------------------------------------------------------------------------
    def night?
      return Team.night?
    end

    # [times, out of]: the chance on this step
    def odds(map_id = nil)
      map_id ||= $game_map ? $game_map.map_id : 0
      return [Team::HAUNTED_MAPS.include?(map_id) ? HAUNTED : 1, RATE]
    end

    # A route, a cave or a haunted place; not a dark map
    def wisp_map?(map_id = nil)
      map_id ||= $game_map ? $game_map.map_id : 0
      meta = defined?(::GameData::MapMetadata) ? (::GameData::MapMetadata.try_get(map_id) rescue nil) : nil
      return false if meta && meta.dark_map
      return false if defined?(darknessEffectOnCurrentMap) && darknessEffectOnCurrentMap()
      return true if Team::HAUNTED_MAPS.include?(map_id)
      enc = $PokemonEncounters
      return false unless enc
      return true if enc.respond_to?(:has_cave_encounters?) && enc.has_cave_encounters?
      return meta && meta.outdoor_map && enc.respond_to?(:has_land_encounters?) && enc.has_land_encounters? ? true : false
    rescue StandardError
      return false
    end

    def steps
      v = Shared.data[:wisp_steps]
      return v.nil? ? COOLDOWN : v.to_i
    end

    def steps=(n)
      Shared.data[:wisp_steps] = n.to_i
    end

    def step(handled)
      return if handled[0] || @trail || @pending
      forced = @forced
      unless forced
        return unless night?
        self.steps = steps + 1 if steps < COOLDOWN
        return if steps < COOLDOWN
        return unless wisp_map?
        times, out_of = odds
        return unless rand(out_of) < times
      end
      return unless Team.quiet_step?
      return if $PokemonGlobal.respond_to?(:surfing) && $PokemonGlobal.surfing
      return unless start
      @forced = false
      handled[0] = true
    end

    #--------------------------------------------------------------------------
    # The trail's maps (his ask 2026-10-25: across one connection): a trail
    # is kept in its first map's tiles, and may step onto the maps connected
    # to it; where you are and where it shows go through their offsets
    #--------------------------------------------------------------------------
    # [[map id, its top left in the first map's tiles], ...]: the first map,
    # then each one connected to it (the game's own connections)
    def frame(origin_id = ($game_map ? $game_map.map_id : 0))
      list = [[origin_id, 0, 0]]
      conns = defined?(::MapFactoryHelper) && ::MapFactoryHelper.respond_to?(:getMapConnections) ? ::MapFactoryHelper.getMapConnections[origin_id] : nil
      Array(conns).each do |c|
        other = c[0] == origin_id ? c[3] : c[0]
        next if other == origin_id || list.any? { |id, _x, _y| id == other }
        ox, oy = $MapFactory.getRelativePos(other, 0, 0, origin_id, 0, 0)   # (its top left, seen from the first map)
        list << [other, ox, oy]
      end
      return list
    rescue StandardError
      return [[origin_id, 0, 0]]
    end

    # The trail's frame now (the one being searched before it starts)
    def trail_frame
      return @trail[:frame] if @trail && @trail[:frame]
      return @frame ||= frame
    end

    # A map by id while the game has it loaded (a connected map is, within
    # a screen and 6 tiles of you), else nil: a map is never read for the
    # trail itself (setting one up runs the game's and other mods' map hooks)
    def map_by_id(id)
      return $game_map if $game_map && $game_map.map_id == id
      maps = defined?($MapFactory) && $MapFactory && $MapFactory.respond_to?(:maps) ? $MapFactory.maps : nil
      return Array(maps).compact.find { |m| m.map_id == id }
    end

    # A tile of the trail's frame: [map, x, y on it], or nil off every map
    def tile_at(x, y, fr = trail_frame)
      fr.each do |id, ox, oy|
        m = map_by_id(id)
        next unless m
        lx, ly = x - ox, y - oy
        return [m, lx, ly] if m.valid?(lx, ly)
      end
      return nil
    end

    # Where a map's top left is in the trail's frame, or nil if it isn't one of its maps
    def offset_of(map_id, fr = trail_frame)
      e = fr.find { |id, _x, _y| id == map_id }
      return e ? [e[1], e[2]] : nil
    end

    def trail_map?(map_id)
      return @trail && offset_of(map_id) ? true : false
    end

    # You in the trail's frame, or nil off its maps
    def player_at
      off = $game_map && $game_player ? offset_of($game_map.map_id) : nil
      return off ? [$game_player.x + off[0], $game_player.y + off[1]] : nil
    end

    #--------------------------------------------------------------------------
    # The trail: a search from you, a hidden spot, the path to it
    #--------------------------------------------------------------------------
    # Every tile you can walk to near you, onto the maps next door too:
    # [distance, came-from], by the player's own passability on your map
    # (ledges aren't followed), by the tiles' and events' elsewhere
    def search(px, py, fr = trail_frame)
      dist = { [px, py] => 0 }
      from = {}
      queue = [[px, py]]
      until queue.empty?
        x, y = queue.shift
        DIRS.each do |d, dx, dy|
          nx, ny = x + dx, y + dy
          next if dist.has_key?([nx, ny])
          next if (nx - px).abs > BOX || (ny - py).abs > BOX
          next unless step_ok?(x, y, d, fr)
          dist[[nx, ny]] = dist[[x, y]] + 1
          from[[nx, ny]] = [x, y]
          queue << [nx, ny]
        end
      end
      return [dist, from]
    end

    # One step of the search: on your map as you'd walk it; across a map's
    # edge or on the map next door by its tiles both ways and no event in the way
    def step_ok?(x, y, d, fr = trail_frame)
      _d, dx, dy = DIRS.find { |dd, _x, _y| dd == d }
      a = tile_at(x, y, fr)
      b = a && tile_at(x + dx, y + dy, fr)
      return false unless a && b
      return $game_player.passable?(a[1], a[2], d) if a[0].equal?($game_map) && b[0].equal?($game_map)
      return false unless a[0].passable?(a[1], a[2], d) && b[0].passable?(b[1], b[2], 10 - d)
      return b[0].events.values.none? { |e| e.x == b[1] && e.y == b[2] && !e.through && e.character_name.to_s != "" }
    end

    def path_to(from, spot)
      path = [spot]
      path.unshift(from[path[0]]) while from[path[0]]
      return path
    end

    # A tile the wisp may show over (the trail's frame): not near its map's
    # edge, no event, not you, no follower, no ledge, ice, water, waterfall,
    # current, bridge or counter
    def spot_ok?(x, y, fr = trail_frame)
      map, lx, ly = tile_at(x, y, fr)
      return false unless map
      return false if lx < 1 || ly < 1 || lx > map.width - 2 || ly > map.height - 2
      return false if map.events.values.any? { |e| e.x == lx && e.y == ly && !e.instance_variable_get(:@erased) }
      return false if [x, y] == player_at || (map.equal?($game_map) && $game_player.x == lx && $game_player.y == ly)
      followers = $PokemonTemp && $PokemonTemp.respond_to?(:dependentEvents) && $PokemonTemp.dependentEvents ? $PokemonTemp.dependentEvents : nil
      if map.equal?($game_map) && followers && followers.respond_to?(:realEvents)
        return false if followers.realEvents.any? { |e| e.x == lx && e.y == ly }
      end
      tag = map.terrain_tag(lx, ly)
      return false if tag && [:ledge, :ice, :can_surf, :waterfall, :waterfall_crest, :waterCurrent, :bridge].any? { |f| tag.respond_to?(f) && tag.send(f) }
      return false if map.respond_to?(:counter?) && map.counter?(lx, ly)
      return true
    end

    # The trail's end: also open on all four sides (the ball there mustn't
    # close a one-tile path), no event next to it, not in tall grass, and
    # well in from its map's edges (coming near it, you're on its map: its
    # ball, grave or battle is always on the map you're on)
    def end_ok?(x, y, fr = trail_frame)
      return false unless spot_ok?(x, y, fr)
      map, lx, ly = tile_at(x, y, fr)
      return false if lx < END_EDGE || ly < END_EDGE || lx > map.width - 1 - END_EDGE || ly > map.height - 1 - END_EDGE
      return false unless [2, 4, 6, 8].all? { |d| map.passable?(lx, ly, d) }
      return false if map.events.values.any? { |e| (e.x - lx).abs <= 1 && (e.y - ly).abs <= 1 && !e.instance_variable_get(:@erased) }
      return !(map.respond_to?(:bush?) && map.bush?(lx, ly))
    end

    # Where a tile of the map you're on is on screen: [x, the ground under
    # it] (Game_Character's way)
    def screen_xy(x, y)
      m = $game_map
      return [((x * 128 - m.display_x) / 4.0).round + 16, ((y * 128 - m.display_y) / 4.0).round + 32]
    end

    # ...a tile of the trail's frame (on the map next door, through its offset)
    def trail_xy(x, y)
      ox, oy = ($game_map ? offset_of($game_map.map_id) : nil) || [0, 0]
      return screen_xy(x - ox, y - oy)
    end

    # On screen with room for the wisp above it
    def on_screen?(x, y)
      sx, sy = trail_xy(x, y)
      return sx.between?(24, 488) && sy.between?(64, 380)
    end

    def start
      return false unless $game_map && $game_player
      @frame = frame
      px, py = $game_player.x, $game_player.y
      dist, from = search(px, py)
      return false if dist.length < MIN_AREA
      hops = HOPS.min + rand(HOPS.max - HOPS.min + 1)
      want = FIRST.min + hops * ((HOP.min + HOP.max) / 2)
      spots = dist.select { |(x, y), d| (d - want).abs <= 3 && end_ok?(x, y) }.keys
      spots = dist.select { |(x, y), d| d >= 12 && end_ok?(x, y) }.keys if spots.empty?
      return false if spots.empty?
      spot = spots[rand(spots.length)]
      path = path_to(from, spot)
      first = (FIRST.to_a.reverse + (3...FIRST.min).to_a.reverse).find do |i|
        i < path.length - 1 && spot_ok?(*path[i]) && on_screen?(*path[i])
      end
      return false unless first
      # (one from the Debug menu isn't lost by day)
      @trail = { :map => $game_map.map_id, :frame => @frame, :path => path, :at => first, :phase => :in, :t => 0,
                 :ending => @forced_end || ending, :anytime => @forced ? true : false }
      @forced_end = nil
      light_on
      WispLook.appear
      end_map = tile_at(*spot)[0].map_id
      GhostlyPossession.log("A will-o'-wisp appeared (#{@trail[:ending]}, #{path.length - 1} tiles to its end at #{spot.inspect}" +
                            (end_map == $game_map.map_id ? ")" : ", on the map next door, #{end_map})"))
      return true
    rescue StandardError => e
      @trail = nil
      @frame = nil
      GhostlyPossession.log("A will-o'-wisp couldn't start: #{e.class}: #{e.message}")
      return false
    end

    # Which end, by weight; one that can't happen now is a treasure
    def ending
      roll = rand(ENDS.sum { |_e, w| w })
      pick = ENDS.find { |_e, w| (roll -= w) < 0 }[0]
      return possible?(pick) ? pick : :treasure
    end

    def possible?(kind)
      case kind
      when :wild       then return wild_type ? true : false
      when :possession then return Settings.team? && !Team.possessed_somewhere? && !Ghosts.hosts.empty?
      when :grave      then return grave_ready?
      end
      return true
    end

    # Restless Spirits (Core/Spirits.rb, Step 12): a fallen Pokémon whose grave can show
    def grave_ready?
      return defined?(GhostlyPossession::Spirits) && GhostlyPossession::Spirits.respond_to?(:grave_ready?) &&
             GhostlyPossession::Spirits.grave_ready? ? true : false
    rescue StandardError
      return false
    end

    #--------------------------------------------------------------------------
    # Each map update: hops, the end, lost
    #--------------------------------------------------------------------------
    def update
      tick_ball
      run_pending if @pending
      t = @trail
      return unless t
      unless $game_map && trail_map?($game_map.map_id)
        stop("its maps were left")
        return
      end
      x, y = t[:path][t[:at]]
      case t[:phase]
      when :in
        t[:t] += 1
        t[:phase], t[:t] = :shown, 0 if t[:t] >= FADE_IN
      when :shown
        return unless calm?
        if !t[:anytime] && Graphics.frame_count % 60 == 0 && !night?
          lose("night ended")
        elsif far?(x, y)
          lose("it was left behind")
        elsif (t[:waited] = t[:waited].to_i + 1) >= WAIT
          lose("it waited an hour")
        elsif near?(x, y)
          if t[:at] >= t[:path].length - 1
            # (its end is on the map you're on: it's well in from the edges)
            if (end_tile = tile_at(x, y)) && end_tile[0].equal?($game_map)
              t[:phase], t[:t] = :sink, 0
              WispLook.sink
            end
          else
            hop = next_hop
            if hop
              t[:next], t[:phase], t[:t], t[:waited] = hop, :out, 0, 0
              WispLook.hop
            end
          end
        end
      when :out, :lost
        t[:t] += 1
        return if t[:t] < (t[:phase] == :lost ? FADE_OUT * 2 : FADE_OUT)
        if t[:phase] == :lost
          clear
        else
          # (picked again from where you are now: you walk on while it fades)
          t[:at], t[:phase], t[:t] = next_hop || t[:next], :in, 0
        end
      when :sink
        t[:t] += 1
        finish if t[:t] >= SINK
      end
    rescue StandardError => e
      clear
      GhostlyPossession.log("A will-o'-wisp's trail failed: #{e.class}: #{e.message}")
    end

    # Nothing else going on (no menu, message or battle; on the map)
    def calm?
      return false unless $scene.is_a?(::Scene_Map) && $game_temp && $game_player
      return false if $PokemonTemp && $PokemonTemp.respond_to?(:miniupdate) && $PokemonTemp.miniupdate
      t = $game_temp
      return !(t.in_menu || t.in_battle || t.message_window_showing || t.player_transferring)
    end

    # (you and it in the trail's frame: you may be on the map next door)
    def near?(x, y)
      px, py = player_at
      return px ? (x - px).abs + (y - py).abs <= NEAR : false
    end

    def far?(x, y)
      px, py = player_at
      return px ? (x - px).abs + (y - py).abs > LOST : true
    end

    # The next spot along the path, counted from it or from you if you're
    # further along: 14 to 10 tiles on, on screen or not (its motes show
    # the way; fewer only when no spot that far will do), the end itself
    # when it's that close
    def next_hop
      t = @trail
      last = t[:path].length - 1
      from = [t[:at], player_index].max
      return last if last - from <= HOP.max
      tries = HOP.to_a.reverse + (2...HOP.min).to_a.reverse
      tries.each do |n|
        i = from + n
        next if i >= last
        return i if spot_ok?(*t[:path][i])
      end
      return nil
    end

    # How far along the trail you are: its tile nearest you (the furthest of equals)
    def player_index
      px, py = player_at || [$game_player.x, $game_player.y]
      best, near = 0, nil
      @trail[:path].each_with_index do |(x, y), i|
        d = (x - px).abs + (y - py).abs
        best, near = i, d if near.nil? || d <= near
      end
      return best
    end

    def lose(why)
      @trail[:phase], @trail[:t] = :lost, 0
      WispLook.lost
      GhostlyPossession.log("The will-o'-wisp faded away (#{why})")
    end

    def stop(why)
      GhostlyPossession.log("The will-o'-wisp is gone (#{why})")
      clear
    end

    def clear
      @trail = nil
      @frame = nil
      self.steps = 0
      light_off
    end

    # The wisp as it shows now, for UI/WispLook.rb: [x, y, phase, frames
    # into it, frames the phase takes, the trail's tiles to its next spot
    # while it fades on (its motes fly them)], or nil; in the trail's frame
    # (WispLook puts it on screen with trail_xy)
    def view
      t = @trail
      return nil unless t
      x, y = t[:path][t[:at]]
      len = { :in => FADE_IN, :out => FADE_OUT, :lost => FADE_OUT * 2, :sink => SINK }[t[:phase]] || 1
      ahead = t[:phase] == :out && t[:next] ? t[:path][t[:at]..t[:next]] : nil
      return [x, y, t[:phase], t[:t], len, ahead]
    end

    def active?
      return @trail ? true : false
    end

    #--------------------------------------------------------------------------
    # The end
    #--------------------------------------------------------------------------
    def finish
      t = @trail
      map, x, y = tile_at(*t[:path].last)
      kind = t[:ending]
      kind = :treasure unless possible?(kind)
      clear
      unless map && map.equal?($game_map)
        GhostlyPossession.log("The will-o'-wisp's trail ended off the map you're on: nothing there")
        return
      end
      GhostlyPossession.log("The will-o'-wisp's trail ended at (#{x}, #{y}): #{kind}")
      case kind
      when :treasure then place_ball(x, y)
      when :grave    then GhostlyPossession::Spirits.place_grave(x, y)
      else @pending = [kind, x, y]
      end
    end

    # A battle or a moment, once nothing else is going on
    def run_pending
      return unless Leave.ready?
      kind, x, y = @pending
      @pending = nil
      case kind
      when :wild
        wild_end(x, y)
      when :possession
        ghost = Ghosts.pick
        hosts = ghost ? Ghosts.hosts(nil, ghost) : []
        host = hosts.empty? ? nil : hosts[rand(hosts.length)]
        place_ball(x, y) if !host || Team.possessed_somewhere? || !Team.possess(host, Ghosts.note_for(host, ghost))
      end
    rescue StandardError => e
      @pending = nil
      GhostlyPossession.log("A will-o'-wisp's end failed: #{e.class}: #{e.message}")
    end

    # This map's kind of wild encounter at the end: the land's, else a cave's
    def wild_type
      enc = $PokemonEncounters
      return nil unless enc
      time = defined?(pbGetTimeNow) ? pbGetTimeNow : nil
      [[:has_land_encounters?, :Land], [:has_cave_encounters?, :Cave]].each do |has, base|
        next unless enc.respond_to?(has) && enc.send(has)
        type = enc.respond_to?(:find_valid_encounter_type_for_time) ? enc.find_valid_encounter_type_for_time(base, time) : base
        return type if type
      end
      return nil
    rescue StandardError
      return nil
    end

    # The map's own wild Pokémon with a Ghost inside: it walks there (Hoenn
    # Overworld Encounters on), or its battle starts
    # (a few of the map's encounters tried, for one a Ghost can go into)
    def wild_end(x, y)
      type = wild_type
      return place_ball(x, y) unless type
      5.times do
        wild = $PokemonEncounters.choose_wild_pokemon(type)
        next unless wild
        if walkers?
          ev = (spawn_overworld_pokemon([wild[0], wild[1]], [x, y], type.to_s.start_with?("Cave") ? :Cave : :Land) rescue nil)
          if ev && ev.respond_to?(:pokemon) && ev.pokemon
            if Wilds.haunt(ev.pokemon)
              GhostlyPossession.log("A possessed #{ev.pokemon.name} walks where the will-o'-wisp went")
              return
            end
            despawn_overworld_pokemon(ev.id, ev.instance_variable_get(:@terrain)) rescue remove_event(ev)
            next
          end
        end
        pkmn = pbGenerateWildPokemon(wild[0], wild[1])
        next unless Wilds.haunt(pkmn)
        pbWildBattleCore(pkmn)
        return
      end
      place_ball(x, y)
    end

    def walkers?
      return Compat.hoenn? && defined?(::HoennNativeKIFSettings) && ::HoennNativeKIFSettings.respond_to?(:enabled?) &&
             ::HoennNativeKIFSettings.enabled? && defined?(spawn_overworld_pokemon) ? true : false
    rescue StandardError
      return false
    end

    #--------------------------------------------------------------------------
    # The treasure
    #--------------------------------------------------------------------------
    # [item, how many]; rare: how much likelier a Rare Find is (Restless
    # Spirits' gift: 2)
    def treasure(rare = 1)
      list = (GHOSTLY + GEAR + VALUABLES).map { |i, n, w| [i, n, w] } + RARE.map { |i, n, w| [i, n, w * rare] }
      list = list.select { |i, _n, _w| item?(i) }
      return nil if list.empty?
      roll = rand(list.sum { |_i, _n, w| w })
      pick = list.find { |_i, _n, w| (roll -= w) < 0 }
      return [pick[0], pick[1]]
    end

    def item?(id)
      return defined?(::GameData::Item) && ::GameData::Item.exists?(id) ? true : false
    rescue StandardError
      return false
    end

    def ball
      b = Shared.data[:wisp_ball]
      return b.is_a?(Hash) ? b : nil
    end

    def place_ball(x, y)
      item = treasure
      return unless item
      Shared.data[:wisp_ball] = { :map => $game_map.map_id, :x => x, :y => y, :item => item[0], :count => item[1],
                                  :night => night? }
      make_ball
      GhostlyPossession.log("A treasure (#{item[1]} #{item[0]}) waits where the will-o'-wisp sank")
    end

    # The ball on the map (made again after a load, or coming back to it)
    def make_ball
      b = ball
      return unless b && $game_map && b[:map] == $game_map.map_id
      return if ball_event
      make_event(BALL, b[:x], b[:y], 2)
      light(:wisp_ball) do
        bb = GhostlyPossession::Wisps.ball
        if bb && $game_map && bb[:map] == $game_map.map_id
          sx, sy = GhostlyPossession::Wisps.screen_xy(bb[:x], bb[:y])
          [sx, sy - 12, 40]
        end
      end
    end

    def ball_event
      return nil unless $game_map
      return $game_map.events.values.find { |e| ours?(e, BALL) }
    end

    # Gone by morning (one left by day, from the Debug menu, waits)
    def tick_ball
      return unless ball && ball[:night] && Graphics.frame_count % 60 == 0 && !night?
      remove_ball
      GhostlyPossession.log("The will-o'-wisp's treasure was gone by morning")
    end

    def remove_ball
      Shared.data[:wisp_ball] = nil
      ev = ball_event
      remove_event(ev) if ev
      light_off(:wisp_ball)
    end

    # A on the ball: the item, the game's way (never swapped by a randomizer)
    def touch(event_id)
      b = ball
      ev = $game_map.events[event_id]
      return unless b && ev && ours?(ev, BALL)
      return unless pbItemBall(b[:item], b[:count], "", false)
      remove_ball
    end

    #--------------------------------------------------------------------------
    # Events of this mod's on the map (plain Game_Events)
    #--------------------------------------------------------------------------
    def ours?(ev, name = nil)
      n = ev.respond_to?(:name) ? ev.name.to_s : ""
      return name ? n == name : n.start_with?("GPWisp")
    rescue StandardError
      return false
    end

    # BWObjects facing up (pattern 2 the game's item ball, 3 an empty frame),
    # held still, A runs the script
    def make_event(name, x, y, pattern)
      rpg = ::RPG::Event.new(x, y)
      rpg.id = ($game_map.events.keys.max || 0) + 1
      rpg.name = name
      page = ::RPG::Event::Page.new
      page.graphic.character_name = "BWObjects"
      page.graphic.direction = 8
      page.graphic.pattern = pattern
      page.direction_fix = true
      page.walk_anime = false
      page.step_anime = false
      page.through = false
      page.trigger = 0
      page.move_type = 0
      page.list = [::RPG::EventCommand.new(355, 0, [SCRIPT]), ::RPG::EventCommand.new(0, 0, [])]
      rpg.pages = [page]
      ev = ::Game_Event.new($game_map.map_id, rpg, $game_map)
      $game_map.events[rpg.id] = ev
      if $scene.is_a?(::Scene_Map) && $scene.respond_to?(:spriteset?) && $scene.spriteset? && $scene.spriteset
        set = $scene.spriteset
        set.character_sprites.push(::Sprite_Character.new(::Spriteset_Map.viewport, ev)) if set.respond_to?(:character_sprites)
      end
      return ev
    end

    def remove_event(ev, map = $game_map)
      ev.erase if ev.respond_to?(:erase)
      map.events.delete(ev.id) if map && map.events[ev.id].equal?(ev)
      return unless $scene.is_a?(::Scene_Map) && $scene.respond_to?(:spritesets) && $scene.spritesets
      $scene.spritesets.values.each do |set|
        next unless set.respond_to?(:character_sprites) && set.character_sprites
        gone = set.character_sprites.select { |s| s.respond_to?(:character) && s.character.equal?(ev) }
        gone.each { |s| s.dispose unless s.disposed? }
        set.character_sprites -= gone
      end
    end

    # Stray events of this mod's (the map changed, or a save made before the
    # lift): taken off; then the ball made again if it's waiting here
    def tidy
      maps = defined?($MapFactory) && $MapFactory ? $MapFactory.maps : [$game_map]
      Array(maps).compact.each do |map|
        map.events.values.select { |e| ours?(e) }.each do |e|
          next if map.equal?($game_map) && ours?(e, BALL) && ball && ball[:map] == map.map_id && e.x == ball[:x] && e.y == ball[:y]
          remove_event(e, map)
        end
      end
      make_ball if ball && (night? || !ball[:night])
    rescue StandardError => e
      GhostlyPossession.log("A will-o'-wisp's leftovers couldn't be tidied: #{e.class}: #{e.message}")
    end

    # While a save is written, this mod's events aren't on any map (the ball
    # waits as plain data in Shared and comes back after a load)
    def lift
      lifted = []
      maps = defined?($MapFactory) && $MapFactory ? $MapFactory.maps : []
      Array(maps).compact.each do |map|
        map.events.each { |id, e| lifted << [map, id, e] if ours?(e) }
      end
      lifted.each { |map, id, _e| map.events.delete(id) }
      return lifted
    rescue StandardError
      return lifted || []
    end

    def put_back(lifted)
      Array(lifted).each { |map, id, e| map.events[id] = e }
    end

    module SaveLift
      def save_to_file(*args)
        lifted = GhostlyPossession::Wisps.lift
        return super
      ensure
        GhostlyPossession::Wisps.put_back(lifted)
      end
    end

    #--------------------------------------------------------------------------
    # Pitch Black's lights (Core/Season.rb, Step 10)
    #--------------------------------------------------------------------------
    def season?
      return defined?(GhostlyPossession::Season) && GhostlyPossession::Season.respond_to?(:light) ? true : false
    end

    def light(key, &block)
      GhostlyPossession::Season.light(key, &block) if season?
    rescue StandardError
      nil
    end

    def light_off(key = :wisp)
      GhostlyPossession::Season.unlight(key) if season? && GhostlyPossession::Season.respond_to?(:unlight)
    rescue StandardError
      nil
    end

    def light_on
      light(:wisp) do
        v = GhostlyPossession::Wisps.view
        if v
          sx, sy = GhostlyPossession::Wisps.trail_xy(v[0], v[1])
          [sx, sy - 30, 44]
        end
      end
    end

    #--------------------------------------------------------------------------
    # The Debug menu
    #--------------------------------------------------------------------------
    def force_next
      pbMessage(force_words)
    end

    # The next quiet step's wisp, its trail's end (nil: by chance): its words
    # (the Kanto Reloaded Debug mod's page calls this)
    def force_words(kind = nil)
      @forced = true
      @forced_end = kind if ENDS.any? { |e, _w| e == kind }
      return _INTL("The next quiet step, a will-o'-wisp will appear (any time, any place you can walk around).") unless @forced_end
      words = _INTL("The next quiet step, a will-o'-wisp will appear, its trail ending in: {1}.", end_name(@forced_end))
      return words if possible?(@forced_end)
      return words + " " + _INTL("It can't end that way here and now, so it may end in a treasure.")
    end

    def end_name(kind)
      return { :treasure => _INTL("A Treasure"), :wild => _INTL("A Possessed Wild"), :possession => _INTL("A Possession"),
               :grave => _INTL("A Grave") }[kind] || kind.to_s
    end

    def force_end
      ends = [:treasure, :wild, :possession, :grave]
      names = [_INTL("Treasure"), _INTL("Possessed Wild"), _INTL("Possession"), _INTL("Grave"), _INTL("By Chance")]
      pick = pbMessage(_INTL("How should the next will-o'-wisp's trail end?"), names, -1)
      return if pick.nil? || pick < 0
      @forced_end = ends[pick]
      pbMessage(_INTL("The next trail ends in: {1}.", names[pick])) if @forced_end
    end

    # (the clock: Debug's Night Now, Evening Now and Morning Now, Core/Debug.rb)
    def debug_menu
      return unless defined?(::DebugMenuCommands)
      ::DebugMenuCommands.register("ghostly_possession_wisp", {
        "parent"      => "ghostly_possession",
        "name"        => _INTL("A Will-o'-Wisp on the Next Step"),
        "description" => _INTL("The next quiet step, a will-o'-wisp appears (any time, no chance, no wait)."),
        "effect"      => proc { GhostlyPossession::Wisps.force_next }
      })
      ::DebugMenuCommands.register("ghostly_possession_wisp_end", {
        "parent"      => "ghostly_possession",
        "name"        => _INTL("A Will-o'-Wisp Ending In..."),
        "description" => _INTL("Choose how the next will-o'-wisp's trail ends: a treasure, a possessed wild Pokémon, a possession or a grave."),
        "effect"      => proc { GhostlyPossession::Wisps.force_end }
      })
    end

    #--------------------------------------------------------------------------
    # The hooks
    #--------------------------------------------------------------------------
    def boot
      if defined?(::SaveData) && ::SaveData.respond_to?(:save_to_file) && !::SaveData.singleton_class.ancestors.include?(SaveLift)
        ::SaveData.singleton_class.prepend(SaveLift)
      end
      unless @booted
        ::Events.onStepTakenTransferPossible += proc { |_sender, e|
          begin
            GhostlyPossession::Wisps.step(e[0])
          rescue StandardError => err
            GhostlyPossession.log("A step's will-o'-wisp check failed: #{err.class}: #{err.message}")
          end
        }
        ::Events.onMapUpdate += proc { |_sender, _e| GhostlyPossession::Wisps.update }
        # (walking onto a map its trail goes onto keeps it)
        ::Events.onMapChange += proc { |_sender, _e|
          w = GhostlyPossession::Wisps
          w.stop("its maps were left") if w.active? && !($game_map && w.trail_map?($game_map.map_id))
        } if ::Events.respond_to?(:onMapChange)
        ::Events.onMapSceneChange += proc { |_sender, _e|
          GhostlyPossession::Wisps.tidy
          GhostlyPossession::WispLook.attach if defined?(GhostlyPossession::WispLook)
        }
        @booted = true
      end
      debug_menu
      return true
    end
  end
end
