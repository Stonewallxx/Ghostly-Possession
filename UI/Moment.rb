#==============================================================================
# Ghostly Possession: the moment on the map
#==============================================================================
# The Chill (Chill, Then a Card, his pick 2026-10-24): the screen goes cold
# and dark at the edges, the Ghost drifts down into the player (KIF has no
# following Pokémon, so it's the player it reaches) and sinks in with a
# glow; then the card, while the chill holds; then the chill lifts. Both
# looks share it.
#
#   GhostlyPossession::Moment.possessed(note) { the card }
#
# Leaving (A Card After the Battle) and casting out (Cast-Out Card), his
# picks 2026-10-24, the same way: the chill, then the Ghost rising out of
# the player and fading away, or staying, hovering, when it lingers; or a
# cold white flash and the Ghost torn out, shaking. Then the card.
#
#   GhostlyPossession::Moment.leaving(note, lingers) { the card }
#   GhostlyPossession::Moment.cast_out(note) { the card }
#
# Nothing saved is touched (no screen tone or flash): it's all sprites on a
# viewport of its own, over the map and under the game's messages.
#==============================================================================

module GhostlyPossession
  module Moment
    Z = 99_000                     # over the map, under messages (99_999)
    # frames at 60 a second (scaled to the game's frame rate)
    CHILL_IN = 20
    DRIFT = 54
    SINK = 16
    HOLD = 10
    CHILL_OUT = 16
    EMERGE = 30                    # rising out of the player
    FADE_AWAY = 44                 # drifting off and gone
    FLASH = 18                     # the cold white flash fading
    CARD_CHILL = 150               # the chill's opacity under the card
    GLOW_RINGS = [[30, 40], [24, 70], [18, 100], [12, 130]].freeze   # [radius, alpha]

    module_function

    def frames(n)
      rate = Graphics.respond_to?(:frame_rate) ? Graphics.frame_rate.to_i : 60
      return [(n * rate / 60.0).round, 1].max
    end

    # On the map with the player there: the moment, else just the card
    def possessed(note, &card)
      return play(note, :play_in, &card)
    end

    def leaving(note, lingers, &card)
      return play(note, lingers ? :play_lingers : :play_left, &card)
    end

    def cast_out(note, &card)
      return play(note, :play_cast, &card)
    end

    # (walking wild Pokémon, Hoenn's, start no battle in the middle of it:
    # the game's own switch for cutscenes, put back as it was)
    def play(note, how)
      return yield unless $scene.is_a?(::Scene_Map) && $game_player
      scene = Scene.new(note)
      temp = $PokemonTemp && $PokemonTemp.respond_to?(:prevent_ow_battles=) ? $PokemonTemp : nil
      calm_was = temp.prevent_ow_battles if temp
      temp.prevent_ow_battles = true if temp
      begin
        scene.send(how)
        result = yield
        scene.play_out
        return result
      ensure
        scene.dispose
        temp.prevent_ow_battles = calm_was if temp
      end
    end

    # The cold: a dim purple, darker toward the edges (fills replace what's
    # under them, so the bands go from the middle out)
    def chill_bitmap(w, h)
      b = Bitmap.new(w, h)
      b.fill_rect(0, 0, w, h, Color.new(30, 6, 60, 90))
      10.times do |i|
        col = Color.new(12, 0, 30, 90 + (10 - i) * 11)
        b.fill_rect(0, i * 6, w, 6, col)
        b.fill_rect(0, h - (i + 1) * 6, w, 6, col)
        b.fill_rect(i * 6, i * 6, 6, h - i * 12, col)
        b.fill_rect(w - (i + 1) * 6, i * 6, 6, h - i * 12, col)
      end
      return b
    end

    # The glow round the player
    def glow_bitmap
      r = GLOW_RINGS[0][0]
      b = Bitmap.new(2 * r + 1, 2 * r + 1)
      GLOW_RINGS.each { |radius, alpha| disc(b, r, r, radius, Color.new(170, 100, 255, alpha)) }
      return b
    end

    def disc(b, cx, cy, r, col)
      (-r..r).each do |dy|
        w = Math.sqrt(r * r - dy * dy).round
        b.fill_rect(cx - w, cy + dy, 2 * w + 1, 1, col)
      end
    end

    # The Ghost's overworld picture (Followers: <SPECIES>_fly or <SPECIES>,
    # the shiny ones in Shiny/), else Gastly's
    def follower_bitmap(ghost, shiny)
      names = []
      [ghost, :GASTLY].uniq.each do |s|
        names << "Graphics/Characters/Followers/Shiny/#{s}_fly" << "Graphics/Characters/Followers/Shiny/#{s}" if shiny
        names << "Graphics/Characters/Followers/#{s}_fly" << "Graphics/Characters/Followers/#{s}"
      end
      names.each do |n|
        path = pbResolveBitmap(n)
        return Bitmap.new(path) if path
      end
      return nil
    rescue StandardError
      return nil
    end

    #--------------------------------------------------------------------------
    # The moment's sprites
    #--------------------------------------------------------------------------
    class Scene
      attr_reader :viewport

      def initialize(note)
        @note = note || {}
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = Z
        @chill = Sprite.new(@viewport)
        @chill.bitmap = Moment.chill_bitmap(Graphics.width, Graphics.height)
        @chill.z = 0
        @glow = Sprite.new(@viewport)
        @glow.bitmap = Moment.glow_bitmap
        @glow.ox = @glow.oy = GLOW_RINGS[0][0]
        @glow.z = 1
        @trail = Sprite.new(@viewport)
        @ghost = Sprite.new(@viewport)
        @flash = Sprite.new(@viewport)
        @flash.bitmap = Bitmap.new(Graphics.width, Graphics.height)
        @flash.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(248, 248, 255))
        @flash.z = 2                   # over the map and the glow, under the Ghost: it shows dark against it
        @flash.opacity = 0
        sheet = Moment.follower_bitmap(@note[:ghost], @note[:ghost_shiny])
        [@trail, @ghost].each_with_index do |s, i|
          s.bitmap = sheet
          s.z = 2 + i
          next unless sheet
          fw = sheet.width / 4
          fh = sheet.height / 4
          s.src_rect = Rect.new(0, 0, fw, fh)   # facing down
          s.ox = fw / 2
          s.oy = fh / 2
        end
        @frame = 0
        set(:chill => 0, :glow => 0, :ghost => nil)
      end

      # Where the player's middle is on screen
      def player_xy
        return [$game_player.screen_x, $game_player.screen_y - 24]
      end

      # Everything for one moment: :chill (0-255), :glow (0-255), :ghost
      # (0 to 1 along its way down, or nil when it's not there), :sink (0 to
      # 1 as it sinks in)
      def set(state)
        px, py = player_xy
        @chill.opacity = state[:chill]
        @glow.x = px
        @glow.y = py
        @glow.opacity = state[:glow]
        t = state[:ghost]
        [@ghost, @trail].each { |s| s.visible = !t.nil? && !s.bitmap.nil? }
        return unless t && @ghost.bitmap
        place(@ghost, px, py, t, state[:sink] || 0)
        place(@trail, px, py, [t - 0.18, 0].max, 0)
        @trail.opacity = t >= 1 ? 0 : 70
        # its frames turn as it drifts
        col = (@frame / Moment.frames(10)) % 4
        [@ghost, @trail].each { |s| s.src_rect.x = col * s.src_rect.width }
      end

      # Down from up and to the right, swaying, slow at both ends, then
      # shrinking into the player
      def place(s, px, py, t, sink)
        ease = t * t * (3 - 2 * t)
        s.x = (px + 56 * (1 - ease) + 6 * Math.sin(t * Math::PI * 3)).round
        s.y = (py - 110 * (1 - ease) - 6).round
        s.zoom_x = s.zoom_y = 1.0 - 0.7 * sink
        s.opacity = ((t < 0.2 ? t / 0.2 : 1.0) * 220 * (1 - sink)).round
      end

      def tick
        @frame += 1
        Graphics.update
        Input.update
        pbUpdateSceneMap
      end

      # The chill comes in, the Ghost drifts down and sinks into the player
      def play_in
        pbSEPlay("Anim/PRSFX- Curse", 70) rescue nil
        n = Moment.frames(CHILL_IN)
        n.times { |i| set(:chill => 255 * (i + 1) / n, :glow => 0, :ghost => nil); tick }
        ::GameData::Species.play_cry_from_species(@note[:ghost], 0, 70, 85) rescue nil
        n = Moment.frames(DRIFT)
        n.times { |i| set(:chill => 255, :glow => 60 * (i + 1) / n, :ghost => (i + 1).to_f / n); tick }
        pbSEPlay("Anim/PRSFX- Grudge", 70) rescue nil
        n = Moment.frames(SINK)
        n.times { |i| set(:chill => 255, :glow => 60 + 195 * (i + 1) / n, :ghost => 1.0, :sink => (i + 1).to_f / n); tick }
        Moment.frames(HOLD).times { tick }
        set(:chill => CARD_CHILL, :glow => 140, :ghost => nil)
      end

      # The chill lifts (a Ghost still hovering fades with it)
      def play_out
        n = Moment.frames(CHILL_OUT)
        chill0 = @chill.opacity
        glow0 = @glow.opacity
        ghost0 = @ghost.visible ? @ghost.opacity : 0
        n.times do |i|
          k = (n - i - 1).to_f / n
          chill_glow(chill0 * k, glow0 * k)
          @ghost.opacity = (ghost0 * k).round if @ghost.visible
          tick
        end
        @ghost.visible = @trail.visible = false
      end

      #------------------------------------------------------------------------
      # Leaving and casting out
      #------------------------------------------------------------------------
      def chill_glow(chill, glow)
        px, py = player_xy
        @chill.opacity = chill.round
        @glow.x = px
        @glow.y = py
        @glow.opacity = glow.round
      end

      # The Ghost at x, y (its frames turning), the trail hidden
      def float(x, y, zoom, opacity)
        @trail.visible = false
        return unless @ghost.bitmap
        @ghost.visible = true
        @ghost.x = x.round
        @ghost.y = y.round
        @ghost.zoom_x = @ghost.zoom_y = zoom
        @ghost.opacity = opacity.round
        @ghost.src_rect.x = ((@frame / Moment.frames(10)) % 4) * @ghost.src_rect.width
      end

      # Hovering over the player, swaying
      def hover(chill, glow)
        px, py = player_xy
        chill_glow(chill, glow)
        float(px + 4 * Math.sin(@frame * 0.08), py - 44 + 4 * Math.sin(@frame * 0.05), 1.0, 220)
      end

      # The chill comes in, the Ghost rises out of the player, growing
      def emerge
        n = Moment.frames(CHILL_IN)
        n.times { |i| chill_glow(255 * (i + 1) / n, 0); tick }
        px, py = player_xy
        n = Moment.frames(EMERGE)
        n.times do |i|
          k = (i + 1).to_f / n
          chill_glow(255, 160 * k)
          float(px, py - 40 * k, 0.3 + 0.7 * k, 220 * k)
          tick
        end
      end

      # It leaves: out of the player, then off and gone
      def play_left
        emerge
        pbSEPlay("Anim/PRSFX- Grudge", 60) rescue nil
        px, py = player_xy
        n = Moment.frames(FADE_AWAY)
        n.times do |i|
          k = (i + 1).to_f / n
          chill_glow(255, 160 * (1 - k))
          float(px - 50 * k + 4 * Math.sin(k * 9), py - 40 - 70 * k, 1.0, 220 * (1 - k))
          tick
        end
        @ghost.visible = false
        Moment.frames(HOLD).times { tick }
        chill_glow(CARD_CHILL, 0)
      end

      # It lingers: out of the player, and it stays, hovering
      def play_lingers
        emerge
        ::GameData::Species.play_cry_from_species(@note[:ghost], 0, 80, 100) rescue nil
        Moment.frames(HOLD * 2).times { hover(255, 120); tick }
        hover(CARD_CHILL, 60)
      end

      # Cast out: a cold white flash, the Ghost torn out above the player,
      # shaking, then hovering
      def play_cast
        n = Moment.frames(CHILL_IN / 2)
        n.times { |i| chill_glow(255 * (i + 1) / n, 0); tick }
        pbSEPlay("Anim/PRSFX- Hex", 80) rescue nil
        px, py = player_xy
        n = Moment.frames(FLASH)
        n.times do |i|
          k = (i + 1).to_f / n
          @flash.opacity = (230 * (1 - k)).round
          chill_glow(255, 0)
          float(px + rand(5) - 2, py - 50 + rand(5) - 2, 1.0, 230)
          tick
        end
        @flash.opacity = 0
        ::GameData::Species.play_cry_from_species(@note[:ghost], 0, 80, 110) rescue nil
        Moment.frames(HOLD).times { hover(255, 0); tick }
        hover(CARD_CHILL, 0)
      end

      def dispose
        sheet = @ghost.bitmap
        [@chill, @glow, @flash].each { |s| s.bitmap.dispose if s.bitmap && !s.bitmap.disposed? }
        sheet.dispose if sheet && !sheet.disposed?
        [@chill, @glow, @flash, @trail, @ghost].each { |s| s.dispose unless s.disposed? }
        @viewport.dispose unless @viewport.disposed?
      end
    end
  end
end
