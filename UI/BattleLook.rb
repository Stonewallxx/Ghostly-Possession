#==============================================================================
# Ghostly Possession: the battle look
#==============================================================================
# A possessed Pokémon in battle (Aura and a Mark, his pick 2026-10-24; the
# Ghost Badge on its move, his pick 2026-10-25). PIF's battle screen, and
# EBDX's when it's on (the same marks, on its screens):
#
#   the aura      a pulsing purple outline round its sprite and a
#                 see-through purple double behind it, risen up and swaying
#                 (Outline and Echo, his pick 2026-10-25; the Aura setting:
#                 both, or one); it follows the sprite (bobbing, EBDX's
#                 camera), its frame, opacity and visibility
#   the mark      a ghost badge on its databox, left of the name (a foe's:
#                 after it)
#   its move      the Ghost's move has the ghost badge in the Fight menu
#   control       when the Ghost takes over: the sprite flashes purple, the
#                 Ghost shows through it, "The Gastly inside Pikachu took
#                 control!" (Core/Control.rb decides)
#
# All drawn while it's the fusion (Engine.applied?), from the game's own
# sprites and bitmaps; nothing of the battle is changed.
#==============================================================================

module GhostlyPossession
  module BattleLook
    PURPLE = [170, 100, 255].freeze
    # the outline: the silhouette offset these ways, px at the base size
    OUTLINE = [[-3, 0], [3, 0], [0, -3], [0, 3], [-2, -2], [2, -2], [-2, 2], [2, 2]].freeze
    # the echo: [dx, dy] at the base size, its opacity, a little bigger, how purple
    ECHO = [12, -30].freeze
    ECHO_OPACITY = 95
    ECHO_ZOOM = 1.05
    ECHO_ALPHA = 210
    BASE = 288.0                   # the sprite height the sizes are for (EBDX's back sprites)
    THIN = 0.45                    # the aura once a wild one's grip slips
    WHITE = [240, 245, 255].freeze # the cold flash as a Ghost bursts out

    module_function

    def possessed?(pkmn)
      return pkmn && Engine.applied?(pkmn) ? true : false
    end

    #--------------------------------------------------------------------------
    # The aura (PokemonBattlerSprite: PIF's and EBDX's battlers)
    #--------------------------------------------------------------------------
    # Outline and Echo (his pick 2026-10-25; the Aura setting shows both or
    # one): purple silhouettes of the battler's own picture behind it. The
    # outline round it, pulsing; the echo a see-through double, risen up
    # and swaying, the Ghost half out of it. They copy the sprite each time
    # it moves or changes (its frame, mirroring, zoom, opacity, visibility).
    class Aura
      def initialize(viewport)
        @echo = Sprite.new(viewport)
        @echo.color = Color.new(*PURPLE, ECHO_ALPHA)
        @outline = OUTLINE.map do
          s = Sprite.new(viewport)
          s.color = Color.new(*PURPLE, 255)
          s
        end
      end

      # thin: a wild one's grip slipping (the aura at THIN of itself); echo
      # only: on an alpha (Both, Keep the Alpha, his pick 2026-10-24: the
      # alpha's look stays clear)
      def sync(sprite, x, y, thin = false, echo_only = false)
        style = echo_only ? 2 : Settings.aura   # 0 Both, 1 Outline, 2 Echo
        shown = sprite.visible && !sprite.disposed? && sprite.bitmap
        t = Graphics.frame_count
        scale = sprite.src_rect.height * sprite.zoom_y / BASE
        pulse = 0.75 + 0.25 * Math.sin(t * 0.08)
        strength = thin ? THIN : 1.0
        @outline.each_with_index do |s, i|
          dx, dy = OUTLINE[i]
          copy(sprite, s, x + step(dx, scale), y + step(dy, scale), shown && style != 2)
          s.opacity = (sprite.opacity * 220 / 255.0 * pulse * strength).round
        end
        sway = 6 * Math.sin(t * 0.05)
        copy(sprite, @echo, x + ((ECHO[0] + sway) * scale).round, y + ((ECHO[1] - 5 * Math.sin(t * 0.07)) * scale).round,
             shown && style != 1)
        @echo.zoom_x = sprite.zoom_x * ECHO_ZOOM
        @echo.zoom_y = sprite.zoom_y * ECHO_ZOOM
        @echo.opacity = (sprite.opacity * ECHO_OPACITY / 255.0 * strength).round
      end

      # an offset at this size, at least a pixel
      def step(d, scale)
        return 0 if d == 0
        v = (d * scale).round
        return v == 0 ? (d <=> 0) : v
      end

      def copy(sprite, s, x, y, shown)
        s.bitmap = sprite.bitmap unless s.bitmap.equal?(sprite.bitmap)
        r = sprite.src_rect
        s.src_rect.set(r.x, r.y, r.width, r.height)
        s.ox = sprite.ox
        s.oy = sprite.oy
        s.mirror = sprite.mirror
        s.zoom_x = sprite.zoom_x
        s.zoom_y = sprite.zoom_y
        s.x = x
        s.y = y
        s.z = sprite.z - 1
        s.visible = shown ? true : false
      end

      # (the bitmaps are the battler's: not ours to dispose)
      def dispose
        ([@echo] + @outline).each do |s|
          s.bitmap = nil unless s.disposed?
          s.dispose unless s.disposed?
        end
      end
    end

    module BattlerSprite
      def update(*args)
        ret = super
        gp_aura
        return ret
      end

      [:x=, :y=, :z=, :visible=, :opacity=, :zoom_x=, :zoom_y=].each do |m|
        define_method(m) do |value|
          super(value)
          gp_aura if @gp_aura
          value
        end
      end

      def dispose
        gp_aura_off
        super
      end

      def gp_aura
        return gp_aura_off unless !disposed? && self.bitmap && GhostlyPossession::BattleLook.possessed?(@pkmn)
        @gp_aura ||= GhostlyPossession::BattleLook::Aura.new(self.viewport)
        @gp_aura.sync(self, @spriteX.to_i + @spriteXExtra.to_i, @spriteY.to_i + @spriteYExtra.to_i,
                      GhostlyPossession::WildBattle.slipping?(@pkmn), GhostlyPossession::Wilds.alpha?(@pkmn))
      rescue StandardError => e
        gp_aura_off
        GhostlyPossession.log("The aura couldn't be drawn: #{e.class}: #{e.message}")
      end

      def gp_aura_off
        @gp_aura.dispose if @gp_aura
        @gp_aura = nil
      end
    end

    #--------------------------------------------------------------------------
    # The mark on the databox
    #--------------------------------------------------------------------------
    # PIF's: drawn on the box's own bitmap after it's drawn (left of your
    # Pokémon's name; after a foe's)
    module DataBox
      def refresh(*args)
        ret = super
        GhostlyPossession::BattleLook.mark_pif(self, @battler, @spriteBaseX.to_i)
        return ret
      end
    end

    def mark_pif(box, battler, base_x)
      return unless battler && possessed?(battler.pokemon) && box.bitmap && !box.bitmap.disposed?
      gold = WildBattle.slipping?(battler.pokemon)
      if battler.opposes?(0)
        w = box.bitmap.text_size(battler.name).width
        Shapes.badge(box.bitmap, [base_x + 8 + w + 10, base_x + 106].min, 8, 2, gold)
      else
        Shapes.badge(box.bitmap, base_x - 28, 8, 2, gold)
      end
    rescue StandardError => e
      GhostlyPossession.log("The databox mark couldn't be drawn: #{e.class}: #{e.message}")
    end

    # EBDX's: a little sprite of the box's own (it moves, fades and hides
    # with the box), just left of where EBDX draws the name: EBDX moves a
    # long name left (name, gender and level wider than the HP bar), and
    # the mark goes with it (his ask, 2026-10-24: it touched the name)
    MARK_GAP = 4                   # px between the mark and the name (its outline takes one)

    module EBDXDataBox
      def setUp(*args)
        ret = super
        GhostlyPossession::BattleLook.mark_sprite_ebdx(@sprites, @viewport)
        return ret
      end

      def refresh(*args)
        ret = super
        GhostlyPossession::BattleLook.mark_ebdx(@sprites, @battler, @pokemon, @hpBarWidth.to_i, @hidden)
        return ret
      end
    end

    def mark_sprite_ebdx(sprites, viewport)
      name = sprites && sprites["textName"]
      return unless name
      s = Sprite.new(viewport)
      s.bitmap = Bitmap.new(15, 15)
      s.z = name.z
      s.ex = name.ex
      s.ey = name.ey.to_i + 4
      sprites["gpMark"] = s
    rescue StandardError => e
      GhostlyPossession.log("The EBDX databox mark couldn't be made: #{e.class}: #{e.message}")
    end

    def mark_ebdx(sprites, battler, pokemon, bar_width, hidden)
      s = sprites && sprites["gpMark"]
      return unless s && s.bitmap && !s.bitmap.disposed?
      s.bitmap.clear
      return unless battler && possessed?(battler.pokemon)
      Shapes.badge(s.bitmap, 0, 0, 1, WildBattle.slipping?(battler.pokemon))
      # where EBDX draws the name: 18 px in, less its shift for a long one
      name = sprites["textName"]
      gender = ""
      gender = "♂" if pokemon && pokemon.gender == 0 && !hidden
      gender = "♀" if pokemon && pokemon.gender == 1 && !hidden
      level = pokemon ? pokemon.level : battler.level
      w = name.bitmap.text_size("#{battler.name}#{gender}Lv.#{level}").width
      shift = w > bar_width + 4 ? ((w - (bar_width + 4)) / 2.0).ceil : 0
      s.ex = name.ex + 18 - shift - MARK_GAP - 15
      s.ey = name.ey.to_i + 4
      base = sprites["base"]
      if base
        s.x = base.x + s.ex
        s.y = base.y + s.ey
      end
    rescue StandardError => e
      GhostlyPossession.log("The EBDX databox mark couldn't be drawn: #{e.class}: #{e.message}")
    end

    #--------------------------------------------------------------------------
    # The Ghost's move in the Fight menu
    #--------------------------------------------------------------------------
    # PIF's: the badge on the left of its button (the names' overlay)
    module FightMenu
      def refreshButtonNames(*args)
        ret = super
        GhostlyPossession::BattleLook.badge_pif(self, @battler, @buttons, @pokemon_name_overlay, @visibility)
        return ret
      end
    end

    def badge_pif(menu, battler, buttons, overlay, visibility)
      slot = Control.ghost_slot(battler)
      return unless slot && buttons && overlay && !overlay.disposed?
      return if visibility && !visibility["button_#{slot}"]
      button = buttons[slot]
      return unless button
      Shapes.badge(overlay.bitmap, button.x - menu.x + 10, button.y - menu.y + 11)
    rescue StandardError => e
      GhostlyPossession.log("The Fight menu's ghost badge couldn't be drawn: #{e.class}: #{e.message}")
    end

    # EBDX's: on its button's bitmap (both halves: shown and chosen)
    module EBDXFightWindow
      def generateButtons(*args)
        ret = super
        GhostlyPossession::BattleLook.badge_ebdx(@battler, @button)
        return ret
      end
    end

    def badge_ebdx(battler, buttons)
      slot = Control.ghost_slot(battler)
      button = slot && buttons ? buttons["#{slot}"] : nil
      return unless button && button.bitmap && !button.bitmap.disposed?
      # the chosen half (the big one, its inner box) a little lower and
      # further in, off the box's edge (his ask, 2026-10-25); the other half
      Shapes.badge(button.bitmap, 14, 16)
      Shapes.badge(button.bitmap, 208, 12)
    rescue StandardError => e
      GhostlyPossession.log("EBDX's ghost badge couldn't be drawn: #{e.class}: #{e.message}")
    end

    #--------------------------------------------------------------------------
    # The Ghost takes control: the flash, the Ghost showing through, the words
    #--------------------------------------------------------------------------
    def took_control(battle, battler)
      note = Note.read(battler.pokemon)
      return unless note
      scene = battle.scene
      sprite = scene.respond_to?(:sprites) && scene.sprites ? scene.sprites["pokemon_#{battler.index}"] : nil
      ghost = through(sprite, PartyLook.ghost_of(battler.pokemon), !battler.opposes?(0))
      pbSEPlay("Anim/PRSFX- Curse", 80) rescue nil
      begin
        animate(scene, 12) { |k| look(sprite, ghost, 170 * k, 160 * k) }
        battle.pbDisplay(_INTL("The {1} inside {2} took control!", UI.ghost_name(note), battler.name))
        animate(scene, 10) { |k| look(sprite, ghost, 170 * (1 - k), 160 * (1 - k)) }
      ensure
        # a fresh Color: EBDX's animations change a sprite's own Color in place
        sprite.color = Color.new(0, 0, 0, 0) if sprite && !sprite.disposed?
        if ghost
          ghost.bitmap.dispose if ghost.bitmap && !ghost.bitmap.disposed?
          ghost.dispose unless ghost.disposed?
        end
      end
    end

    #--------------------------------------------------------------------------
    # A wild one's Ghost bursts out (Its Own Battle Next, his pick
    # 2026-10-24): a cold white light on it and the Ghost showing; the change
    # (the block: it's itself again); then the Ghost rises away and fades
    #--------------------------------------------------------------------------
    def burst(battle, battler, note)
      scene = battle.scene
      sprite = scene.respond_to?(:sprites) && scene.sprites ? scene.sprites["pokemon_#{battler.index}"] : nil
      ghost = through(sprite, PartyLook.ghost_of(battler.pokemon), false)
      pbSEPlay("Anim/PRSFX- Hex", 80) rescue nil
      begin
        animate(scene, 14) { |k| cold(sprite, ghost, 200 * k, 220 * k, 0) }
        yield
        animate(scene, 26) { |k| cold(sprite, ghost, 200 * (1 - k), 220 * (1 - k), (52 * k).round) }
      ensure
        sprite.color = Color.new(0, 0, 0, 0) if sprite && !sprite.disposed?
        if ghost
          ghost.bitmap.dispose if ghost.bitmap && !ghost.bitmap.disposed?
          ghost.dispose unless ghost.disposed?
        end
      end
    end

    # The Leap: the Ghost rises out of the fainted one (from: its battler
    # index), leaps across in an arc with a faint trail, and goes into the
    # one it possesses: a purple flash, the change (the block: it's the
    # fusion) at its brightest
    LEAP_RISE = 12                 # frames the Ghost takes to show
    LEAP_FLY = 30                  # frames across
    LEAP_ARC = 48                  # px the arc rises at its middle
    LEAP_TRAIL = [0.1, 0.2].freeze # how far behind the trail's copies are

    def leapt(battle, battler, from = nil, note = nil)
      scene = battle.scene
      sprites = scene.respond_to?(:sprites) && scene.sprites ? scene.sprites : {}
      sprite = sprites["pokemon_#{battler.index}"]
      source = from ? sprites["pokemon_#{from}"] : nil
      ghost = note && source && sprite ? leaper(source, sprite, UI.ghost_pokemon(note, battler.pokemon.level)) : nil
      trail = ghost ? LEAP_TRAIL.map { leaper_copy(ghost) } : []
      pbSEPlay("Anim/PRSFX- Curse", 80) rescue nil
      begin
        if ghost
          place = proc do |k, s|
            e = k * k * (3 - 2 * k)
            sx, sy = middle(source)
            tx, ty = middle(sprite)
            s.x = (sx + (tx - sx) * e).round
            s.y = (sy + (ty - sy) * e - Math.sin(Math::PI * k) * LEAP_ARC).round
            s.zoom_x = s.zoom_y = source.zoom_x + (sprite.zoom_x - source.zoom_x) * e
          end
          place.call(0, ghost)
          animate(scene, LEAP_RISE) { |k| ghost.opacity = (230 * k).round }
          animate(scene, LEAP_FLY) do |k|
            place.call(k, ghost)
            trail.each_with_index do |s, i|
              place.call([k - LEAP_TRAIL[i], 0].max, s)
              s.opacity = k > LEAP_TRAIL[i] ? 90 - 30 * i : 0
            end
          end
          trail.each { |s| s.opacity = 0 }
        end
        animate(scene, 10) do |k|
          look(sprite, nil, 190 * k, 0)
          ghost.opacity = (230 * (1 - k)).round if ghost
        end
        yield
        animate(scene, 16) { |k| look(sprite, nil, 190 * (1 - k), 0) }
      ensure
        sprite.color = Color.new(0, 0, 0, 0) if sprite && !sprite.disposed?
        trail.each { |s| s.dispose unless s.disposed? }
        if ghost
          ghost.bitmap.dispose if ghost.bitmap && !ghost.bitmap.disposed?
          ghost.dispose unless ghost.disposed?
        end
      end
    end

    # A battler sprite's middle on screen (its picture's, whatever its origin
    # or how much of it shows)
    def middle(s)
      h = (s.bitmap ? s.bitmap.height : 0) * s.zoom_y
      return [s.x, s.y - s.oy * s.zoom_y + h / 2]
    end

    # The leaping Ghost: its front picture, a little purple, over both
    def leaper(source, target, ghost_pkmn)
      return nil unless ghost_pkmn
      anim = ::GameData::Species.sprite_bitmap_from_pokemon(ghost_pkmn, false)
      return nil unless anim
      anim.scale_bitmap(::Settings::FRONTSPRITE_SCALE) if anim.respond_to?(:scale_bitmap)
      s = Sprite.new(source.viewport)
      s.bitmap = anim.bitmap.clone
      anim.dispose if anim.respond_to?(:dispose)
      s.ox = s.bitmap.width / 2
      s.oy = s.bitmap.height / 2
      s.z = [source.z, target.z].max + 5
      s.color = Color.new(*PURPLE, 70)
      s.opacity = 0
      return s
    rescue StandardError => e
      GhostlyPossession.log("The leaping Ghost couldn't be shown: #{e.class}: #{e.message}")
      return nil
    end

    # A faint copy for its trail (the same picture)
    def leaper_copy(ghost)
      s = Sprite.new(ghost.viewport)
      s.bitmap = ghost.bitmap
      s.ox = ghost.ox
      s.oy = ghost.oy
      s.z = ghost.z - 1
      s.color = Color.new(*PURPLE, 160)
      s.opacity = 0
      return s
    end

    def cold(sprite, ghost, light, ghost_alpha, rise)
      sprite.color = Color.new(*WHITE, light.round) if sprite && !sprite.disposed?
      return unless ghost && !ghost.disposed?
      ghost.opacity = ghost_alpha.round
      from = ghost.instance_variable_get(:@gp_from_y) || ghost.instance_variable_set(:@gp_from_y, ghost.y)
      ghost.y = from - rise
    end

    # frames of a tween, k from 0 to 1
    def animate(scene, frames)
      frames.times do |i|
        yield((i + 1).to_f / frames)
        scene.respond_to?(:pbUpdate) ? scene.pbUpdate : Graphics.update
      end
    end

    def look(sprite, ghost, flash, ghost_alpha)
      sprite.color = Color.new(*PURPLE, flash.round) if sprite && !sprite.disposed?
      ghost.opacity = ghost_alpha.round if ghost && !ghost.disposed?
    end

    # The Ghost's battle sprite over the battler's, a little above it (the
    # player's side mirrored, as PIF shows backs)
    def through(sprite, ghost_pkmn, own)
      return nil unless sprite && !sprite.disposed? && ghost_pkmn && sprite.bitmap
      anim = ::GameData::Species.sprite_bitmap_from_pokemon(ghost_pkmn, own)
      return nil unless anim
      anim.scale_bitmap(own ? ::Settings::BACKRPSPRITE_SCALE : ::Settings::FRONTSPRITE_SCALE) if anim.respond_to?(:scale_bitmap)
      s = Sprite.new(sprite.viewport)
      s.bitmap = anim.bitmap.clone
      anim.dispose if anim.respond_to?(:dispose)
      s.mirror = own
      s.ox = s.bitmap.width / 2
      s.oy = s.bitmap.height
      s.x = sprite.x
      s.y = sprite.y - 16
      s.zoom_x = sprite.zoom_x
      s.zoom_y = sprite.zoom_y
      s.z = sprite.z + 2
      s.opacity = 0
      return s
    rescue StandardError => e
      GhostlyPossession.log("The Ghost couldn't show through: #{e.class}: #{e.message}")
      return nil
    end

    def boot
      ::PokemonBattlerSprite.prepend(BattlerSprite) if defined?(::PokemonBattlerSprite) && !::PokemonBattlerSprite.ancestors.include?(BattlerSprite)
      ::PokemonDataBox.prepend(DataBox) if defined?(::PokemonDataBox) && !::PokemonDataBox.ancestors.include?(DataBox)
      ::FightMenuDisplay.prepend(FightMenu) if defined?(::FightMenuDisplay) && !::FightMenuDisplay.ancestors.include?(FightMenu)
      if defined?(::DataBoxEBDX) && ::DataBoxEBDX.method_defined?(:refresh) && ::DataBoxEBDX.method_defined?(:setUp) &&
         !::DataBoxEBDX.ancestors.include?(EBDXDataBox)
        ::DataBoxEBDX.prepend(EBDXDataBox)
      end
      if defined?(::FightWindowEBDX) && ::FightWindowEBDX.method_defined?(:generateButtons) && !::FightWindowEBDX.ancestors.include?(EBDXFightWindow)
        ::FightWindowEBDX.prepend(EBDXFightWindow)
      end
      return true
    end
  end
end
