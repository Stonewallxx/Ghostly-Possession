#==============================================================================
# Ghostly Possession: the party look
#==============================================================================
# A possessed Pokémon shows as the fusion on the party screen, with a mark
# you can't miss (Fusion Icon and a Ghost Mark, his pick 2026-10-24). It's
# drawn from the note: the Pokémon itself stays as it is.
#
#   On its own (the game's party screen): the fusion's icon (Big Pokémon
#   Icons too), the panel's Poké Ball ghost purple, the name lavender.
#   With Kanto Reloaded (its Party Screen): the fusion's icon and types (the
#   card is purple: Ghost is its first type), a dashed purple outline and a
#   ghost badge on the card; the details show the Ghost's picture and name,
#   (and its Overworld Menu's Party View: the fusion's picture and types, the
#   card lit ghost purple, the ghost mark by the level on a Full card),
#   top right (no POSSESSED pill: his call, 2026-10-25).
#==============================================================================

module GhostlyPossession
  module PartyLook
    GHOST_RGB = [150, 80, 230].freeze
    # the name on the game's panel (lavender, deep purple shadow)
    NAME = [Color.new(224, 184, 255), Color.new(72, 32, 112)].freeze
    GLYPH = Shapes::GHOST
    BALL_HUE = 0.76                # the ball's red, moved to ghost purple (same shading)
    @balls = {}
    @ghosts = {}

    module_function

    # The game's party ball in ghost purple (made once, kept)
    def ball(selected)
      path = "Graphics/Pictures/Party/" + (selected ? "icon_ball_sel" : "icon_ball")
      path += "_dark" if defined?(isDarkMode) && isDarkMode && pbResolveBitmap(path + "_dark")
      b = @balls[path]
      return b if b && !b.disposed?
      src = Bitmap.new(pbResolveBitmap(path) || path)
      @balls[path] = purple(src)
    rescue StandardError => e
      GhostlyPossession.log("The purple ball couldn't be made: #{e.class}: #{e.message}")
      return nil
    end

    # Each strongly coloured pixel takes the purple hue, keeping its lightness
    def purple(b)
      b.width.times do |x|
        b.height.times do |y|
          c = b.get_pixel(x, y)
          next if c.alpha == 0
          h, l, s = hls(c.red / 255.0, c.green / 255.0, c.blue / 255.0)
          next if s <= 0.25
          r, g, bl = rgb(BALL_HUE, l, [s, 0.6].max)
          b.set_pixel(x, y, Color.new((r * 255).round, (g * 255).round, (bl * 255).round, c.alpha))
        end
      end
      return b
    end

    def hls(r, g, b)
      mx = [r, g, b].max
      mn = [r, g, b].min
      l = (mx + mn) / 2.0
      return [0.0, l, 0.0] if mx == mn
      d = mx - mn
      s = l > 0.5 ? d / (2.0 - mx - mn) : d / (mx + mn)
      h = if mx == r then ((g - b) / d) % 6
          elsif mx == g then (b - r) / d + 2
          else (r - g) / d + 4
          end
      return [h / 6.0, l, s]
    end

    def rgb(h, l, s)
      q = l < 0.5 ? l * (1 + s) : l + s - l * s
      p = 2 * l - q
      return [h + 1 / 3.0, h, h - 1 / 3.0].map do |t|
        t += 1 if t < 0
        t -= 1 if t > 1
        if t < 1 / 6.0 then p + (q - p) * 6 * t
        elsif t < 0.5 then q
        elsif t < 2 / 3.0 then p + (q - p) * (2 / 3.0 - t) * 6
        else p
        end
      end
    end

    # The Ghost as a Pokémon, for its picture: one per host and Ghost, so the
    # party screen keeps one icon for it
    def ghost_of(pkmn)
      note = Note.read(pkmn)
      return nil unless note
      key = [Note.pid_of(pkmn), note[:ghost], note[:ghost_shiny]]
      @ghosts.clear if @ghosts.length > 12
      return @ghosts[key] ||= UI.ghost_pokemon(note, pkmn.level)
    end

    #--------------------------------------------------------------------------
    # On its own: the game's party panel
    #--------------------------------------------------------------------------
    module Panel
      def initialize(*args)
        super
        gp_look
      end

      def pokemon=(value)
        super
        gp_look
      end

      # the fusion's icon while it's possessed
      def gp_look
        @gp_possessed = @pokemon && !@pokemon.egg? && GhostlyPossession::Note.possessed?(@pokemon)
        return unless @gp_possessed && @pkmnsprite && !@pkmnsprite.disposed?
        look = GhostlyPossession::Engine.display(@pokemon)
        @pkmnsprite.pokemon = look if look
        @refreshBitmap = true
        refresh
      rescue StandardError => e
        GhostlyPossession.log("The party panel's possessed look failed: #{e.class}: #{e.message}")
      end

      # the ball purple, the name lavender (while the panel draws)
      def refresh
        return super unless @gp_possessed
        GhostlyPossession::PartyLook.with_name(@pokemon.name) { super }
        if @ballsprite && !@ballsprite.disposed? && @ballsprite.visible
          purple = GhostlyPossession::PartyLook.ball(self.selected)
          @ballsprite.bitmap = purple if purple
        end
      end
    end

    # pbDrawTextPositions colours the possessed one's name (only while its
    # panel draws)
    module NameColour
      def pbDrawTextPositions(bitmap, textpos)
        name = GhostlyPossession::PartyLook.recolour
        if name && textpos.is_a?(Array)
          done = false
          textpos = textpos.map do |t|
            next t if done || !t.is_a?(Array) || t[0] != name
            done = true
            t2 = t.dup
            t2[4], t2[5] = GhostlyPossession::PartyLook::NAME
            t2
          end
        end
        return super(bitmap, textpos)
      end
    end

    def recolour
      return @recolour
    end

    def with_name(name)
      before = @recolour
      @recolour = name
      return yield
    ensure
      @recolour = before
    end

    #--------------------------------------------------------------------------
    # With Kanto Reloaded: its Party Screen (Reloaded::PartyScene)
    #--------------------------------------------------------------------------
    module KRScene
      # (Kanto Reloaded's names in full: constants here don't come from its scene)
      KP = ::Reloaded::Pixel if defined?(::Reloaded::Pixel)
      KF = ::KIF::PixelFont if defined?(::KIF::PixelFont)

      # the fusion's types: the card and details lit Ghost purple
      def types_of(pkmn)
        look = gp_look(pkmn)
        return super(look || pkmn)
      end

      # the fusion's icon, on the card and in the details
      def icon_for(pkmn)
        return super(gp_look(pkmn) || pkmn)
      end

      def card_content(top, c, x, y, pkmn, types, i)
        super
        return unless gp_possessed?(pkmn)
        ink = GhostlyPossession::PartyLook.ink(c)
        # a dashed purple outline inside the card, a ghost badge in its corner
        paint = ::Reloaded::PartyPaint
        chamfer_outline(top, x + 3, y + 3, x + paint::CW - 3, y + paint::CH - 3, 10, ink, 3)
        fill = c[:light] ? mix(c[:panel2], ink, 0.22) : mix(c[:panel], ink, 0.3)
        KP.ui.rbox(top, x + 6, y + 6, x + 23, y + 21, 4, fill, ink)
        pixels(top, GhostlyPossession::PartyLook::GLYPH, x + 10, y + 9, ink)
      rescue StandardError => e
        GhostlyPossession.log("The possessed card couldn't be drawn: #{e.class}: #{e.message}")
      end

      # the Ghost's picture and name, top right
      def paint_details(base, top, c, pkmn)
        super
        return unless gp_possessed?(pkmn)
        ink = GhostlyPossession::PartyLook.ink(c)
        dx = ::Reloaded::PartyPaint::DX
        dw = ::Reloaded::PartyPaint::DW
        gy = ::Reloaded::PartyPaint::GY
        ghost = GhostlyPossession::PartyLook.ghost_of(pkmn)
        return unless ghost
        @kr_panel_spots << [ghost, dx + dw - 26, gy + 24, 30]
        KP.text(top, dx + dw - 56, gy + 40, 60, 12, KF.fit(KF::TINY, ghost.name.to_s.upcase, 60), ink, KF::TINY, 2)
      rescue StandardError => e
        GhostlyPossession.log("The possessed details couldn't be drawn: #{e.class}: #{e.message}")
      end

      def gp_possessed?(pkmn)
        return pkmn && !pkmn.egg? && GhostlyPossession::Note.possessed?(pkmn)
      end

      def gp_look(pkmn)
        return gp_possessed?(pkmn) ? GhostlyPossession::Engine.display(pkmn) : nil
      end
    end

    #--------------------------------------------------------------------------
    # With Kanto Reloaded: its Overworld Menu's Party View
    # (Reloaded::OverworldMenuScreen; his ask 2026-10-24)
    #--------------------------------------------------------------------------
    # A possessed one's card there, as on the Party Screen: the fusion's
    # picture (Full: its battle sprite; Compact: its icon), Ghost-first
    # types, the card lit ghost purple (its fill and its own edge) with the
    # Party Screen's dashed purple outline inside it; on a Full card the
    # ghost mark by its level, with the gender and shiny marks. Its name
    # stays its own.
    module KROverworldCards
      # the cards' pictures, made from the possessed look
      def build_cards(*args)
        @gp_looks = true
        return super
      ensure
        @gp_looks = false
      end

      def party(*args)
        list = super
        return list unless @gp_looks
        return list.map { |p| GhostlyPossession::PartyLook.look_of(p) || p }
      end

      def battle_sprite(pkmn)
        return super(GhostlyPossession::PartyLook.look_of(pkmn) || pkmn)
      end

      def types(pkmn)
        return super(GhostlyPossession::PartyLook.look_of(pkmn) || pkmn)
      end

      def paint_full(base, top, c, pkmn, x, y)
        return super unless GhostlyPossession::PartyLook.possessed?(pkmn)
        ret = super(base, top, GhostlyPossession::PartyLook.lit(c), pkmn, x, y)
        screen = ::Reloaded::OverworldMenuScreen
        GhostlyPossession::PartyLook.dashes(top, c, x, y, screen::FULL_W, screen::FULL_H)
        return ret
      end

      def paint_compact(base, top, c, pkmn, x, y)
        return super unless GhostlyPossession::PartyLook.possessed?(pkmn)
        ret = super(base, top, GhostlyPossession::PartyLook.lit(c), pkmn, x, y)
        screen = ::Reloaded::OverworldMenuScreen
        GhostlyPossession::PartyLook.dashes(top, c, x, y, screen::CARD_W, screen::CARD_H, true)
        return ret
      end

      # the ghost mark after the gender and shiny marks (the width with it)
      def marks(top, pkmn, x, y, draw = true)
        w = super
        return w unless GhostlyPossession::PartyLook.possessed?(pkmn)
        x += w + (w > 0 ? 2 : 0)
        pixels(top, GhostlyPossession::PartyLook::GLYPH, x, y - 1, GhostlyPossession::PartyLook.ink(palette)) if draw
        return w + (w > 0 ? 2 : 0) + 9
      end
    end

    def possessed?(pkmn)
      return pkmn && !(pkmn.egg? rescue true) && Note.possessed?(pkmn) ? true : false
    end

    def look_of(pkmn)
      return possessed?(pkmn) ? Engine.display(pkmn) : nil
    end

    # The Party Screen's dashed purple outline inside a card (his ask,
    # 2026-10-24), its corners cut small to follow the menu's rounded cards;
    # on a small (Compact) card, close to its edge: clear of the name above
    # and under the HP bar along its bottom
    def dashes(top, c, x, y, w, h, small = false)
      if small
        ::Reloaded::PartyPaint.chamfer_outline(top, x + 1, y + 1, x + w - 2, y + h - 1, 3, ink(c), 3)
      else
        ::Reloaded::PartyPaint.chamfer_outline(top, x + 3, y + 3, x + w - 3, y + h - 3, 4, ink(c), 3)
      end
    rescue StandardError => e
      GhostlyPossession.log("The possessed card's outline couldn't be drawn: #{e.class}: #{e.message}")
    end

    # The colours a possessed one's card is painted with: its fill and edge
    # ghost purple
    def lit(c)
      ink = ink(c)
      fill = ::Reloaded::Palette.mix(c[:panel2], ink, c[:light] ? 0.22 : 0.3)
      return c.merge(:panel2 => fill, :line => ink)
    end

    def ink(c)
      return ::Reloaded::PartyPaint.ink(c, GHOST_RGB)
    end

    def boot
      if defined?(::PokemonPartyPanel) && !::PokemonPartyPanel.ancestors.include?(Panel)
        ::PokemonPartyPanel.prepend(Panel)
      end
      ::Object.prepend(NameColour) unless ::Object.ancestors.include?(NameColour)
      if KR.on? && defined?(::Reloaded::PartyScene) && !::Reloaded::PartyScene.ancestors.include?(KRScene)
        needs = [:types_of, :icon_for, :card_content, :paint_details]
        if needs.all? { |m| ::Reloaded::PartyScene.method_defined?(m) || ::Reloaded::PartyScene.private_method_defined?(m) }
          ::Reloaded::PartyScene.prepend(KRScene)
        else
          GhostlyPossession.log("Kanto Reloaded's Party Screen has changed: the possessed look isn't drawn on it")
        end
      end
      if KR.on? && defined?(::Reloaded::OverworldMenuScreen) && !::Reloaded::OverworldMenuScreen.ancestors.include?(KROverworldCards)
        needs = [:build_cards, :party, :battle_sprite, :types, :paint_full, :paint_compact, :marks, :pixels, :palette]
        if needs.all? { |m| ::Reloaded::OverworldMenuScreen.method_defined?(m) || ::Reloaded::OverworldMenuScreen.private_method_defined?(m) }
          ::Reloaded::OverworldMenuScreen.prepend(KROverworldCards)
        else
          GhostlyPossession.log("Kanto Reloaded's Overworld Menu has changed: Party View doesn't show the possessed look")
        end
      end
      return true
    end
  end
end
