#==============================================================================
# Ghostly Possession: how Restless Spirits look
#==============================================================================
# His picks 2026-10-24 (sheets gp-wisp-grave-better, gp-grave-card-2,
# gp-spirit-rises-2, gp-spirit-battle, gp-came-back):
#
#   The grave       the Small Headstone in full detail, Engraved Lines: a
#                   rounded grey stone lit from the left, an etched Poké
#                   Ball, two engraved lines, moss, a slab on a mound, a soft
#                   shadow; night-tinted as any map sprite; while it waits,
#                   the treasure ball's Glow and Motes
#   Reading it      the Memorial Card (Kanto Reloaded: "Here Lies Sparky", its
#                   picture faded lilac on a disc, its kind and level, where
#                   it fell; Call Its Spirit / Pay Respects; B closes it). On
#                   its own: the game's message under a window with its
#                   faded picture, then the choice
#   It rises        Rises From the Grave: its own follower sprite, faded and
#                   lilac, with the Outline and Echo, comes up behind the
#                   stone and hovers facing you; Call: a lilac flash into
#                   battle; Pay Respects: it drifts up into sparks. The grave
#                   fades as it goes
#   Its battle      see-through and lilac (a lilac copy over it, its opacity
#                   capped: EBDX keeps resetting a battler's own colour) with
#                   the battle's Outline and Echo; the Restless Pill under its
#                   HP bar (RESTLESS 5 to 1), in EBDX's stat-stage pills' row
#                   and style, and on PIF's screen past the status icon
#   It came back    Before and After: "Sparky Came Back!" (old picture faded
#                   -> the new one with its types). On its own: the message
#                   under a window, old -> new
#==============================================================================

