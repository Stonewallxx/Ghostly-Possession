#==============================================================================
# Ghostly Possession: possessed Pokémon on KIF's title
#==============================================================================
# KIF 1.2's Living title (F-UI-12_LivingTitle) has Pokémon wandering KIF's
# world. With Ghostly Possession, now and then one of them has a Ghost
# inside (his ask, 2026-10-25; his pick: the Outline and Echo look, as in
# battle): a pulsing purple outline round it and a see-through purple
# double risen behind it, swaying. The Aura setting (all saves) picks both,
# or one, as in battle; the per-save ones aren't loaded on the title.
#
# Drawn from the wanderer's own sheet (sprites coloured purple), following
# its frame, place, size and tall grass every frame; walkers only (not the
# two that fuse, the diggers or the flyers), and not one Kanto Reloaded made
# an Alpha. Works with or without Kanto Reloaded.
#==============================================================================

module GhostlyPossession
  module TitleLook
    CHANCE = 10                    # one wanderer in this many
    PURPLE = [170, 100, 255].freeze
    # the outline: the silhouette offset these ways (px, at the title's size)
    OUTLINE = [[-2, 0], [2, 0], [0, -2], [0, 2], [-2, -2], [2, -2], [-2, 2], [2, 2]].freeze
    # the echo: risen and to the side (px), its opacity, a little bigger, how purple
    ECHO = [4, -10].freeze
    ECHO_OPACITY = 95
    ECHO_ZOOM = 1.05
    ECHO_ALPHA = 210
    SWAY = 3                       # px the echo sways each way

    module_function

    def boot
      return true unless defined?(::KifLivingTitle)
      ::KifLivingTitle.prepend(Title) unless ::KifLivingTitle.ancestors.include?(Title)
      return true
    end

    # KIF just dressed a wanderer: now and then a Ghost is inside it
    def dressed(screen, actor)
      possessed = actor.kind == :walk && !actor.instance_variable_get(:@kr_alpha) && rand(CHANCE) == 0
      actor.instance_variable_set(:@gp_possessed, possessed)
    rescue StandardError => e
      GhostlyPossession.log("A title screen wanderer couldn't be dressed: #{e.message}")
    end

    # Every frame, after KIF drew it: the aura on it, or put away
    def follow(screen, actor)
      s = actor.sprite
      aura = actor.instance_variable_get(:@gp_aura)
      on = actor.instance_variable_get(:@gp_possessed) && s && !s.disposed? && s.visible && s.bitmap
      unless on
        aura.each { |sp| sp.visible = false unless sp.disposed? } if aura
        return
      end
      aura ||= make(screen, actor)
      style = Settings.aura                    # 0 Both, 1 Outline, 2 Echo
      t = Graphics.frame_count / 40.0
      zoom = s.zoom_x.to_f
      outline, echo = aura[0, OUTLINE.length], aura.last
      pulse = (200 + 55 * Math.sin(t * 3)).round
      outline.each_with_index do |sp, i|
        copy(s, sp)
        sp.x = s.x + (OUTLINE[i][0] * zoom).round
        sp.y = s.y + (OUTLINE[i][1] * zoom).round
        sp.z = s.z - 1
        sp.opacity = pulse
        sp.visible = style != 2
      end
      copy(s, echo)
      echo.zoom_x = echo.zoom_y = zoom * ECHO_ZOOM
      echo.x = s.x + ((ECHO[0] + Math.sin(t * 2) * SWAY) * zoom).round
      echo.y = s.y + (ECHO[1] * zoom).round
      echo.z = s.z - 2
      echo.opacity = ECHO_OPACITY
      echo.color = Color.new(*PURPLE, ECHO_ALPHA)
      echo.visible = style != 1
    rescue StandardError => e
      GhostlyPossession.log("A possessed wanderer's aura couldn't be drawn: #{e.message}")
    end

    # Its outline and echo: sprites in the title's viewport, kept with KIF's
    # own (KIF disposes them with the title)
    def make(screen, actor)
      sprites = screen.instance_variable_get(:@sprites)
      vp = actor.sprite.viewport
      aura = (OUTLINE.length + 1).times.map do |i|
        sp = Sprite.new(vp)
        sp.color = Color.new(*PURPLE, 255)
        sp.visible = false
        sprites["gp_#{actor.sprite.object_id}_#{i}"] = sp if sprites
        sp
      end
      actor.instance_variable_set(:@gp_aura, aura)
      return aura
    end

    # The wanderer's picture as it shows now: frame, origin, size, grass
    def copy(s, sp)
      sp.bitmap = s.bitmap unless sp.bitmap.equal?(s.bitmap)
      r = s.src_rect
      sp.src_rect.set(r.x, r.y, r.width, r.height)
      sp.ox = s.ox
      sp.oy = s.oy
      sp.zoom_x = s.zoom_x
      sp.zoom_y = s.zoom_y
      sp.bush_depth = s.bush_depth.to_i if sp.respond_to?(:bush_depth=)
    end

    # On KifLivingTitle (prepended)
    module Title
      def dress(*args)
        result = super
        GhostlyPossession::TitleLook.dressed(self, args[0])
        result
      end

      def draw_actor(*args)
        result = super
        GhostlyPossession::TitleLook.follow(self, args[0])
        result
      end
    end
  end
end
