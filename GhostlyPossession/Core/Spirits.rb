#==============================================================================
# Ghostly Possession: Restless Spirits
#==============================================================================
# In KIF's Nuzlocke, now and then a will-o'-wisp leads you to the grave of a
# Pokémon that died in the run (his picks 2026-10-24):
#
#   Whose       the dead no longer with you (sent to the Graveyard, or
#               released; with "stays fainted" the body keeps its spirit);
#               a run not ended; the Restless Spirits setting On
#   How often   1 in 20 wisps (Wisps::ENDS), only while one is waiting
#   Where       the wisp's trail end; a fallen that died on this map, or one
#               joined to it, comes first (a Gym's or a town's: the maps round
#               that town count), else any (KIF's world graph, entrances.dat)
#   The grave   a small headstone (UI/SpiritLook.rb), waiting until morning;
#               A on it: Here Lies Sparky, Call Its Spirit / Pay Respects
#               (B closes it: the grave keeps waiting)
#   Pay Respects  its spirit rises and drifts away: laid to rest, its gift
#   Call        its spirit rises and battles you, a Ghost fusion: its own
#               body (a fusion's body half), a Ghost's head that suits its
#               level, its name. It's restless: after 5 turns it fades away.
#               Beat it: laid to rest, its gift. Catch it: it comes back,
#               keeping all it can (nickname, OT, nature, IVs, EVs, shininess;
#               its gender, ability and moves where its new form can have
#               them, else the ability's slot), it leaves KIF's
#               Graveyard (the death record stays), and it doesn't use up
#               the Nuzlocke place. It stays a Ghost: it can't be unfused
#               (his pick 2026-10-24: no free way back to the old one).
#   One chance  once its spirit has risen (whatever happens) its grave never
#               shows again
#   The gift    its held item if the Graveyard kept it, else a treasure
#               (Wisps.treasure, a Rare Find twice as likely)
#
# The grave is a plain Game_Event made here (never a class of this mod's):
# lifted out of every save while it's written, kept as plain data on
# $PokemonGlobal (Shared) instead, and made again on its map.
#
#   GhostlyPossession::Spirits.grave_ready?      a grave could show (Wisps asks)
#   GhostlyPossession::Spirits.place_grave(x, y) the wisp's trail ended here
#   GhostlyPossession::Spirits.active?           a spirit's battle is running
#==============================================================================