module GhostlyPossession
  module SpiritLook
    LILAC = [196, 168, 255].freeze
    PURPLE = [170, 100, 255].freeze
    HALO = [168, 112, 255].freeze
    POOL = [150, 110, 255].freeze
    PILL = [150, 80, 230].freeze
    CAP = 209                      # the spirit's opacity at most (0.82)
    LILAC_SHARE = 0.45             # how lilac it looks
    ICON_OPACITY = 175
    ICON_COLOUR = [196, 168, 255, 140].freeze
    Z = 99_000                     # the flash: over the map, under messages
    RISE = 40                      # frames it takes to come up
    HOVER = 30
    DRIFT = 50
    FLASH = 16
    FADE = 24                      # frames it takes to fade in battle

    module_function

    def kr?
      return UI.kr?
    rescue StandardError
      return false
    end

    def species_name(f)
      return ::GameData::Species.get(f[:species]).name
    rescue StandardError
      return f[:species].to_s.capitalize
    end

    # The fallen one as a Pokémon (for its pictures): the Graveyard's, else made
    def picture_pokemon(f)
      return f[:pokemon] if f[:pokemon]
      return (f[:picture] ||= ::Pokemon.new(f[:species], [f[:level].to_i, 1].max))
    rescue StandardError
      return nil
    end

    def spirit!(sprite)
      return unless sprite && !sprite.disposed?
      sprite.opacity = ICON_OPACITY
      sprite.color = Color.new(*ICON_COLOUR)
    end

    #--------------------------------------------------------------------------
    # The headstone (28 x 34), drawn once: grave_art.py's Engraved Lines
    #--------------------------------------------------------------------------
    HS_W = 28
    HS_H = 34
    HS = { :o => [52, 46, 64], :h => [236, 236, 244], :l => [204, 204, 218], :m => [174, 174, 190], :d => [138, 138, 156],
           :dd => [112, 112, 130], :k => [96, 96, 114], :e => [226, 226, 236], :v => [104, 146, 84], :vd => [76, 116, 64],
           :g => [98, 170, 82], :gd => [64, 126, 60], :mu => [130, 102, 76], :md => [98, 76, 58], :sh => [20, 16, 32, 110] }.freeze
    BALL = ["..KKKKK..", ".K.....K.", "K.......K", "K..KKK..K", "KKKK.KKKK", "K..KKK..K", "K.......K", ".K.....K.", "..KKKKK.."].freeze

    # The stone's pixels as names (:h, :l, ...), from the art's own steps
    def headstone_pixels
      px = {}
      put = proc { |x, y, c| px[[x, y]] = c if x >= 0 && y >= 0 && x < HS_W && y < HS_H }
      cx, r, top, face_b = 14, 9, 2, 23
      half = proc do |y|
        dy = y - (top + r)
        dy >= 0 ? r : Math.sqrt([0, r * r - dy * dy].max).round
      end
      (29...33).each { |y| (2...27).each { |x| put.call(x, y, :sh) if ((x - 14.5) / 12.5)**2 + ((y - 30.5) / 2.2)**2 <= 1 } }
      (26...31).each { |y| (3...26).each { |x| put.call(x, y, y < 29 ? :mu : :md) if ((x - 14.5) / 11.5)**2 + ((y - 27.0) / 3.4)**2 <= 1 } }
      [[3, 2], [4, 3], [6, 2], [8, 1], [20, 2], [22, 3], [23, 2], [25, 1], [11, 1], [17, 1]].each do |x, h|
        h.times { |k| put.call(x, 27 - k, k < h - 1 || h == 1 ? :g : :gd) }
        put.call(x, 28, :gd)
      end
      (top..face_b).each do |y|
        hw = half.call(y)
        (cx - hw...cx + hw).each do |x|
          t = (x - (cx - hw)).to_f / [1, 2 * hw - 1].max
          c = t < 0.12 ? :h : t < 0.5 ? :l : t < 0.82 ? :m : :d
          c = (c == :l ? :m : :d) if y >= face_b - 2 && [:l, :m].include?(c)
          put.call(x, y, c)
        end
        if y < top + r
          put.call(cx - hw, y, :h)
          put.call(cx - hw + 1, y, :h) if hw > 2
        end
      end
      (top..face_b).each do |y|
        hw = half.call(y)
        put.call(cx - hw - 1, y, :o)
        put.call(cx + hw, y, :o)
      end
      stone = [:h, :l, :m, :d]
      (cx - r - 1..cx + r).each do |x|
        (top - 1..face_b).each do |y|
          next if px[[x, y]]
          put.call(x, y, :o) if [[0, 1], [1, 0], [-1, 0]].any? { |dx, dy| stone.include?(px[[x + dx, y + dy]]) }
        end
      end
      x0, y0 = cx - 5, 5
      cuts = []
      BALL.each_with_index { |row, j| row.chars.each_with_index { |ch, i| cuts << [x0 + i, y0 + j] if ch == "K" } }
      cuts.each do |x, y|
        below = BALL[y + 1 - y0]
        put.call(x, y + 1, :e) if !cuts.include?([x, y + 1]) && below && below[x - x0] == "."
      end
      cuts.each { |x, y| put.call(x, y, :k) }
      [[16, cx - 5, cx + 5], [19, cx - 4, cx + 4]].each do |y, a, b|
        (a...b).each { |x| put.call(x, y, :k); put.call(x, y + 1, :e) }
      end
      [[cx + 6, 4], [cx + 5, 5], [cx + 5, 6], [cx + 4, 7]].each { |x, y| put.call(x, y, :dd) }
      [[cx - 8, 22, :v], [cx - 8, 23, :vd], [cx - 7, 23, :v], [cx + 7, 23, :v], [cx - 9, 21, :v]].each { |x, y, c| put.call(x, y, c) }
      (24..26).each do |y|
        (cx - r - 2...cx + r + 2).each { |x| put.call(x, y, y == 24 ? :l : x < cx + r ? :m : :d) }
      end
      (cx - r - 2...cx + r + 2).each { |x| put.call(x, 27, :o) }
      (24..26).each { |y| put.call(cx - r - 3, y, :o); put.call(cx + r + 2, y, :o) }
      ((cx - r - 2...cx - r).to_a + (cx + r...cx + r + 2).to_a).each { |x| put.call(x, 23, :o) }
      return px
    end

    def headstone
      return @headstone if @headstone && !@headstone.disposed?
      @headstone = Bitmap.new(HS_W, HS_H)
      headstone_pixels.each { |(x, y), c| @headstone.set_pixel(x, y, Color.new(*HS[c])) }
      return @headstone
    end

    #--------------------------------------------------------------------------
    # The grave on the map: the stone, hung on its event's sprite, and the
    # treasure ball's Glow and Motes while it waits
    #--------------------------------------------------------------------------
    IVAR = :@gp_grave_look

    def grave_follow(s, ch)
      looks = s.instance_variable_get(IVAR)
      unless ch && Spirits.ours?(ch) && !ch.instance_variable_get(:@erased)
        grave_off(s) if looks
        return
      end
      looks = grave_make(s) if !looks || looks.any?(&:disposed?)
      stone, pool, halo, *motes = looks
      shown = !s.disposed? && s.visible
      stone.x, stone.y, stone.z = s.x, s.y, s.z
      stone.visible = shown
      stone.opacity = s.opacity
      stone.tone = s.tone.clone if s.tone       # night-tinted as the map's sprites
      cy = s.y - 16
      frame = Graphics.frame_count
      [pool, halo].each { |g| g.visible = shown; g.opacity = s.opacity }
      pool.x, pool.y, pool.z = s.x, s.y - 4, s.z - 1
      halo.x, halo.y, halo.z = s.x, cy, s.z - 1
      halo.zoom_x = halo.zoom_y = (frame / 8).even? ? 1.0 : 1.06
      motes.each_slice(2).each_with_index do |(glow, dot), n|
        ang = frame * 0.05 + Math::PI / 4 + n * Math::PI
        mx = s.x + (Math.cos(ang) * 17).round
        my = cy + (Math.sin(ang) * 6).round
        [glow, dot].each do |m|
          m.x, m.y = mx, my
          m.z = Math.sin(ang) < 0 ? s.z - 1 : s.z + 1
          m.visible = shown
          m.opacity = s.opacity
        end
      end
    rescue StandardError => e
      grave_off(s)
      GhostlyPossession.log("The grave couldn't be drawn: #{e.class}: #{e.message}")
    end

    def grave_make(s)
      grave_off(s)
      stone = Sprite.new(s.viewport)
      stone.bitmap = headstone
      stone.ox = HS_W / 2
      stone.oy = HS_H
      looks = [stone]
      [[WispLook.glow(24, POOL, 0.7, 0.35, 1.3), true], [WispLook.glow(30, HALO, 0.7, 1.0, 1.8), true]].each do |bitmap, add|
        looks << glow_sprite(s.viewport, bitmap, add)
      end
      2.times do
        looks << glow_sprite(s.viewport, WispLook.glow(6, HALO, 0.5), true)
        looks << glow_sprite(s.viewport, WispLook.mote, false)
      end
      s.instance_variable_set(IVAR, looks)
      return looks
    end

    def glow_sprite(viewport, bitmap, additive)
      sp = Sprite.new(viewport)
      sp.bitmap = bitmap
      sp.ox = bitmap.width / 2
      sp.oy = bitmap.height / 2
      sp.blend_type = 1 if additive
      sp.visible = false
      return sp
    end

    def grave_off(s)
      looks = s.instance_variable_get(IVAR)
      return unless looks
      looks.each { |sp| sp.dispose unless sp.disposed? }       # (the bitmaps are shared: kept)
      s.instance_variable_set(IVAR, nil)
    end

    module GraveSprite
      def update(*args)
        ret = super
        GhostlyPossession::SpiritLook.grave_follow(self, @character)
        return ret
      end

      def dispose(*args)
        GhostlyPossession::SpiritLook.grave_off(self)
        return super
      end
    end

    # The grave's sprite on the map (its layer and z), or nil
    def grave_sprite(ev)
      return nil unless ev && $scene.respond_to?(:spriteset) && $scene.spriteset
      set = $scene.spriteset
      return nil unless set.respond_to?(:character_sprites) && set.character_sprites
      return set.character_sprites.find { |s| !s.disposed? && s.respond_to?(:character) && s.character.equal?(ev) }
    rescue StandardError
      return nil
    end

    #--------------------------------------------------------------------------
    # Reading the grave: :call, :respects, or nil (B)
    #--------------------------------------------------------------------------
    def read_grave(f)
      return kr? ? read_kr(f) : read_alone(f)
    end

    def body_words
      return _INTL("Its spirit lingers here, restless. Call it and it rises for 5 turns: beat it, or catch it to bring it back. Or pay your respects and let it rest.")
    end

    def read_kr(f)
      args = { :title => _INTL("Here Lies {1}", f[:name]), :rgb => Card::GHOST_RGB,
               :buttons => [_INTL("Call Its Spirit"), _INTL("Pay Respects")], :before => picture_pokemon(f), :after => nil,
               :ghost => nil, :before_name => f[:name], :after_name => f[:name], :body => body_words,
               :note => _INTL("Either way, it only happens once."), :changed => :before, :pills => false, :middle => nil,
               :cancel => true, :disabled => [], :fallen => f }
      scene = MemorialScene.new(args)
      begin
        pick = scene.run(0)
      ensure
        scene.dispose
      end
      return [:call, :respects][pick] if pick
      return nil
    end

    def read_alone(f)
      window = Plaque.new(picture_pokemon(f), f[:name])
      begin
        pbMessage(_INTL("Here lies {1} the {2}, Lv. {3}.\\nIt fell at {4}.", f[:name], species_name(f), f[:level], f[:place])) { window.update }
        pick = pbMessage(_INTL("Its spirit is restless... What will you do?\\nEither way, it only happens once."),
                         [_INTL("Call Its Spirit"), _INTL("Pay Respects")], -1) { window.update }
      ensure
        window.dispose
      end
      return [:call, :respects][pick] if pick.is_a?(Integer) && pick >= 0
      return nil
    end

    # Kanto Reloaded's card: its faded picture on a disc, its name, kind and
    # level, where it fell, the words; B closes it without a choice
    class MemorialScene < Card::Scene
      C = Card

      def draw(choice, pictures = true)
        a = @args
        f = a[:fallen]
        c = ::Reloaded::Palette.map_menu
        paint = ::Reloaded::PartyPaint
        dg = ::Reloaded::Dialogs
        tint = paint.ink(c, a[:rgb])
        o = @sprite.bitmap
        o.clear
        o.fill_rect(0, 0, C::W, C::H, Color.new(0, 0, 0, 110))
        body = P.wrap(a[:body].to_s, C::CW - 28)
        note = P.small_wrap(o, a[:note].to_s, C::CW - 28)
        split = 158
        h = split + 8 + body.length * 18 + 6 + note.length * 16 + 50
        y0 = [(C::H - P::HINT_H - h) / 2, 6].max
        y1 = y0 + h
        dg.send(:panel, o, c, C::X0, y0, C::CW, h, tint)
        dg.send(:title_bar, o, c, C::X0, y0, C::CW, a[:title].to_s, tint, tint, tint)
        cx = C::X0 + C::CW / 2
        paint.disc(o, cx, y0 + 74, 36, ::Reloaded::Palette.mix(c[:panel2], tint, 0.22))
        if pictures
          picture(a[:before], cx, y0 + 74)
          GhostlyPossession::SpiritLook.spirit!(@icons.last)
        end
        name(o, f[:name].to_s, cx, y0 + 114, c[:txt])
        tiny = ::KIF::PixelFont::TINY
        P.text(o, C::X0, y0 + 132, C::CW, 16, _INTL("{1}  Lv. {2}", GhostlyPossession::SpiritLook.species_name(f), f[:level]), c[:dim], tiny, 2)
        P.text(o, C::X0, y0 + 146, C::CW, 16, _INTL("Fell at {1}", f[:place]), tint, tiny, 2)
        o.fill_rect(C::X0 + 12, y0 + split + 8, C::CW - 24, 1, c[:line])
        y = y0 + split + 16
        body.each { |ln| P.text(o, C::X0 + 14, y, C::CW - 28, 18, ln, c[:txt]); y += 18 }
        y += 6
        note.each { |ln| P.small(o, C::X0 + 14, y, C::CW - 28, 16, ln, c[:dim]); y += 16 }
        paint_buttons(o, c, a[:buttons], choice, y1 - 40)
        P.hints(o, o, c, [[:lr, _INTL("Choose")], [button(:C), _INTL("Select")]], ::Reloaded::Prompts.style)
      end

      # (as the card's, but B and a right click close it: nil)
      def run(choice)
        buttons = @args[:buttons]
        draw(choice)
        loop do
          Graphics.update
          Input.update
          @icons.each(&:update)
          pt = ::Reloaded::Pointer
          if pt.moved? && (i = pt.hit(@hits)) && i != choice
            choice = i
            pbPlayCursorSE
            draw(choice, false)
          end
          if pt.left? && (i = pt.hit(@hits))
            pbPlayDecisionSE
            return i
          elsif pt.right? || Input.trigger?(Input::BACK)
            pbPlayCancelSE
            return nil
          elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
            choice = (choice + (Input.trigger?(Input::RIGHT) ? 1 : -1)) % buttons.length
            pbPlayCursorSE
            draw(choice, false)
          elsif Input.trigger?(Input::USE)
            pbPlayDecisionSE
            return choice
          end
        end
      end
    end

    # On its own: a window up top, its faded picture and its name
    class Plaque
      X = 156
      Y = 40
      W = 200
      H = 132

      def initialize(pkmn, name)
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = Alone::Z
        @window = SpriteWindow_Base.new(X, Y, W, H)
        @window.viewport = @viewport
        @icon = pkmn ? Alone.icon(pkmn, @viewport, @window.z + 1, X + W / 2, Y + 52) : nil
        SpiritLook.spirit!(@icon)
        @overlay = Sprite.new(@viewport)
        @overlay.bitmap = Bitmap.new(Graphics.width, Graphics.height)
        @overlay.z = @window.z + 2
        base, shadow = getDefaultTextColors(@window.windowskin)
        pbSetSystemFont(@overlay.bitmap)
        pbDrawTextPositions(@overlay.bitmap, [[name.to_s, X + W / 2, Y + 80, 2, base, shadow]])
      end

      def update
        @window.update
        @icon.update if @icon
      end

      def dispose
        @icon.dispose if @icon && !@icon.disposed?
        @overlay.bitmap.dispose if @overlay.bitmap && !@overlay.bitmap.disposed?
        @overlay.dispose unless @overlay.disposed?
        @window.dispose unless @window.disposed?
        @viewport.dispose unless @viewport.disposed?
      end
    end

    #--------------------------------------------------------------------------
    # It rises (Rises From the Grave, with the Outline and Echo)
    #--------------------------------------------------------------------------
    def frames(n)
      return Moment.frames(n)
    end

    def tick
      Graphics.update
      Input.update
      pbUpdateSceneMap
    end

    # Its own overworld picture: [sheet, columns, rows] (Followers, 4 x 4; a
    # fusion's: its body's), else its icon (2 x 1), else nil
    def follower_of(f)
      pkmn = f[:pokemon]
      species = f[:species]
      data = ::GameData::Species.get(species)
      species = ::GameData::Species.get(Spirits.body_id(species)).id if data.id_number > ::Settings::NB_POKEMON
      names = []
      names << "Graphics/Characters/Followers/Shiny/#{species}" if pkmn && pkmn.shiny?
      names << "Graphics/Characters/Followers/#{species}"
      names.each do |n|
        path = pbResolveBitmap(n)
        return [Bitmap.new(path), 4, 4] if path
      end
      icon = pbResolveBitmap(::GameData::Species.icon_filename(species)) rescue nil
      return icon ? [Bitmap.new(icon), 2, 1] : nil
    rescue StandardError
      return nil
    end

    # how: :call (a lilac flash into battle) or :respects (it drifts away);
    # the grave fades as it goes
    def rise(f, how)
      g = Spirits.grave
      return unless g && $scene.is_a?(::Scene_Map) && $game_player
      temp = $PokemonTemp && $PokemonTemp.respond_to?(:prevent_ow_battles=) ? $PokemonTemp : nil
      calm_was = temp.prevent_ow_battles if temp
      temp.prevent_ow_battles = true if temp
      scene = Rise.new(f, g)
      begin
        scene.play(how)
      ensure
        scene.dispose
        temp.prevent_ow_battles = calm_was if temp
      end
    rescue StandardError => e
      GhostlyPossession.log("The spirit's rise couldn't be shown: #{e.class}: #{e.message}")
    end

    # The spirit on the map's own layer, just under the stone's (it comes up
    # behind it); the flash over everything
    class Rise
      OUTLINE = [[-1, 0], [1, 0], [0, -1], [0, 1], [-1, -1], [1, -1], [-1, 1], [1, 1]].freeze
      LINE = 22                    # where it comes up: its feet this far over the ground, behind the stone
      UP = 6                       # then it rises this much more (its feet still just behind the stone's top)

      attr_reader :parts

      def initialize(f, g)
        @f = f
        @g = g
        @ev = Spirits.grave_event
        host = SpiritLook.grave_sprite(@ev)
        @own = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @own.z = Z
        @vp = host && host.viewport ? host.viewport : @own
        @z = host ? host.z - 6 : 0
        @sheet, @cols, @rows = SpiritLook.follower_of(f)
        @fw = @sheet ? @sheet.width / @cols : 0
        @fh = @sheet ? @sheet.height / @rows : 0
        @row = @rows == 4 ? facing : 0
        @top, @bottom = rows_drawn
        @glow = SpiritLook.glow_sprite(@vp, WispLook.glow(26, HALO, 0.6, 1.0, 1.8), true)
        @glow.z = @z
        @echo = part(PURPLE, 210, 1)
        @outline = OUTLINE.map { part(PURPLE, 255, 2) }
        @body = part(nil, 0, 3)
        @lilac = part(LILAC, 255, 4)
        @sparks = 4.times.map { SpiritLook.glow_sprite(@vp, WispLook.mote, false).tap { |s| s.z = @z + 5 } }
        @flash = Sprite.new(@own)
        @flash.bitmap = Bitmap.new(Graphics.width, Graphics.height)
        @flash.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(*LILAC))
        @flash.opacity = 0
        @parts = [@glow, @echo] + @outline + [@body, @lilac] + @sparks
        @frame = 0
      end

      def part(rgb, alpha, dz)
        s = Sprite.new(@vp)
        s.bitmap = @sheet
        s.color = Color.new(*rgb, alpha) if rgb
        s.z = @z + dz
        s.visible = false
        return s
      end

      # Facing you: down, left, right or up (the sheet's rows)
      def facing
        dx = $game_player.x - @g[:x]
        dy = $game_player.y - @g[:y]
        return dx < 0 ? 1 : 2 if dx.abs > dy.abs
        return dy < 0 ? 3 : 0
      end

      def ground
        return Wisps.screen_xy(@g[:x], @g[:y])
      end

      # [its picture's first row, the row after its last] in its frame (the
      # empty rows above and under it don't count as it comes up)
      def rows_drawn
        return [0, @fh] unless @sheet
        rows = (0...@fh).select do |y|
          (0...@fw).step(2).any? { |x| @sheet.get_pixel(x, @row * @fh + y).alpha > 0 }
        end
        return rows.empty? ? [0, @fh] : [rows.first, rows.last + 1]
      rescue StandardError
        return [0, @fh]
      end

      # Its picture's bottom at y, the top `shown` of it (0 to 1: coming up
      # from behind the stone), at opacity o (0 to 1)
      def show(y, shown, o)
        return unless @sheet
        sx, = ground
        h = (@top + (@bottom - @top) * shown).round
        col = (@frame / SpiritLook.frames(10)) % @cols
        cut = proc do |s, x, yy|
          s.src_rect.set(col * @fw, @row * @fh, @fw, h)
          s.ox = @fw / 2
          s.oy = h
          s.x, s.y = x, yy
        end
        cut.call(@body, sx, y)
        @body.opacity = (CAP * o).round
        cut.call(@lilac, sx, y)
        @lilac.opacity = (CAP * o * LILAC_SHARE).round
        aura = o * o
        @outline.each_with_index do |s, i|
          cut.call(s, sx + OUTLINE[i][0], y + OUTLINE[i][1])
          s.opacity = (210 * aura * (0.75 + 0.25 * Math.sin(@frame * 0.08))).round
        end
        cut.call(@echo, sx + 5 + (2 * Math.sin(@frame * 0.05)).round, y - 10 - (Math.sin(@frame * 0.07)).round)
        @echo.zoom_x = @echo.zoom_y = 1.05
        @echo.opacity = (95 * aura).round
        ([@body, @lilac, @echo] + @outline).each { |s| s.visible = h > 0 && o > 0 }
        @glow.x, @glow.y = sx, y - h / 2
        @glow.opacity = (200 * o).round
        @glow.visible = o > 0
      end

      # its spot as it comes up, and as it hovers
      def line
        return ground[1] - LINE
      end

      def hover_y
        return line - UP + (2 * Math.sin(@frame * 0.12)).round
      end

      def play(how)
        pbSEPlay("Anim/PRSFX- Curse", 60) rescue nil
        n = SpiritLook.frames(RISE)
        n.times do |i|
          k = (i + 1).to_f / n
          show(line, k, k)
          step
        end
        ::GameData::Species.play_cry_from_species(@f[:species], 0, 60, 85) rescue nil
        n = SpiritLook.frames(HOVER)
        n.times do |i|
          show(line - (UP * [(i + 1).to_f / (n / 2.0), 1.0].min).round, 1.0, 1.0) if i < n / 2
          show(hover_y, 1.0, 1.0) if i >= n / 2
          step
        end
        how == :call ? flash : drift
      end

      # Call: a lilac flash, the spirit and the grave gone under it
      def flash
        pbSEPlay("Anim/PRSFX- Shadow Ball", 70) rescue nil
        n = SpiritLook.frames(FLASH)
        n.times do |i|
          k = (i + 1).to_f / n
          show(hover_y, 1.0, 1.0)
          @flash.opacity = (200 * k).round
          grave(1 - k)
          step
        end
        @parts.each { |s| s.visible = false }
        n.times do |i|
          @flash.opacity = (200 * (1 - (i + 1).to_f / n)).round
          step
        end
      end

      # Pay Respects: it drifts up into sparks, the grave fading with it
      def drift
        pbSEPlay("Anim/PRSFX- Wish", 60) rescue nil
        n = SpiritLook.frames(DRIFT)
        sx, = ground
        y = hover_y
        n.times do |i|
          k = (i + 1).to_f / n
          show(y - (40 * k).round, 1.0, 1 - k)
          @sparks.each_with_index do |s, j|
            s.x = sx + [-12, 10, -4, 8][j] + (3 * Math.sin(@frame * 0.1 + j)).round
            s.y = y - 24 - (60 * k * (0.6 + 0.15 * j)).round
            s.opacity = (255 * (1 - k * k)).round
            s.visible = true
          end
          grave(1 - k)
          step
        end
      end

      # the grave's own fade (its event's opacity: the stone and its glows follow)
      def grave(o)
        @ev.instance_variable_set(:@opacity, (255 * o).round) if @ev
      end

      def step
        @frame += 1
        SpiritLook.tick
      end

      def dispose
        @parts.each do |s|
          next if s.disposed?
          s.bitmap = nil if @sheet && s.bitmap.equal?(@sheet)
          s.dispose
        end
        @flash.bitmap.dispose unless @flash.bitmap.disposed?
        @flash.dispose
        @sheet.dispose if @sheet && !@sheet.disposed?
        @own.dispose unless @own.disposed?
      end
    end

    #--------------------------------------------------------------------------
    # At rest, its gift
    #--------------------------------------------------------------------------
    def at_rest(f)
      pbMessage(_INTL("{1}'s spirit is at rest.", f[:name]))
    end

    def gift(f, item, count, own)
      name = (::GameData::Item.get(item).name rescue item.to_s)
      if own
        pbMessage(_INTL("It left its {1} behind.", name))
      else
        pbMessage(_INTL("It left something behind..."))
      end
      got = if defined?(pbReceiveItem)
              pbReceiveItem(item, count)
            elsif $PokemonBag
              $PokemonBag.pbStoreItem(item, count)
            end
      to_pc(item, count, name) unless got
    rescue StandardError => e
      GhostlyPossession.log("The spirit's gift couldn't be given: #{e.class}: #{e.message}")
    end

    # A full Bag: to the PC's item storage, as KIF's level caps do, never lost
    def to_pc(item, count, name)
      return unless $PokemonGlobal && defined?(::PCItemStorage)
      $PokemonGlobal.pcItemStorage ||= ::PCItemStorage.new
      if ($PokemonGlobal.pcItemStorage.pbStoreItem(item, count) rescue false)
        pbMessage(_INTL("Your Bag is full: The {1} was sent to your PC.", name))
      else
        GhostlyPossession.log("The spirit's gift (#{item} x#{count}) couldn't be stored anywhere")
      end
    end

    #--------------------------------------------------------------------------
    # It came back
    #--------------------------------------------------------------------------
    def came_back_words(f)
      return _INTL("{1}'s spirit came back to you. It's a Ghost now, but it remembers you, its name and its moves.", f[:name])
    end

    def came_back(spirit, f)
      if kr?
        place = (::KIF::Nuzlocke.place_name($game_map.map_id) rescue nil)
        note = Spirits.nuzlocke? && place ? _INTL("Nuzlocke: {1} is back on your team. It doesn't use up {2}'s encounter.", f[:name], place) : nil
        args = { :title => _INTL("{1} Came Back!", f[:name]), :rgb => Card::GHOST_RGB, :buttons => [_INTL("OK")],
                 :before => picture_pokemon(f), :after => spirit, :ghost => nil, :before_name => f[:name],
                 :after_name => spirit.name, :body => came_back_words(f), :note => note, :changed => :after, :pills => true,
                 :middle => nil, :cancel => true, :disabled => [] }
        scene = BackScene.new(args)
        begin
          scene.run(0)
        ensure
          scene.dispose
        end
      else
        window = Returned.new(picture_pokemon(f), spirit, f[:name])
        begin
          pbMessage(_INTL("{1} came back to you!\\nIt's a Ghost now, but it remembers you.", f[:name])) { window.update }
        ensure
          window.dispose
        end
      end
    rescue StandardError => e
      GhostlyPossession.log("The came-back card couldn't be shown: #{e.class}: #{e.message}")
    end

    # The card with its old picture faded like a spirit
    class BackScene < Card::Scene
      def draw(choice, pictures = true)
        super
        GhostlyPossession::SpiritLook.spirit!(@icons.first) if pictures
      end
    end

    # On its own: old (faded) -> new, names under, the new one's lavender
    class Returned
      X = 70
      Y = 40
      W = 372
      H = 124

      def initialize(old, now, name)
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = Alone::Z
        @window = SpriteWindow_Base.new(X, Y, W, H)
        @window.viewport = @viewport
        @old = old ? Alone.icon(old, @viewport, @window.z + 1, X + 96, Y + 52) : nil
        SpiritLook.spirit!(@old)
        @now = Alone.icon(now, @viewport, @window.z + 1, X + W - 96, Y + 52)
        @overlay = Sprite.new(@viewport)
        @overlay.bitmap = Bitmap.new(Graphics.width, Graphics.height)
        @overlay.z = @window.z + 2
        b = @overlay.bitmap
        base, shadow = getDefaultTextColors(@window.windowskin)
        pbSetSystemFont(b)
        Shapes.arrow(b, X + W / 2 - 18, X + W / 2 + 18, Y + 52, base)
        pbDrawTextPositions(b, [[name.to_s, X + 96, Y + 80, 2, base, shadow],
                                [now.name.to_s, X + W - 96, Y + 80, 2, Alone::LAVENDER[0], Alone::LAVENDER[1]]])
      end

      def update
        @window.update
        [@old, @now].compact.each(&:update)
      end

      def dispose
        [@old, @now].compact.each { |s| s.dispose unless s.disposed? }
        @overlay.bitmap.dispose if @overlay.bitmap && !@overlay.bitmap.disposed?
        @overlay.dispose unless @overlay.disposed?
        @window.dispose unless @window.disposed?
        @viewport.dispose unless @viewport.disposed?
      end
    end

    #--------------------------------------------------------------------------
    # In battle: see-through and lilac, with the Outline and Echo
    #--------------------------------------------------------------------------
    module SpiritSprite
      def update(*args)
        ret = super
        gp_spirit
        return ret
      end

      def opacity=(value)
        value = [value, CAP].min if GhostlyPossession::Spirits.spirit?(@pkmn)
        super(value)
        gp_spirit if @gp_spirit && !@gp_spirit_busy
        value
      end

      [:x=, :y=, :z=, :visible=, :zoom_x=, :zoom_y=].each do |m|
        define_method(m) do |value|
          super(value)
          gp_spirit if @gp_spirit && !@gp_spirit_busy
          value
        end
      end

      def dispose
        gp_spirit_off
        super
      end

      def gp_spirit
        return gp_spirit_off unless !disposed? && self.bitmap && GhostlyPossession::Spirits.spirit?(@pkmn)
        @gp_spirit_busy = true
        self.opacity = CAP if self.opacity > CAP
        @gp_spirit ||= [GhostlyPossession::BattleLook::Aura.new(self.viewport), Sprite.new(self.viewport)]
        aura, lilac = @gp_spirit
        x = @spriteX.to_i + @spriteXExtra.to_i
        y = @spriteY.to_i + @spriteYExtra.to_i
        aura.sync(self, x, y)
        aura.copy(self, lilac, x, y, self.visible)
        lilac.z = self.z + 1
        lilac.color = Color.new(*LILAC, 255)
        lilac.opacity = (self.opacity * LILAC_SHARE).round
      rescue StandardError => e
        gp_spirit_off
        GhostlyPossession.log("The spirit's look couldn't be drawn: #{e.class}: #{e.message}")
      ensure
        @gp_spirit_busy = false
      end

      def gp_spirit_off
        return unless @gp_spirit
        aura, lilac = @gp_spirit
        aura.dispose
        lilac.bitmap = nil unless lilac.disposed?
        lilac.dispose unless lilac.disposed?
        @gp_spirit = nil
      end
    end

    # It fades (after its 5 turns)
    def fade(battle, battler)
      scene = battle.scene
      sprite = scene.respond_to?(:sprites) && scene.sprites ? scene.sprites["pokemon_#{battler.index}"] : nil
      pbSEPlay("Darkness6", 60) rescue nil
      return unless sprite && !sprite.disposed?
      from = sprite.opacity
      BattleLook.animate(scene, frames(FADE)) { |k| sprite.opacity = (from * (1 - k)).round }
    rescue StandardError => e
      GhostlyPossession.log("The spirit couldn't fade: #{e.class}: #{e.message}")
    end

    def refresh_box(battle, battler)
      scene = battle.scene
      scene.pbRefreshOne(battler.index) if scene.respond_to?(:pbRefreshOne)
    rescue StandardError
      nil
    end

    #--------------------------------------------------------------------------
    # The Restless Pill
    #--------------------------------------------------------------------------
    PILL_H = 13
    PILL_FONT = 13

    # Drawn as EBDX's stat-stage pills are (a dark edge, the fill, white
    # words); its width
    def draw_pill(b, n)
      b.clear
      return 0 unless n
      pbSetSmallFont(b)
      b.font.size = PILL_FONT
      label = _INTL("RESTLESS {1}", n)
      w = b.text_size(label).width + 3
      b.fill_rect(0, 0, w, PILL_H, Color.new(8, 8, 8, 215))
      b.fill_rect(1, 1, w - 2, PILL_H - 2, Color.new(*PILL))
      b.font.color = Color.new(255, 255, 255)
      b.draw_text(1, 3, w, PILL_H, label, 0)
      return w
    end

    # EBDX: its own sprite of the box's, in the stat-stage pills' row, the
    # stat-stage pills moved along after it while it shows
    module EBDXRestless
      def setUp(*args)
        ret = super
        GhostlyPossession::SpiritLook.pill_sprite_ebdx(@sprites, @viewport)
        return ret
      end

      def refresh(*args)
        ret = super
        GhostlyPossession::SpiritLook.pill_ebdx(@sprites, @battler)
        return ret
      end
    end

    def pill_sprite_ebdx(sprites, viewport)
      ss = sprites && sprites["statStages"]
      s = Sprite.new(viewport)
      s.bitmap = Bitmap.new(96, 16)
      s.z = ss ? ss.z : 10
      s.ex = ss ? ss.ex : 20
      s.ey = ss ? ss.ey : 23
      s.instance_variable_set(:@gp_ss_ex, ss ? ss.ex : nil)
      sprites["gpRestless"] = s
    rescue StandardError => e
      GhostlyPossession.log("The EBDX Restless Pill couldn't be made: #{e.class}: #{e.message}")
    end

    def pill_ebdx(sprites, battler)
      s = sprites && sprites["gpRestless"]
      return unless s && s.bitmap && !s.bitmap.disposed?
      n = battler ? Spirits.turns_left(battler.pokemon) : nil
      w = draw_pill(s.bitmap, n)
      ss = sprites["statStages"]
      ss_ex = s.instance_variable_get(:@gp_ss_ex)
      ss.ex = w > 0 ? s.ex + w + 2 : ss_ex if ss && ss_ex
      base = sprites["base"]
      if base
        s.x = base.x + s.ex
        s.y = base.y + s.ey
        ss.x = base.x + ss.ex if ss && ss.respond_to?(:ex)
      end
    rescue StandardError => e
      GhostlyPossession.log("The EBDX Restless Pill couldn't be drawn: #{e.class}: #{e.message}")
    end

    # PIF: its own sprite in the box's sprites (so it fades, hides and goes
    # with the box), under the HP bar past KIF's status icon; moved with it
    PIF_PILL = [60, 11].freeze     # from the HP bar's corner: level with KIF's status icon, past it

    module PIFRestless
      def refresh(*args)
        ret = super
        GhostlyPossession::SpiritLook.pill_pif(@sprites, @battler, @hpBar, self.viewport)
        return ret
      end

      def x=(value)
        super
        GhostlyPossession::SpiritLook.place_pill_pif(@sprites, @hpBar)
      end

      def y=(value)
        super
        GhostlyPossession::SpiritLook.place_pill_pif(@sprites, @hpBar)
      end
    end

    def pill_pif(sprites, battler, hp_bar, viewport)
      return unless sprites && hp_bar
      n = battler ? Spirits.turns_left(battler.pokemon) : nil
      s = sprites["gpRestless"]
      if !s && n
        # (the box may be hidden already, as it is before the send-out: shown as its bar is)
        s = Sprite.new(viewport)
        s.bitmap = Bitmap.new(96, 16)
        s.visible = hp_bar.visible
        s.opacity = hp_bar.opacity
        sprites["gpRestless"] = s
      end
      return unless s && s.bitmap && !s.bitmap.disposed?
      draw_pill(s.bitmap, n)
      s.z = hp_bar.z + 1
      place_pill_pif(sprites, hp_bar)
    rescue StandardError => e
      GhostlyPossession.log("The Restless Pill couldn't be drawn: #{e.class}: #{e.message}")
    end

    def place_pill_pif(sprites, hp_bar)
      s = sprites && sprites["gpRestless"]
      return unless s && hp_bar && !s.disposed?
      s.x = hp_bar.x + PIF_PILL[0]
      s.y = hp_bar.y + PIF_PILL[1]
    end

    def boot
      ::Sprite_Character.prepend(GraveSprite) if defined?(::Sprite_Character) && !::Sprite_Character.ancestors.include?(GraveSprite)
      ::PokemonBattlerSprite.prepend(SpiritSprite) if defined?(::PokemonBattlerSprite) && !::PokemonBattlerSprite.ancestors.include?(SpiritSprite)
      ::PokemonDataBox.prepend(PIFRestless) if defined?(::PokemonDataBox) && !::PokemonDataBox.ancestors.include?(PIFRestless)
      if defined?(::DataBoxEBDX) && ::DataBoxEBDX.method_defined?(:refresh) && ::DataBoxEBDX.method_defined?(:setUp) &&
         !::DataBoxEBDX.ancestors.include?(EBDXRestless)
        ::DataBoxEBDX.prepend(EBDXRestless)
      end
      return true
    end
  end
end
