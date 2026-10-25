#==============================================================================
# Ghostly Possession: a card (with Kanto Reloaded)
#==============================================================================
# With Kanto Reloaded, the moments are told on a card in its notice look
# (Reloaded::Notice), drawn with its kit and Theme Mode: a panel with a
# coloured edge and title, one Pokémon -> another (the Ghost small over the
# arrow, the new look on a disc, its types), what it means, a smaller line,
# and buttons.
#
#   i = GhostlyPossession::Card.show(:title => "Possessed!", :rgb => [150, 80, 230],
#                                    :before => host, :after => Engine.display(host),
#                                    :ghost => ghost_pkmn, :body => "...", :note => "...",
#                                    :buttons => ["OK"])
#   # => the button picked (B picks the last)
#
# The pictures are the game's icons as Kanto Reloaded shows them
# (Reloaded::PartyIcons: Big Pokémon Icons too).
#==============================================================================

module GhostlyPossession
  module Card
    W = 512
    H = 384
    X0 = 86
    CW = 340
    Z = 100_500
    GHOST_RGB = [150, 80, 230].freeze
    GREY_RGB = [150, 150, 160].freeze

    module_function

    # Kanto Reloaded is there with everything the card is drawn with
    def ready?
      return false unless KR.has?(:Notice)
      return defined?(::Reloaded::Pixel) && defined?(::Reloaded::Dialogs) && defined?(::Reloaded::PartyPaint) &&
             defined?(::Reloaded::PartyIcons) && defined?(::Reloaded::Palette) && defined?(::Reloaded::Prompts) &&
             defined?(::Reloaded::Pointer) && defined?(::KIF::PixelFont) ? true : false
    end

    # changed: which side has the possessed look (its disc, its name in the
    # card's colour, its types): :after (Possessed!) or :before (it leaves).
    # middle: an item's picture over the chevrons instead of the Ghost.
    # cancel: false when B doesn't close it; disabled: buttons that can't
    # be picked (dimmed, a buzz).
    def show(title:, rgb:, buttons:, before: nil, after: nil, ghost: nil, before_name: nil, after_name: nil,
             body: nil, note: nil, choice: 0, changed: :after, pills: true, middle: nil, cancel: true, disabled: [])
      scene = Scene.new(:title => title, :rgb => rgb, :buttons => buttons, :before => before, :after => after,
                        :ghost => ghost, :before_name => before_name, :after_name => after_name,
                        :body => body, :note => note, :changed => changed, :pills => pills, :middle => middle,
                        :cancel => cancel, :disabled => disabled)
      begin
        return scene.run(choice)
      ensure
        scene.dispose
      end
    end

    class Scene
      P = ::Reloaded::Pixel if defined?(::Reloaded::Pixel)

      attr_reader :sprite

      def initialize(args)
        @args = args
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = Z
        @sprite = Sprite.new(@viewport)
        @sprite.bitmap = Bitmap.new(W, H)
        @icons = []
        @hits = []
      end

      def run(choice)
        buttons = @args[:buttons]
        # B picks the last button, unless it can't close the card
        cancel = @args[:cancel] == false ? nil : buttons.length - 1
        draw(choice)
        picked = nil
        loop do
          Graphics.update
          Input.update
          @icons.each(&:update)
          pt = ::Reloaded::Pointer
          redraw = false
          if pt.moved? && (i = pt.hit(@hits)) && i != choice
            choice = i
            pbPlayCursorSE
            redraw = true
          end
          if pt.left? && (i = pt.hit(@hits))
            picked = i
          elsif pt.right? || Input.trigger?(Input::BACK)
            picked = cancel
          elsif buttons.length > 1 && (Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT))
            choice = (choice + (Input.trigger?(Input::RIGHT) ? 1 : -1)) % buttons.length
            pbPlayCursorSE
            redraw = true
          elsif Input.trigger?(Input::USE)
            picked = choice
          end
          if picked && Array(@args[:disabled]).include?(picked)
            pbPlayBuzzerSE
            picked = nil
          end
          break if picked
          draw(choice, false) if redraw
        end
        picked == cancel && buttons.length > 1 ? pbPlayCancelSE : pbPlayDecisionSE
        return picked
      end

      # The card; its pictures only the first time
      def draw(choice, pictures = true)
        a = @args
        c = ::Reloaded::Palette.map_menu   # Theme Mode: Dark, or Light for Light and Frost
        paint = ::Reloaded::PartyPaint
        pf = ::KIF::PixelFont
        dg = ::Reloaded::Dialogs
        tint = paint.ink(c, a[:rgb])
        o = @sprite.bitmap
        o.clear
        o.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 110))
        body = a[:body] ? P.wrap(a[:body].to_s, CW - 28) : []
        note = a[:note] ? P.small_wrap(o, a[:note].to_s, CW - 28) : []
        # the line under the pictures: lower when the new look's types show
        split = a[:pills] != false ? 178 : 158
        h = split + 8 + body.length * 18 + (note.empty? ? 0 : 6 + note.length * 16) + 50
        y0 = [(H - P::HINT_H - h) / 2, 6].max
        y1 = y0 + h
        dg.send(:panel, o, c, X0, y0, CW, h, tint)
        dg.send(:title_bar, o, c, X0, y0, CW, a[:title].to_s, tint, tint, tint)
        # before -> after, the Ghost (or an item) and the arrow between
        spots = layout(y0)
        side = a[:changed] == :before ? :before : :after
        paint.disc(o, spots[side][0], spots[side][1], 40, ::Reloaded::Palette.mix(c[:panel2], tint, 0.22))
        paint_link(o, c, tint, spots)
        middle(o, a[:middle], *spots[:ghost]) if a[:middle] && !a[:ghost]
        if pictures
          picture(a[:before], *spots[:before])
          picture(a[:ghost], *spots[:ghost])
          picture(a[:after], *spots[:after])
        end
        before_name = a[:before_name] || (a[:before] ? a[:before].name : "")
        after_name = a[:after_name] || before_name
        name(o, before_name, spots[:before][0], y0 + 134, side == :before ? tint : c[:txt])
        name(o, a[:ghost].name, spots[:ghost][0], y0 + 134, c[:dim]) if spots[:ghost_name] && a[:ghost]
        name(o, after_name, spots[:after][0], y0 + 134, side == :after ? tint : c[:txt])
        type_pills(o, c, a[side], spots[side][0], y0 + 156) if a[side] && a[:pills] != false
        o.fill_rect(X0 + 12, y0 + split, CW - 24, 1, c[:line])
        y = y0 + split + 8
        body.each do |ln|
          P.text(o, X0 + 14, y, CW - 28, 18, ln, c[:txt])
          y += 18
        end
        y += 6 unless note.empty?
        note.each do |ln|
          P.small(o, X0 + 14, y, CW - 28, 16, ln, c[:dim])
          y += 16
        end
        paint_buttons(o, c, a[:buttons], choice, y1 - 40)
        pairs = a[:buttons].length > 1 ? [[:lr, _INTL("Choose")], [button(:C), _INTL("Select")]] : [[button(:C), a[:buttons][0].to_s]]
        P.hints(o, o, c, pairs, ::Reloaded::Prompts.style)
      end

      # Where the pictures' middles go: [x, y] (the Ghost's [x, y, zoom];
      # whole-number sizes keep the pixels even), and whether the Ghost's
      # name shows under it
      # (Chevrons Under the Ghost, his pick 2026-10-25: the Ghost full size)
      def layout(y0)
        return { :before => [X0 + 80, y0 + 92], :ghost => [X0 + CW / 2, y0 + 78, 1.0],
                 :after => [X0 + CW - 80, y0 + 92], :ghost_name => false }
      end

      # Three chevrons under the Ghost (or the item), pointing to the new
      # look; with nothing over them, level with the pictures
      def paint_link(o, c, tint, spots)
        x, y = spots[:ghost]
        y = @args[:ghost] || @args[:middle] ? y + 33 : spots[:before][1] - 5
        3.times { |i| Shapes.chevron(o, x - 15 + i * 11, y, 11, tint) }
      end

      # An item's picture (its icon file) centred on x, y, at its own size
      def middle(o, path, x, y, *_rest)
        bm = Bitmap.new(pbResolveBitmap(path) || path)
        o.blt(x - bm.width / 2, y - bm.height / 2, bm, Rect.new(0, 0, bm.width, bm.height))
        bm.dispose
      rescue StandardError
        nil
      end

      # A name centred on x
      def name(o, text, x, y, colour)
        pf = ::KIF::PixelFont
        P.text(o, x - 50, y, 100, 18, pf.fit(pf::TEXT, text.to_s, 100), colour, pf::TEXT, 2)
      end

      # A Pokémon's icon, its picture's middle on x, y
      def picture(pkmn, x, y, zoom = 1.0)
        return unless pkmn
        s = ::Reloaded::PartyIcons.icon(pkmn, @viewport, 1)
        return unless s
        ::Reloaded::PartyIcons.place(s, x, y)
        s.zoom_x = s.zoom_y = s.zoom_x * zoom
        @icons << s
      end

      # The new look's types, as the party screen's pills
      def type_pills(o, c, pkmn, cx, y)
        types = (pkmn.types rescue [pkmn.type1, pkmn.type2]).compact.uniq
        pills = types.map do |t|
          name = (::GameData::Type.get(t).name rescue t.to_s).upcase
          rgb = defined?(::Reloaded::PartyScreen::TYPE_RGB) ? (::Reloaded::PartyScreen::TYPE_RGB[t] || GREY_RGB) : GREY_RGB
          [name, rgb]
        end
        ws = pills.map { |label, _| P.width(::KIF::PixelFont::TINY, label) + 12 }
        x = cx - (ws.sum + 6 * (pills.length - 1)) / 2
        pills.each_with_index do |(label, rgb), i|
          fill, ink = ::Reloaded::PartyPaint.badge(c, rgb)
          P.pill(o, x, y, label, fill, ink, false)
          x += ws[i] + 6
        end
      end

      # Buttons as wide as their words need, sharing the row (the notice's)
      def paint_buttons(o, c, labels, choice, by)
        pf = ::KIF::PixelFont
        gap = 8
        room = CW - 28 - gap * (labels.length - 1)
        need = labels.map { |l| P.width(pf::TEXT, l.to_s) + 24 }
        extra = [(room - need.sum) / labels.length, 0].max
        widths = need.map { |n| n + extra }
        widths = widths.map { |n| n * room / widths.sum } if widths.sum > room
        @hits = []
        bx = X0 + 14
        labels.each_with_index do |label, i|
          bw = widths[i]
          @hits << [i, bx, by, bx + bw, by + 28]
          ::Reloaded::Dialogs.send(:button, o, c, bx, by, bx + bw, by + 28, i == choice)
          ink = if Array(@args[:disabled]).include?(i) then c[:dim]
                elsif i == choice then c[:strong] || c[:white]
                else c[:txt]
                end
          P.text(o, bx, by + 2, bw, 24, pf.fit(pf::TEXT, label.to_s, bw - 8), ink, pf::TEXT, 2)
          bx += bw + gap
        end
      end

      def button(sym)
        return ::Reloaded::Prompts.input(sym) || ::Reloaded::Prompts.name(sym)
      end

      def dispose
        @icons.each { |s| s.dispose unless s.disposed? }
        @sprite.bitmap.dispose if @sprite.bitmap && !@sprite.bitmap.disposed?
        @sprite.dispose unless @sprite.disposed?
        @viewport.dispose unless @viewport.disposed?
      end
    end
  end
end