module GhostlyPossession
  module Spirits
    TURNS = 5                      # it fades after this many turns
    GRAVE = "GPGrave"              # the grave's event name
    SCRIPT = "GhostlyPossession::Spirits.touch(@event_id) if defined?(GhostlyPossession::Spirits)"
    RARE = 2                       # the gift's treasure: a Rare Find this much likelier
    STAMP_SPOT = 46                # its light in Pitch Black (px)
    MARK = :@ghostly_spirit        # on a spirit (plain data: harmless with the mod removed)

    module_function

    #--------------------------------------------------------------------------
    # Who: the fallen
    #--------------------------------------------------------------------------
    def nuzlocke?
      return false unless defined?(::KIF::Nuzlocke) && ::KIF::Nuzlocke.respond_to?(:on?) && ::KIF::Nuzlocke.on?
      st = ::KIF::Nuzlocke.state
      return st.is_a?(Hash) && !st[:ended]
    rescue StandardError
      return false
    end

    def risen
      list = Shared.data[:spirits_risen]
      list = Shared.data[:spirits_risen] = [] unless list.is_a?(Array)
      return list
    end

    def risen?(key)
      return risen.include?(key)
    end

    def rise!(key)
      risen << key unless risen?(key)
    end

    # [{:key, :name, :species, :level, :place, :pokemon (the Graveyard's, or nil)}]
    # The Graveyard's (they hold the Pokémon), then deaths with no Graveyard
    # entry (released, or stays fainted), the two matched on name, species,
    # level and place; then the risen and those still with you left out
    def fallen
      return [] unless nuzlocke?
      st = ::KIF::Nuzlocke.state
      graves = Array(st[:graveyard]).select { |e| e.is_a?(Hash) && e[:pokemon] }
      list = graves.map do |e|
        { :key => "p#{e[:pokemon].personalID}", :name => e[:name] || e[:pokemon].name, :species => e[:species] || e[:pokemon].species,
          :level => e[:level] || e[:pokemon].level, :place => e[:place], :pokemon => e[:pokemon] }
      end
      pool = graves.dup
      Array(st[:deaths]).each_with_index do |d, i|
        next unless d.is_a?(Hash)
        m = pool.index { |g| [:name, :species, :level, :place].all? { |k| g[k] == d[k] } }
        if m
          pool.delete_at(m)
          next
        end
        list << { :key => "d#{i}:#{d[:species]}:#{d[:name]}", :name => d[:name], :species => d[:species],
                  :level => d[:level], :place => d[:place], :pokemon => nil }
      end
      return list.reject { |f| risen?(f[:key]) || with_you?(f) }
    rescue StandardError => e
      GhostlyPossession.log("The fallen couldn't be listed: #{e.class}: #{e.message}")
      return []
    end

    # A dead one still in your party or PC (KIF's "stays fainted"): its body keeps its spirit
    def with_you?(f)
      return false if f[:pokemon]
      return owned.any? do |p|
        p.respond_to?(:kif_nz_dead) && p.kif_nz_dead && p.name == f[:name] && p.species == f[:species]
      end
    end

    def owned
      list = $Trainer ? $Trainer.party.compact : []
      if $PokemonStorage
        $PokemonStorage.maxBoxes.times do |b|
          $PokemonStorage.maxPokemon(b).times { |i| p = $PokemonStorage[b, i]; list << p if p }
        end
      end
      return list
    rescue StandardError
      return list || []
    end

    def find(key)
      return fallen.find { |f| f[:key] == key } || (@debug && @debug[:key] == key ? @debug : nil)
    end

    #--------------------------------------------------------------------------
    # Where: maps joined to where it died
    #--------------------------------------------------------------------------
    def infos
      @infos ||= (pbLoadMapInfos rescue {})
      return @infos
    end

    # place name => [map ids] (KIF's place_name run over every map, once)
    def place_maps(place)
      unless @places
        @places = Hash.new { |h, k| h[k] = [] }
        infos.keys.each { |id| @places[(::KIF::Nuzlocke.place_name(id) rescue nil)] << id }
      end
      return @places.has_key?(place) ? @places[place] : []
    end

    # The outdoor map an interior is in (a Gym: its town), or itself
    def town(id)
      seen = 0
      cur = id
      while cur && cur > 0 && seen < 12
        return cur if Season.outdoor?(cur)
        info = infos[cur]
        cur = info && info.respond_to?(:parent_id) ? info.parent_id : nil
        seen += 1
      end
      return id
    end

    # map id => [neighbouring map ids]: KIF's world graph (doors and walks),
    # then the game's edge connections
    def neighbours(id)
      @adjacent ||= build_adjacent
      return @adjacent[id] || []
    end

    def world
      return ::KIF::Rand::ER.dat if defined?(::KIF::Rand::ER) && ::KIF::Rand::ER.respond_to?(:dat)
      return Marshal.load(File.binread("Data/KIF/entrances.dat")) if File.file?("Data/KIF/entrances.dat")
      return nil
    rescue StandardError
      return nil
    end

    def build_adjacent
      adj = Hash.new { |h, k| h[k] = [] }
      link = proc do |a, b|
        next if a.nil? || b.nil? || a == b
        adj[a] << b unless adj[a].include?(b)
        adj[b] << a unless adj[b].include?(a)
      end
      d = world
      if d.is_a?(Hash)
        Array(d[:edges]).each do |from, list|
          a = from.to_s.split(":")[0].to_i
          Array(list).each { |to, _need| link.call(a, to.to_s.split(":")[0].to_i) }
        end
        Array(d[:doors]).each { |o| link.call(o[:map], o[:exit_map]) if o.is_a?(Hash) }
      end
      if defined?(::MapFactoryHelper) && ::MapFactoryHelper.respond_to?(:getMapConnections)
        conns = (::MapFactoryHelper.getMapConnections rescue nil)
        Array(conns).each_with_index do |list, id|
          Array(list).each { |c| link.call(id, c[0] == id ? c[3] : c[0]) if c.is_a?(Array) }
        end
      end
      return {}.merge(adj)
    rescue StandardError => e
      GhostlyPossession.log("The maps' links couldn't be read: #{e.class}: #{e.message}")
      return {}
    end

    # Where a fallen one counts as "here": the maps of its place, their towns,
    # and the maps joined to those
    def near_maps(f)
      ids = place_maps(f[:place])
      towns = ids.map { |id| town(id) }
      near = (ids + towns).uniq
      (ids + towns).uniq.each { |id| near.concat(neighbours(id)) }
      return near.uniq
    end

    def near?(f, map_id = ($game_map ? $game_map.map_id : 0))
      return near_maps(f).include?(map_id)
    end

    # The fallen one this grave is for: one from near here first, else any
    def choose(map_id = ($game_map ? $game_map.map_id : 0))
      list = fallen
      return nil if list.empty?
      near = list.select { |f| near?(f, map_id) }
      pool = near.empty? ? list : near
      return pool[rand(pool.length)]
    end

    #--------------------------------------------------------------------------
    # The grave on the map
    #--------------------------------------------------------------------------
    def grave
      g = Shared.data[:grave]
      return g.is_a?(Hash) ? g : nil
    end

    def grave_ready?
      return Settings.spirits? && grave.nil? && !fallen.empty?
    rescue StandardError
      return false
    end

    def night?
      return Team.night?
    end

    # The wisp's trail ended at x, y (Wisps.finish): a grave for one of the fallen
    def place_grave(x, y, f = nil)
      f ||= choose
      return Wisps.place_ball(x, y) unless f && $game_map
      Shared.data[:grave] = { :map => $game_map.map_id, :x => x, :y => y, :key => f[:key], :night => night? && !@debug_any }
      make_grave
      GhostlyPossession.log("A grave for #{f[:name]} (#{f[:species]}, died at #{f[:place]}) where the will-o'-wisp sank")
    end

    def make_grave
      g = grave
      return unless g && $game_map && g[:map] == $game_map.map_id
      return if grave_event
      make_event(GRAVE, g[:x], g[:y])
      Season.light(:grave) do
        gg = GhostlyPossession::Spirits.grave
        if gg && $game_map && gg[:map] == $game_map.map_id
          sx, sy = Wisps.screen_xy(gg[:x], gg[:y])
          [sx, sy - 14, STAMP_SPOT]
        end
      end if defined?(Season) && Season.respond_to?(:light)
    end

    def grave_event
      return nil unless $game_map
      return $game_map.events.values.find { |e| ours?(e) }
    end

    def remove_grave
      Shared.data[:grave] = nil
      ev = grave_event
      Wisps.remove_event(ev) if ev
      Season.unlight(:grave) if defined?(Season) && Season.respond_to?(:unlight)
    end

    def ours?(ev)
      return ev.respond_to?(:name) && ev.name.to_s == GRAVE
    rescue StandardError
      return false
    end

    # The game's BWObjects sheet, its empty frame (facing up, pattern 3): it
    # blocks and takes A, and draws nothing; the headstone is UI/SpiritLook.rb's
    def make_event(name, x, y)
      rpg = ::RPG::Event.new(x, y)
      rpg.id = ($game_map.events.keys.max || 0) + 1
      rpg.name = name
      page = ::RPG::Event::Page.new
      page.graphic.character_name = "BWObjects"
      page.graphic.direction = 8
      page.graphic.pattern = 3
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

    # Each map update: gone by morning (its spirit hasn't risen: it may come again)
    def update
      g = grave
      return unless g && g[:night] && Graphics.frame_count % 60 == 0 && !night?
      remove_grave
      GhostlyPossession.log("The grave was gone by morning")
    rescue StandardError => e
      GhostlyPossession.log("The grave couldn't be looked after: #{e.class}: #{e.message}")
    end

    # Stray graves taken off (the map changed, or a save made before the
    # lift); then the grave made again if it's waiting here
    def tidy
      maps = defined?($MapFactory) && $MapFactory ? $MapFactory.maps : [$game_map]
      g = grave
      Array(maps).compact.each do |map|
        map.events.values.select { |e| ours?(e) }.each do |e|
          next if g && map.equal?($game_map) && g[:map] == map.map_id && e.x == g[:x] && e.y == g[:y]
          Wisps.remove_event(e, map)
        end
      end
      make_grave if g && (night? || !g[:night])
    rescue StandardError => e
      GhostlyPossession.log("A grave's leftovers couldn't be tidied: #{e.class}: #{e.message}")
    end

    def lift
      lifted = []
      maps = defined?($MapFactory) && $MapFactory ? $MapFactory.maps : []
      Array(maps).compact.each { |map| map.events.each { |id, e| lifted << [map, id, e] if ours?(e) } }
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
        lifted = GhostlyPossession::Spirits.lift
        return super
      ensure
        GhostlyPossession::Spirits.put_back(lifted)
      end
    end

    #--------------------------------------------------------------------------
    # A on the grave
    #--------------------------------------------------------------------------
    def touch(event_id)
      g = grave
      ev = $game_map.events[event_id]
      return unless g && ev && ours?(ev)
      f = find(g[:key])
      unless f
        remove_grave
        return
      end
      case SpiritLook.read_grave(f)
      when :call     then call(f)
      when :respects then respects(f)
      end
    rescue StandardError => e
      GhostlyPossession.log("The grave couldn't be read: #{e.class}: #{e.message}")
    end

    # Its one chance taken: risen, the grave gone (before any battle: a save
    # reloaded can't try it again)
    def risen!(f)
      rise!(f[:key]) unless f[:key].to_s.start_with?("debug")
      @debug = nil if @debug && @debug[:key] == f[:key]
      remove_grave
    end

    def respects(f)
      SpiritLook.rise(f, :respects)
      risen!(f)
      SpiritLook.at_rest(f)
      gift(f)
      GhostlyPossession.log("#{f[:name]}'s spirit was laid to rest (paid respects)")
    end

    def call(f)
      spirit = build(f)
      unless spirit
        GhostlyPossession.log("#{f[:name]}'s spirit couldn't take a form: laid to rest")
        respects(f)
        return
      end
      SpiritLook.rise(f, :call)
      risen!(f)
      start(spirit, f)
    end

    #--------------------------------------------------------------------------
    # The spirit: a Ghost fusion of the fallen one
    #--------------------------------------------------------------------------
    def body_id(species)
      data = ::GameData::Species.get(species)
      return data.id_number <= ::Settings::NB_POKEMON ? data.id_number : get_body_id_from_symbol(data.id)
    end

    # A Ghost (GP's: this area's, else a classic one) at the stage that suits
    # its level, on its body; a few tried for a fusion that exists
    def form_for(f)
      body = body_id(f[:species])
      level = f[:level].to_i
      6.times do
        ghost = Ghosts.pick
        next unless ghost
        ghost = Ghosts.suited(ghost, level)
        head = ::GameData::Species.get(ghost).id_number
        species = :"B#{body}H#{head}"
        return species if (::GameData::Species.get(species) rescue nil)
      end
      return nil
    rescue StandardError
      return nil
    end

    # Copied from the fallen one, by name (never its death, HP, status or a
    # Ghost's note)
    KEEP = [:owner, :iv, :ev, :ivMaxed, :hiddenPowerType, :personalID, :obtain_method, :obtain_map, :obtain_text,
            :obtain_level, :hatched_map, :ribbons, :markings, :happiness, :pokerus, :hat, :cool, :beauty, :cute, :smart,
            :tough, :sheen].freeze
    KEEP_IVARS = [:@nature, :@ability_index, :@nature_for_stats, :@timeReceived].freeze

    # (a copy of its own: nothing shared with the Graveyard's)
    def copy_of(v)
      return v if v.nil? || v.is_a?(Integer) || v.is_a?(Float) || v.is_a?(Symbol) || v == true || v == false
      return Marshal.load(Marshal.dump(v))
    rescue StandardError
      return v
    end

    def build(f)
      species = form_for(f)
      return nil unless species
      level = [[f[:level].to_i, 1].max, (::GameData::GrowthRate.max_level rescue 100)].min
      spirit = ::Pokemon.new(species, level)
      old = f[:pokemon]
      if old
        KEEP.each do |attr|
          next unless old.respond_to?(attr) && spirit.respond_to?(:"#{attr}=")
          v = old.send(attr)
          spirit.send(:"#{attr}=", copy_of(v)) unless v.nil?
        end
        KEEP_IVARS.each do |iv|
          spirit.instance_variable_set(iv, copy_of(old.instance_variable_get(iv))) if old.instance_variable_defined?(iv)
        end
        shiny = old.shiny? ? true : false
        body_shiny = old.respond_to?(:body_shiny) && old.isFusion? ? old.body_shiny : shiny
        moves_from(spirit, old)
        keep_gender(spirit, old)
        keep_ability(spirit, old)
      else
        shiny = false
        body_shiny = false
      end
      spirit.instance_variable_set(:@shiny, shiny)
      spirit.head_shiny = false if spirit.respond_to?(:head_shiny=)
      spirit.body_shiny = body_shiny ? true : false if spirit.respond_to?(:body_shiny=)
      spirit.name = f[:name].to_s unless f[:name].to_s.empty?
      spirit.instance_variable_set(MARK, true)
      Engine.ghost_first(spirit)
      spirit.record_first_moves if spirit.respond_to?(:record_first_moves)
      spirit.calc_stats
      spirit.heal
      return spirit
    rescue StandardError => e
      GhostlyPossession.log("#{f[:name]}'s spirit couldn't be made: #{e.class}: #{e.message}")
      return nil
    end

    # Its gender, where its new form can be either
    def keep_gender(spirit, old)
      g = old.gender
      spirit.gender = g if g == 0 || g == 1
    end

    # Its ability, where its new form can have it (else the same slot)
    def keep_ability(spirit, old)
      id = old.ability_id
      slot = spirit.getAbilityList.find { |a, _i| a == id }
      return unless slot
      spirit.instance_variable_set(:@ability_index, slot[1])
      spirit.instance_variable_set(:@ability, nil)
    end

    # Its old moves where its new form can use them; the rest its new form's own
    def moves_from(spirit, old)
      kept = Array(old.moves).compact.select { |m| (spirit.compatible_with_move?(m.id) rescue false) }
      own = spirit.moves.map(&:id)
      list = kept.map do |m|
        nm = ::Pokemon::Move.new(m.id)
        nm.ppup = m.ppup if nm.respond_to?(:ppup=) && m.respond_to?(:ppup)
        nm
      end
      own.each do |id|
        break if list.length >= ::Pokemon::MAX_MOVES
        list << ::Pokemon::Move.new(id) unless list.any? { |m| m.id == id }
      end
      spirit.moves = list.first(::Pokemon::MAX_MOVES) unless list.empty?
    end

    #--------------------------------------------------------------------------
    # Its battle
    #--------------------------------------------------------------------------
    def active?
      return @active ? true : false
    end

    def spirit?(pkmn)
      return @active && pkmn && @active[:pokemon].equal?(pkmn) ? true : false
    end

    def battle_state
      return @active
    end

    # The spirit's battle: decision 1 laid to rest (its gift), 4 came back,
    # 3 faded (or you ran), 2 or 5 lost
    def start(spirit, f)
      if !$Trainer || $Trainer.able_pokemon_count == 0
        GhostlyPossession.log("#{f[:name]}'s spirit had no one to face: it faded")
        return
      end
      rewards = $PokemonTemp && $PokemonTemp.respond_to?(:battleRewards) && $PokemonTemp.battleRewards ? $PokemonTemp.battleRewards.length : nil
      @active = { :pokemon => spirit, :fallen => f, :snap => Marshal.load(Marshal.dump(spirit)), :left => TURNS,
                  :started => false, :faded => false, :rewards => rewards }
      decision = 0
      begin
        decision = pbWildBattleCore(spirit)
      ensure
        state = @active
        @active = nil
      end
      after(decision, state)
    end

    def after(decision, state)
      f = state[:fallen]
      if decision == 4
        came_back(state[:pokemon], f)
      elsif decision == 1 && state[:started]
        SpiritLook.at_rest(f)
        gift(f)
        GhostlyPossession.log("#{f[:name]}'s spirit was laid to rest (beaten)")
      elsif state[:faded]
        GhostlyPossession.log("#{f[:name]}'s spirit faded away")
      else
        GhostlyPossession.log("#{f[:name]}'s spirit's battle ended (#{decision})")
      end
    end

    # It came back: out of KIF's Graveyard (its death record stays), then the card
    def came_back(spirit, f)
      if f[:pokemon] && defined?(::KIF::Nuzlocke)
        Array(::KIF::Nuzlocke.state[:graveyard]).delete_if { |e| e.is_a?(Hash) && e[:pokemon].equal?(f[:pokemon]) }
      end
      GhostlyPossession.log("#{f[:name]}'s spirit came back")
      SpiritLook.came_back(spirit, f)
    end

    # Its gift: its held item if the Graveyard kept it (taken off it), else a treasure
    def gift(f)
      old = f[:pokemon]
      item = old && old.respond_to?(:item_id) ? old.item_id : nil
      if item
        old.item = nil
        SpiritLook.gift(f, item, 1, true)
        return
      end
      t = Wisps.treasure(RARE)
      SpiritLook.gift(f, t[0], t[1], false) if t
    end

    # As the battle starts: itself again (anything that changed a wild Pokémon
    # as it was made: onWildPokemonCreate's handlers, an alpha's roll), and
    # no alpha's backdrop or drops
    def battle_start(battle)
      a = @active
      return unless a
      spirit = a[:pokemon]
      snap = a[:snap]
      (spirit.instance_variables - snap.instance_variables).each { |iv| spirit.remove_instance_variable(iv) }
      snap.instance_variables.each { |iv| spirit.instance_variable_set(iv, Marshal.load(Marshal.dump(snap.instance_variable_get(iv)))) }
      if $PokemonTemp
        $PokemonTemp.encounterIsAlphaPokemon = false if $PokemonTemp.respond_to?(:encounterIsAlphaPokemon=)
        if $PokemonTemp.respond_to?(:battleRewards) && $PokemonTemp.battleRewards.is_a?(Array)
          $PokemonTemp.battleRewards.slice!((a[:rewards] || 0)..-1)
        end
      end
      a[:started] = true
    end

    # The end of a round: one turn less; the words; at none, it fades
    def end_of_round(battle)
      a = @active
      return unless a && battle.decision == 0
      battler = Array(battle.battlers).find { |b| b && spirit?(b.pokemon) }
      return unless battler
      a[:left] -= 1
      name = a[:fallen][:name]
      if a[:left] <= 0
        SpiritLook.fade(battle, battler)
        battle.pbDisplay(_INTL("{1}'s spirit faded away... It's at rest now.", name))
        a[:faded] = true
        battle.decision = 3
        return
      end
      SpiritLook.refresh_box(battle, battler)
      if a[:left] == 1
        battle.pbDisplay(_INTL("{1}'s spirit is about to fade away!", name))
      else
        battle.pbDisplay(_INTL("{1}'s spirit is growing restless...", name))
      end
    end

    def turns_left(pkmn)
      return spirit?(pkmn) ? @active[:left] : nil
    end

    # [the game's intro, ours]
    def intro(battle)
      a = @active
      return nil unless a
      name = a[:pokemon].name
      if battle.instance_variable_get(:@caughtOffGuard)
        return [_INTL("The wild {1} was caught off guard!", name), _INTL("{1}'s restless spirit rose up! It won't stay long...", name)]
      end
      return [_INTL("Oh! A wild {1} appeared!", name), _INTL("{1}'s restless spirit rose up! It won't stay long...", name)]
    end

    #--------------------------------------------------------------------------
    # Hooks
    #--------------------------------------------------------------------------
    module BattleHooks
      def pbStartBattle(*args)
        GhostlyPossession::Battle.safely("A spirit's battle") { GhostlyPossession::Spirits.battle_start(self) }
        return super
      end

      def pbStartBattleSendOut(*args)
        @gp_spirit_intro = nil
        GhostlyPossession::Battle.safely("A spirit's intro") { @gp_spirit_intro = GhostlyPossession::Spirits.intro(self) }
        return super
      ensure
        @gp_spirit_intro = nil
      end

      def pbDisplayPaused(msg, &block)
        if @gp_spirit_intro && msg == @gp_spirit_intro[0]
          msg = @gp_spirit_intro[1]
          @gp_spirit_intro = nil
        end
        return super(msg, &block)
      end

      def pbEndOfRoundPhase(*args)
        ret = super
        GhostlyPossession::Battle.safely("A restless spirit") { GhostlyPossession::Spirits.end_of_round(self) }
        return ret
      end

      # it keeps its name: no nickname to ask for
      def pbStorePokemon(pkmn, *args)
        return super unless GhostlyPossession::Spirits.spirit?(pkmn) && $PokemonSystem.respond_to?(:prompt_nicknames=)
        was = $PokemonSystem.prompt_nicknames
        $PokemonSystem.prompt_nicknames = false
        begin
          return super
        ensure
          $PokemonSystem.prompt_nicknames = was
        end
      end
    end

    # KIF's Nuzlocke: a spirit's battle is free (catchable, the place kept)
    module NuzlockeFree
      def judge(*args)
        ret = super
        return ret unless ret.is_a?(Array) && GhostlyPossession::Spirits.active?
        return [ret[0], :free]
      end
    end

    # Haunted Wilds never takes a spirit
    module NoHaunting
      def candidate(*args)
        return nil if GhostlyPossession::Spirits.active?
        return super
      end
    end

    # Never an alpha (Alpha Encounters makes one inside its own battle start,
    # and sets its lava backdrop), never handed to a partner trainer. The
    # game's (and Alpha's) are private methods of every object: these are
    # too, and each is added only when the one it wraps is there.
    module NoAlpha
      private

      def make_alpha(pokemon, *args)
        return nil if GhostlyPossession::Spirits.spirit?(pokemon)
        return super
      end
    end

    module NoLava
      private

      def setBattleRule(*args)
        st = GhostlyPossession::Spirits.battle_state
        return nil if st && !st[:started] && args[0].to_s == "backdrop" && args[1].to_s == "lava"
        return super
      end
    end

    module NoPartner
      private

      def promptGiveToPartner(pkmn, *args)
        return false if GhostlyPossession::Spirits.spirit?(pkmn)
        return super
      end
    end

    # A spirit that came back stays a Ghost: every unfuse (the party, the PC,
    # the Splicers) goes through the game's pbUnfuse
    module NoUnfuse
      private

      def pbUnfuse(pokemon, scene, *args)
        return super unless GhostlyPossession::Spirits.bound?(pokemon)
        msg = _INTL("{1}'s spirit is bound to its Ghost. It can't be unfused.", pokemon.name)
        scene && scene.respond_to?(:pbDisplay) ? scene.pbDisplay(msg) : pbMessage(msg)
        return false
      end
    end

    def bound?(pkmn)
      return pkmn.respond_to?(:instance_variable_defined?) && pkmn.instance_variable_defined?(MARK) &&
             pkmn.instance_variable_get(MARK) ? true : false
    end

    def object_hooks
      { NoAlpha => :make_alpha, NoLava => :setBattleRule, NoPartner => :promptGiveToPartner, NoUnfuse => :pbUnfuse }.each do |mod, name|
        next if ::Object.ancestors.include?(mod)
        next unless ::Object.private_method_defined?(name) || ::Object.method_defined?(name)
        ::Object.prepend(mod)
      end
    end

    #--------------------------------------------------------------------------
    # The Debug menu: a grave in front of you (one of the fallen, else your
    # lead Pokémon's spirit, for trying it out)
    #--------------------------------------------------------------------------
    def debug_grave
      pbMessage(debug_grave_words)
    end

    # (its words returned: the Kanto Reloaded Debug mod's page calls this)
    def debug_grave_words
      return _INTL("There's no map to put a grave on.") unless $game_map && $game_player
      dx, dy = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }[$game_player.direction] || [0, 1]
      x, y = $game_player.x + dx, $game_player.y + dy
      unless $game_map.valid?(x, y) && $game_map.passable?(x, y, 0) && !$game_map.events.values.any? { |e| e.x == x && e.y == y }
        return _INTL("There's no room for a grave in front of you.")
      end
      remove_grave if grave
      f = choose
      unless f
        lead = $Trainer && $Trainer.party.compact.find { |p| !p.egg? }
        return _INTL("No fallen Pokémon, and no Pokémon to stand in for one.") unless lead
        copy = Marshal.load(Marshal.dump(lead))
        copy.remove_instance_variable(Note::IVAR) if copy.instance_variable_defined?(Note::IVAR)
        @debug = { :key => "debug#{rand(1_000_000)}", :name => copy.name, :species => copy.species, :level => copy.level,
                   :place => (::KIF::Nuzlocke.place_name($game_map.map_id) rescue "here"), :pokemon => copy }
        f = @debug
      end
      @debug_any = true
      place_grave(x, y, f)
      @debug_any = false
      return _INTL("A grave for {1}, in front of you.", f[:name])
    end

    def debug_menu
      return unless defined?(::DebugMenuCommands)
      ::DebugMenuCommands.register("ghostly_possession_grave", {
        "parent"      => "ghostly_possession",
        "name"        => _INTL("A Grave Here"),
        "description" => _INTL("A Restless Spirits grave in front of you: one of the Nuzlocke's fallen, else your lead Pokémon's spirit (to try it out; nothing is changed for real)."),
        "effect"      => proc { GhostlyPossession::Spirits.debug_grave }
      })
    end

    def boot
      ::PokeBattle_Battle.prepend(BattleHooks) if defined?(::PokeBattle_Battle) && !::PokeBattle_Battle.ancestors.include?(BattleHooks)
      if defined?(::KIF::Nuzlocke) && ::KIF::Nuzlocke.respond_to?(:judge) &&
         !::KIF::Nuzlocke.singleton_class.ancestors.include?(NuzlockeFree)
        ::KIF::Nuzlocke.singleton_class.prepend(NuzlockeFree)
      end
      ::GhostlyPossession::Wilds.singleton_class.prepend(NoHaunting) unless ::GhostlyPossession::Wilds.singleton_class.ancestors.include?(NoHaunting)
      object_hooks
      if defined?(::SaveData) && ::SaveData.respond_to?(:save_to_file) && !::SaveData.singleton_class.ancestors.include?(SaveLift)
        ::SaveData.singleton_class.prepend(SaveLift)
      end
      unless @booted
        if defined?(::Events)
          ::Events.onMapUpdate += proc { |_sender, _e| GhostlyPossession::Spirits.update }
          ::Events.onMapSceneChange += proc { |_sender, _e| GhostlyPossession::Spirits.tidy }
        end
        @booted = true
      end
      debug_menu
      return true
    end
  end
end
