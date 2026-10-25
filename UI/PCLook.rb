#==============================================================================
# Ghostly Possession: the PC look
#==============================================================================
# A possessed Pokémon in the PC shows as the fusion with the battle's ghost
# badge (his pick 2026-10-25: Ghost Badge), drawn from its note like the
# party look: the Pokémon itself stays as it is.
#
#   Its Icon       The fusion's (Big Pokémon Icons too) wherever the game
#                  makes a box icon: the boxes, the party column, held in
#                  the hand, picked (PokemonBoxIcon#refresh draws the look).
#   On Its Own     (the game's PC) the ghost badge in the icon's corner, on
#                  the icon's own copy of its picture, so it goes where the
#                  icon goes; the side panel: its name lavender, the
#                  fusion's Ghost-first types and picture, and the Ghost
#                  small in the picture's corner.
#   With Kanto Reloaded (its Reloaded PC): the badge in the slot's corner on
#                  the PC's marks layer (the box and the party row); the
#                  plate lit ghost purple (Ghost-first types) with the Party
#                  Screen's dashed outline, the fusion's picture and the
#                  Ghost and its name top right; Compare: the fusion's
#                  picture and types, the badge after its name.
#==============================================================================

module GhostlyPossession
  module PCLook
    BADGE = 15                     # Shapes.badge's side (its size 1)
    # where the badge sits in an icon's picture: its slot's top right
    # (a box icon is 64 px over a 48 px slot; a big one 96 px, drawn 16 up and left)
    AT = [36, 2].freeze
    AT_BIG = [52, 18].freeze
    GHOST_SIZE = 48                # the Ghost's picture on the side panel
    GHOST_AT = [150, 74].freeze    # its middle: the panel picture's top right
    @plain = 0

    module_function

    # Kanto Reloaded's PC draws the badge itself: icons made inside this are plain
    def plain
      @plain += 1
      return yield
    ensure
      @plain -= 1
    end

    def plain?
      return @plain > 0
    end

    # A still picture standing in for the AnimatedBitmap an IconSprite keeps
    # (it puts that one's picture back every frame)
    class Still
      attr_reader :bitmap
      def initialize(bitmap); @bitmap = bitmap; end
      def width; @bitmap.width; end
      def height; @bitmap.height; end
      def update; end
      def disposed?; @bitmap.disposed?; end
      def dispose; @bitmap.dispose unless @bitmap.disposed?; end
      def pbSetColor(*args); end
    end

    #--------------------------------------------------------------------------
    # Every box icon (the game's PC, Kanto Reloaded's, any other)
    #--------------------------------------------------------------------------
    module BoxIcon
      def refresh(*args)
        # (an icon Kanto Reloaded's PC made stays plain: its badge is the PC's)
        @gp_plain = GhostlyPossession::PCLook.plain? if @gp_plain.nil?
        look = @pokemon && GhostlyPossession::PartyLook.look_of(@pokemon)
        return super unless look
        real = @pokemon
        @pokemon = look
        begin
          ret = super
        ensure
          @pokemon = real
        end
        gp_badge unless @gp_plain
        return ret
      end

      # the badge on the icon's own copy of its picture
      def gp_badge
        src = self.bitmap
        return unless src && !src.disposed?
        r = self.src_rect
        rect = Rect.new(r.x, r.y, r.width, r.height)
        copy = src.clone
        dx, dy = @kif_big ? PCLook::AT_BIG : PCLook::AT
        x = [rect.x + dx, rect.x + rect.width - PCLook::BADGE].min
        GhostlyPossession::Shapes.badge(copy, x, rect.y + dy)
        setBitmapDirectly(PCLook::Still.new(copy))
        self.src_rect = rect
      rescue StandardError => e
        GhostlyPossession.log("A possessed box icon's badge couldn't be drawn: #{e.class}: #{e.message}")
      end
    end

    #--------------------------------------------------------------------------
    # On its own: the game's PC side panel (Kanto Reloaded's PC draws its own)
    #--------------------------------------------------------------------------
    module Panel
      def pbUpdateOverlay(selection, party = nil)
        ghost = @sprites && @sprites["gp_ghost"]
        ghost.visible = false if ghost && !ghost.disposed?
        pokemon = nil
        if @screen && @screen.pbHeldPokemon && !@screen.fusionMode
          pokemon = @screen.pbHeldPokemon
        elsif selection >= 0
          pokemon = party ? party[selection] : @storage[@storage.currentBox, selection]
        end
        look = pokemon && GhostlyPossession::PartyLook.look_of(pokemon)
        return super unless look
        ret = GhostlyPossession::PartyLook.with_name(pokemon.name) { super }
        gp_panel(pokemon, look)
        return ret
      end

      # the fusion's types and picture over the panel's own, the Ghost in the corner
      def gp_panel(pokemon, look)
        overlay = @sprites["overlay"].bitmap
        overlay.fill_rect(6, 272, 168, 28, Color.new(0, 0, 0, 0))
        types = AnimatedBitmap.new("Graphics/Pictures/types")
        row = proc { |t| Rect.new(0, ::GameData::Type.get(t).id_number * 28, 64, 28) }
        if look.type1 == look.type2
          overlay.blt(52, 272, types.bitmap, row.call(look.type1))
        else
          overlay.blt(18, 272, types.bitmap, row.call(look.type1))
          overlay.blt(88, 272, types.bitmap, row.call(look.type2))
        end
        types.dispose
        pic = @sprites["pokemon"]
        pic.setPokemonBitmap(look)
        pic.zoom_x = pic.zoom_y = ::Settings::FRONTSPRITE_SCALE
        gp_ghost(pokemon, pic)
      rescue StandardError => e
        GhostlyPossession.log("The PC panel's possessed look couldn't be drawn: #{e.class}: #{e.message}")
      end

      def gp_ghost(pokemon, pic)
        ghost = GhostlyPossession::PartyLook.ghost_of(pokemon)
        return unless ghost
        s = @sprites["gp_ghost"]
        if s.nil? || s.disposed? || !s.pokemon.equal?(ghost)
          s.dispose if s && !s.disposed?
          s = @sprites["gp_ghost"] = GhostPicture.new(pic.viewport, ghost)
        end
        s.z = pic.z + 1
        s.visible = !s.bitmap.nil?
      end
    end

    # The Ghost's picture, small (its own copy of its front sprite), its
    # middle where it's put (the PC's side panel, the Summary)
    class GhostPicture < ::Sprite
      attr_reader :pokemon

      def initialize(viewport, pokemon, at = GHOST_AT, size = GHOST_SIZE)
        super(viewport)
        @pokemon = pokemon
        anim = ::GameData::Species.sprite_bitmap_from_pokemon(pokemon, false)
        return unless anim
        self.bitmap = anim.bitmap.clone
        anim.dispose if anim.respond_to?(:dispose)
        self.ox = bitmap.width / 2
        self.oy = bitmap.height / 2
        self.zoom_x = self.zoom_y = size.to_f / [bitmap.height, 1].max
        self.x, self.y = at
      end

      def dispose
        bitmap.dispose if bitmap && !bitmap.disposed?
        super
      end
    end

    #--------------------------------------------------------------------------
    # With Kanto Reloaded: its Reloaded PC (Reloaded::PCScene)
    #--------------------------------------------------------------------------
    module KRScene
      # (Kanto Reloaded's names in full: constants here don't come from its scene)
      KP = ::Reloaded::Pixel if defined?(::Reloaded::Pixel)
      KF = ::KIF::PixelFont if defined?(::KIF::PixelFont)

      def gp_possessed?(pk)
        return GhostlyPossession::PartyLook.possessed?(pk)
      end

      # one look per possessed Pokémon while the PC is open (its pictures made once)
      def gp_look(pk)
        return nil unless gp_possessed?(pk)
        @gp_looks ||= {}.compare_by_identity
        return @gp_looks[pk] ||= GhostlyPossession::Engine.display(pk)
      end

      # Ghost-first types: the plate, Compare and Box Overview lit ghost purple
      def types_of(p)
        return super(gp_look(p) || p)
      end

      # (the box icon draws the look itself; the badge goes on the marks layer)
      def box_icon(pk, key = nil)
        return super unless gp_possessed?(pk)
        return GhostlyPossession::PCLook.plain { super }
      end

      def detail_picture(pk, cx, cy)
        return super(gp_look(pk) || pk, cx, cy)
      end

      def compare_icon(pk, side)
        return super(gp_look(pk) || pk, side)
      end

      def box_grid(base, top, c)
        super
        sc = ::Reloaded::PCScene
        PokemonBox::BOX_SIZE.times do |i|
          pk = box[i]
          next unless gp_possessed?(pk)
          sx, sy, = slot_rect(i)
          gp_badge(marks, c, sx + sc::CELL_W - 18, sy + 2)
        end
      rescue StandardError => e
        GhostlyPossession.log("Reloaded PC's possessed badge couldn't be drawn: #{e.class}: #{e.message}")
      end

      def party_row(base, top, c)
        super
        sc = ::Reloaded::PCScene
        6.times do |i|
          pk = @storage.party[i]
          next unless gp_possessed?(pk)
          cx, = party_centre(i)
          x0 = cx - sc::PARTY_STEP / 2 + 2
          gp_badge(marks, c, x0 + sc::PARTY_STEP - 4 - 18, sc::PARTY_Y + 18)
        end
      rescue StandardError => e
        GhostlyPossession.log("Reloaded PC's possessed badge couldn't be drawn: #{e.class}: #{e.message}")
      end

      # the Party Screen card's ghost badge, a size smaller
      def gp_badge(b, c, x, y)
        ink = GhostlyPossession::PartyLook.ink(c)
        fill = c[:light] ? mix(c[:panel2], ink, 0.22) : mix(c[:panel], ink, 0.3)
        KP.ui.rbox(b, x, y, x + 15, y + 13, 4, fill, ink)
        ::Reloaded::PartyPaint.pixels(b, GhostlyPossession::PartyLook::GLYPH, x + 3, y + 2, ink)
      end

      # the plate: the dashed purple outline, the Ghost and its name top right
      def plate(base, top, c)
        super
        pk = focused_pokemon
        return unless gp_possessed?(pk)
        x0, y0, x1, y1 = ::Reloaded::PCScene::PLATE
        ink = GhostlyPossession::PartyLook.ink(c)
        ::Reloaded::PartyPaint.chamfer_outline(top, x0 + 3, y0 + 3, x1 - 3, y1 - 3, 14, ink, 3)
        ghost = GhostlyPossession::PartyLook.ghost_of(pk)
        return unless ghost
        gx = x1 - 28
        s = gp_ghost_icon(ghost)
        place(s, gx, y0 + 36, 30, 1.0) if s
        KP.text(top, gx - 30, y0 + 52, 60, 12, KF.fit(KF::TINY, ghost.name.to_s.upcase, 60), ink, KF::TINY, 2)
      rescue StandardError => e
        GhostlyPossession.log("Reloaded PC's possessed plate couldn't be drawn: #{e.class}: #{e.message}")
      end

      def gp_ghost_icon(ghost)
        (@kr_used ||= {})[:gp_ghost] = true
        s, who = @kr_icons[:gp_ghost]
        if s.nil? || s.disposed? || !who.equal?(ghost)
          s.dispose if s && !s.disposed?
          s = ::Reloaded::PartyIcons.icon(ghost, @viewport, 2)
          return nil unless s
          @kr_icons[:gp_ghost] = [s, ghost]
        end
        s.visible = true
        return s
      end

      # Compare: the badge after its name
      def compare_card(base, top, c, pk, x0, side)
        super
        return unless gp_possessed?(pk)
        w = ::Reloaded::PCScene::W / 2 - 12
        tx = side == :left ? x0 + 70 : x0 + 10
        nw = KP.width(KF::TEXT, KF.fit(KF::TEXT, pk.name.to_s, w - 84))
        gp_badge(top, c, tx + nw + 6, 42)
      rescue StandardError => e
        GhostlyPossession.log("Compare's possessed badge couldn't be drawn: #{e.class}: #{e.message}")
      end
    end

    def boot
      if defined?(::PokemonBoxIcon) && !::PokemonBoxIcon.ancestors.include?(BoxIcon)
        ::PokemonBoxIcon.prepend(BoxIcon)
      end
      if defined?(::PokemonStorageScene) && !::PokemonStorageScene.ancestors.include?(Panel)
        ::PokemonStorageScene.prepend(Panel)
      end
      if KR.on? && defined?(::Reloaded::PCScene) && !::Reloaded::PCScene.ancestors.include?(KRScene)
        needs = [:types_of, :box_icon, :detail_picture, :compare_icon, :box_grid, :party_row, :plate, :compare_card,
                 :slot_rect, :party_centre, :marks, :focused_pokemon, :place, :mix, :box]
        if needs.all? { |m| ::Reloaded::PCScene.method_defined?(m) || ::Reloaded::PCScene.private_method_defined?(m) }
          ::Reloaded::PCScene.prepend(KRScene)
        else
          GhostlyPossession.log("Kanto Reloaded's Reloaded PC has changed: the possessed look isn't drawn on it")
        end
      end
      return true
    end
  end
end
