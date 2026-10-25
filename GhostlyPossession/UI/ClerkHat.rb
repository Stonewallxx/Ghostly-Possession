#==============================================================================
# Ghostly Possession: the Poké Mart clerks' Witchy Hat
#==============================================================================
# While the Spooky Season is On, the Poké Mart clerks wear the Witchy Hat
# they hand out on 31 October (his picks 2026-10-25: all Spooky Season, the
# hat lifted 8 px). The clerks in the green apron (BW (85)) whose event runs
# a Mart: its page opens the shop or gives the hats, or calls a common event
# that does (the game's PokéMart). The clerk who hands the hats out in her
# own blue hat (BW (84)) keeps hers.
#
# The game's own hat art (the player's overworld Witchy Hat, one frame per
# facing, on the same 80 px frames as the clerk), drawn by the clerk's
# Sprite_Character over it every update: its facing, place, fade and tint.
# The sprite belongs to the Sprite_Character (never saved, gone with it);
# the maps and the clerks' pictures aren't changed.
#==============================================================================

module GhostlyPossession
  module ClerkHat
    CLERK = "BW (85)"
    HAT = "Graphics/Characters/player/hat/witchyhat/hat_witchyhat"
    LIFT = 8                       # px above where the player wears it (the clerk's head sits lower)
    ROWS = { 2 => 0, 4 => 1, 6 => 2, 8 => 3 }.freeze   # the hat's rows by facing
    MART = /pbPokemonMart|give_date_specific_hats/
    IVAR = :@gp_clerk_hat
    @hat = nil
    @mart_events = nil

    module_function

    def hat_bitmap
      return @hat if @hat && !@hat.disposed?
      @hat = Bitmap.new(HAT)
    rescue StandardError
      return nil
    end

    # (a script's text: its first line and the lines that go on from it)
    def mart_script?(list)
      text = Array(list).select { |c| c && [355, 655].include?(c.code) }.map { |c| c.parameters[0].to_s }
      return MART.match?(text.join("\n"))
    end

    # The common events that open a Mart (the game's PokéMart)
    def mart_events
      return @mart_events if @mart_events
      @mart_events = {}
      Array($data_common_events).each { |ce| @mart_events[ce.id] = true if ce && mart_script?(ce.list) }
      return @mart_events
    rescue StandardError
      return @mart_events = {}
    end

    # (each page's answer kept: every character sprite asks every frame)
    def mart_page?(list)
      return false unless list
      @pages ||= {}.compare_by_identity
      @pages.clear if @pages.length > 256
      return @pages.fetch(list) do
        @pages[list] = mart_script?(list) || list.any? { |c| c && c.code == 117 && mart_events[c.parameters[0]] }
      end
    end

    def wanted?(ch)
      return false unless ch && ch.respond_to?(:character_name) && ch.character_name == CLERK
      return false unless defined?(::Game_Event) && ch.is_a?(::Game_Event) && Settings.season?
      return mart_page?(ch.list)
    end

    # Every update, after the game's: the hat on it, or put away
    def follow(s, ch)
      hat = s.instance_variable_get(IVAR)
      unless wanted?(ch)
        off(s) if hat
        return
      end
      bmp = hat_bitmap
      return off(s) unless bmp
      if !hat || hat.disposed?
        hat = Sprite.new(s.viewport)
        hat.bitmap = bmp
        s.instance_variable_set(IVAR, hat)
      end
      frame = bmp.width
      hat.src_rect.set(0, ROWS.fetch(ch.direction, 0) * frame, frame, frame)
      hat.ox = s.ox
      hat.oy = s.oy
      hat.zoom_x = s.zoom_x
      hat.zoom_y = s.zoom_y
      hat.x = s.x
      hat.y = s.y - (LIFT * s.zoom_y).round
      hat.z = s.z + 1
      hat.opacity = s.opacity
      hat.tone = s.tone.clone if s.tone
      hat.color = s.color.clone if s.color
      hat.visible = !s.disposed? && s.bitmap && s.visible && s.opacity > 0 ? true : false
    rescue StandardError => e
      off(s)
      GhostlyPossession.log("A Mart clerk's hat couldn't be drawn: #{e.class}: #{e.message}")
    end

    # (the hat's picture is shared: never disposed here)
    def off(s)
      hat = s.instance_variable_get(IVAR)
      return unless hat
      unless hat.disposed?
        hat.bitmap = nil
        hat.dispose
      end
      s.instance_variable_set(IVAR, nil)
    end

    module CharacterSprite
      def update(*args)
        ret = super
        GhostlyPossession::ClerkHat.follow(self, @character)
        return ret
      end

      def dispose(*args)
        GhostlyPossession::ClerkHat.off(self)
        return super
      end
    end

    def boot
      return true unless defined?(::Sprite_Character)
      ::Sprite_Character.prepend(CharacterSprite) unless ::Sprite_Character.ancestors.include?(CharacterSprite)
      return true
    end
  end
end
