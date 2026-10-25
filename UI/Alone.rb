#==============================================================================
# Ghostly Possession: on its own (KIF's own look)
#==============================================================================
# Without Kanto Reloaded, Ghostly Possession speaks with the game's own
# windows: its messages, and its menu frame (the one the player picked).
#
#   Possessed! (Chill, Then a Card, his pick 2026-10-24): a window up top,
#   the host + the Ghost -> the fusion ("Possessed" in lavender; One Row,
#   his pick 2026-10-25), over PIF's message "Gastly possessed Pikachu! It
#   will act on its own now and then."
#   Keep Which? (his pick 2026-10-24), in battle: a window up top, the
#   Growlithe "or" the Gastly, over the battle's own question and its
#   choice list (UI/Keep.rb).
#==============================================================================

module GhostlyPossession
  module Alone
    Z = 99_500                     # over the chill, under the message (99_999)
    BATTLE_Z = 100_400             # over the battle screen (99_999), under a card
    # "Possessed": lavender on a dark frame, deep purple on a light one
    LAVENDER = [Color.new(216, 168, 255), Color.new(72, 40, 104)].freeze
    PURPLE = [Color.new(120, 56, 192), Color.new(208, 192, 232)].freeze
    ICON_FRAME = 64                # a bigger icon (Big Pokémon Icons) is scaled to it

    module_function

    # leapt_from: after the Leap, the wild one it leaped out of
    def possessed(host, note, leapt_from = nil)
      window = BeforeAfter.new(host, UI.ghost_pokemon(note, host.level), Engine.display(host))
      first = leapt_from ? _INTL("{1}'s {2} leaped into {3}!", leapt_from, UI.ghost_name(note), host.name) :
                           _INTL("{1} possessed {2}!", UI.ghost_name(note), host.name)
      begin
        pbMessage(_INTL("{1}\\n{2}", first, _INTL("It will act on its own now and then."))) { window.update }
      ensure
        window.dispose
      end
    end

    #--------------------------------------------------------------------------
    # A window in the player's menu frame, one row: the host + the Ghost ->
    # the fusion, their names under them
    #--------------------------------------------------------------------------
    class BeforeAfter
      X = 70
      Y = 40
      W = 372
      H = 124

      def initialize(before, ghost, after, label = nil)
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = Z
        @window = SpriteWindow_Base.new(X, Y, W, H)
        @window.viewport = @viewport
        @icons = [[before, X + 64], [ghost, X + 172], [after, X + 296]].map do |pkmn, x|
          pkmn ? Alone.icon(pkmn, @viewport, @window.z + 1, x, Y + 52) : nil
        end.compact
        @overlay = Sprite.new(@viewport)
        @overlay.bitmap = Bitmap.new(Graphics.width, Graphics.height)
        @overlay.z = @window.z + 2
        base, shadow = getDefaultTextColors(@window.windowskin)
        ghostly = isDarkWindowskin(@window.windowskin) ? LAVENDER : PURPLE
        b = @overlay.bitmap
        pbSetSystemFont(b)
        Shapes.plus(b, X + 118, Y + 52, base)
        Shapes.arrow(b, X + 216, X + 250, Y + 52, base)
        pbDrawTextPositions(b, [[before ? before.name : "", X + 64, Y + 80, 2, base, shadow],
                                [ghost ? ghost.name : "", X + 172, Y + 80, 2, base, shadow],
                                [label || _INTL("Possessed"), X + 296, Y + 80, 2, ghostly[0], ghostly[1]]])
      end

      def update
        @window.update
        @icons.each(&:update)
      end

      def dispose
        @icons.each { |s| s.dispose unless s.disposed? }
        @overlay.bitmap.dispose if @overlay.bitmap && !@overlay.bitmap.disposed?
        @overlay.dispose unless @overlay.disposed?
        @window.dispose unless @window.disposed?
        @viewport.dispose unless @viewport.disposed?
      end
    end

    #--------------------------------------------------------------------------
    # A window in the player's menu frame over the battle: one Pokémon "or"
    # the other, their names under them (Keep Which?)
    #--------------------------------------------------------------------------
    class Pair < BeforeAfter
      def initialize(left, right)
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = BATTLE_Z
        @window = SpriteWindow_Base.new(X, Y, W, H)
        @window.viewport = @viewport
        @icons = [[left, X + 96], [right, X + W - 96]].map { |pkmn, x| Alone.icon(pkmn, @viewport, @window.z + 1, x, Y + 52) }
        @overlay = Sprite.new(@viewport)
        @overlay.bitmap = Bitmap.new(Graphics.width, Graphics.height)
        @overlay.z = @window.z + 2
        base, shadow = getDefaultTextColors(@window.windowskin)
        b = @overlay.bitmap
        pbSetSystemFont(b)
        pbDrawTextPositions(b, [[left.name, X + 96, Y + 80, 2, base, shadow], [right.name, X + W - 96, Y + 80, 2, base, shadow],
                                [_INTL("or"), X + W / 2, Y + 40, 2, base, shadow]])
      end
    end

    module_function

    # A Pokémon's icon sprite, its picture centred on x, y (the game's icon:
    # Big Pokémon Icons too, scaled to a small icon's size)
    def icon(pkmn, viewport, z, x, y)
      s = PokemonIconSprite.new(pkmn, viewport)
      s.kif_big_offset = false if s.respond_to?(:kif_big_offset=)
      s.z = z
      w = s.src_rect.width
      h = s.src_rect.height
      s.zoom_x = s.zoom_y = h > ICON_FRAME ? ICON_FRAME.to_f / h : 1.0
      s.ox = w / 2
      s.oy = h > ICON_FRAME ? h / 2 : h * 9 / 16
      s.x = x
      s.y = y
      return s
    end
  end
end
