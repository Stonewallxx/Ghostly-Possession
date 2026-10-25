#==============================================================================
# Ghostly Possession: a possessed walking wild on the map
#==============================================================================
# With Hoenn Overworld Encounters (Core/Compat.rb), a walking wild with a
# Ghost inside shows the battle's aura on the map (Outline and Echo, his pick
# 2026-10-24; the Aura setting picks both or one): purple silhouettes of its
# own picture a pixel round it, pulsing, and one see-through purple double
# risen up and to the side, swaying. Raised further than in battle, so it
# reads at the map's size.
#
# Drawn by its Sprite_Character, copying its frame, place, grass cut and
# fade every update; the sprites belong to the Sprite_Character (never
# saved, gone with it), under Hoenn's red alpha outline.
#==============================================================================

module GhostlyPossession
  module MapAura
    PURPLE = [170, 100, 255].freeze
    OUTLINE = [[-1, 0], [1, 0], [0, -1], [0, 1], [-1, -1], [1, -1], [-1, 1], [1, 1]].freeze
    ECHO = [5, -12].freeze         # risen up and to the side (px)
    ECHO_OPACITY = 125
    ECHO_ZOOM = 1.05
    ECHO_ALPHA = 210
    SWAY = 2                       # px the echo sways each way
    IVAR = :@gp_map_aura

    module_function

    def wanted?(ch)
      return false unless ch && defined?(::OverworldPokemonEvent) && ch.is_a?(::OverworldPokemonEvent)
      return Compat.possessed_ow?(ch) && Compat.on_map?(ch)
    end

    # Every update, after the game's: the aura on it, or put away
    def follow(s, ch)
      aura = s.instance_variable_get(IVAR)
      unless wanted?(ch)
        off(s) if aura
        return
      end
      aura = make(s) if !aura || aura.any?(&:disposed?)
      style = Settings.aura                  # 0 Both, 1 Outline, 2 Echo
      shown = !s.disposed? && s.bitmap && s.visible && s.opacity > 0 ? true : false
      t = Graphics.frame_count
      pulse = 0.8 + 0.2 * Math.sin(t * 0.08)
      aura.each_with_index do |sp, i|
        copy(s, sp)
        if i < OUTLINE.length
          sp.x = s.x + OUTLINE[i][0]
          sp.y = s.y + OUTLINE[i][1]
          sp.z = s.z - 2
          sp.opacity = (s.opacity * 210 / 255.0 * pulse).round
          sp.visible = shown && style != 2
        else
          sp.zoom_x = s.zoom_x * ECHO_ZOOM
          sp.zoom_y = s.zoom_y * ECHO_ZOOM
          sp.x = s.x + ECHO[0] + (SWAY * Math.sin(t * 0.05)).round
          sp.y = s.y + ECHO[1]
          sp.z = s.z - 3
          sp.opacity = (s.opacity * ECHO_OPACITY / 255.0).round
          sp.visible = shown && style != 1
        end
      end
    rescue StandardError => e
      off(s)
      GhostlyPossession.log("A walking wild's aura couldn't be drawn: #{e.class}: #{e.message}")
    end

    def make(s)
      off(s)
      aura = (OUTLINE.length + 1).times.map do |i|
        sp = Sprite.new(s.viewport)
        sp.color = i < OUTLINE.length ? Color.new(*PURPLE, 255) : Color.new(*PURPLE, ECHO_ALPHA)
        sp.visible = false
        sp
      end
      s.instance_variable_set(IVAR, aura)
      return aura
    end

    # Its picture as it shows now (the bitmap is the game's: never disposed here)
    def copy(s, sp)
      sp.bitmap = s.bitmap unless sp.bitmap.equal?(s.bitmap)
      r = s.src_rect
      sp.src_rect.set(r.x, r.y, r.width, r.height)
      sp.ox = s.ox
      sp.oy = s.oy
      sp.zoom_x = s.zoom_x
      sp.zoom_y = s.zoom_y
      sp.mirror = s.mirror if sp.respond_to?(:mirror=)
    end

    def off(s)
      aura = s.instance_variable_get(IVAR)
      return unless aura
      aura.each do |sp|
        next if sp.disposed?
        sp.bitmap = nil
        sp.dispose
      end
      s.instance_variable_set(IVAR, nil)
    end

    module CharacterSprite
      def update(*args)
        ret = super
        GhostlyPossession::MapAura.follow(self, @character)
        return ret
      end

      def dispose(*args)
        GhostlyPossession::MapAura.off(self)
        return super
      end
    end

    def boot
      return true unless Compat.hoenn? && defined?(::Sprite_Character)
      ::Sprite_Character.prepend(CharacterSprite) unless ::Sprite_Character.ancestors.include?(CharacterSprite)
      return true
    end
  end
end
