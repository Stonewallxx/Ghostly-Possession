#==============================================================================
# Ghostly Possession: the Possession command and its Info Popup
#==============================================================================
# A possessed Pokémon's party menu has Possession (Info Popup, his pick
# 2026-10-24): which Ghost is inside, its Will and how long it'll stay (as
# hints, not numbers: his pick), and its move.
#
#   On its own: Possession after Summary in the game's command list, then a
#   window in the player's menu frame with those lines, over the party
#   screen's own message.
#   With Kanto Reloaded: Possession in its Party Screen's menu (a mod's
#   command), then a popup on the screen: the Ghost on a purple disc, WILL,
#   STAY, ITS MOVE, what happens when it leaves, and Cast It Out ("Uses 1
#   Cleanse Tag (you have 2)": green when there's one, red when there isn't).
#
# Casting it out: on its own, "Use a Cleanse Tag to cast it out? You have
# 2." Yes or No. Then the menus close themselves and it happens on the map
# (Leave.request).
#==============================================================================

module GhostlyPossession
  module Info
    WILLS = ["It's quiet.", "It stirs now and then.", "It's restless."].freeze
    Z = 100_000                    # over the party screen (99_999)

    module_function

    def will_hint(note)
      return _INTL(WILLS[note[:will]] || WILLS[1])
    end

    # by the battles it has left: the hint stays true as they count down
    def stay_hint(note)
      left = note[:battles_left].to_i
      return _INTL("It won't stay long.") if left <= Ghosts::STAY_HINTS[0]
      return _INTL("It'll stay a while.") if left <= Ghosts::STAY_HINTS[1]
      return _INTL("It's settling in.")
    end

    def move_name(note)
      return ::GameData::Move.get(note[:move]).name
    rescue StandardError
      return note[:move].to_s
    end

    def tags
      return CleanseTag.count
    end

    # The Possession command, from either party screen
    def open(scene, pkmn)
      note = Note.read(pkmn)
      return false unless note
      if UI.kr? && defined?(::Reloaded::PartyScene) && scene.is_a?(::Reloaded::PartyScene)
        return popup(scene, pkmn, note)
      end
      return alone(scene, pkmn, note)
    rescue StandardError => e
      GhostlyPossession.log("Possession info couldn't be shown: #{e.class}: #{e.message}")
      return false
    end

    #--------------------------------------------------------------------------
    # On its own: a window in the menu frame, then the screen's own message
    #--------------------------------------------------------------------------
    def alone(scene, pkmn, note)
      window = Window.new(pkmn, note)
      begin
        n = tags
        if n > 0
          question = _INTL("Use a Cleanse Tag to cast it out?\\nYou have {1}.", n)
          yes = scene.respond_to?(:pbDisplayConfirm) ? scene.pbDisplayConfirm(question) : pbConfirmMessage(question)
          if yes
            Leave.request(pkmn)
            return true
          end
        else
          text = _INTL("A Cleanse Tag would cast it out.\\nYou have none.")
          scene.respond_to?(:pbDisplay) ? scene.pbDisplay(text) : pbMessage(text)
        end
      ensure
        window.dispose
      end
      return false
    end

    class Window
      X = 40
      Y = 24
      W = 432
      H = 192

      def initialize(pkmn, note)
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = Z
        @window = SpriteWindow_Base.new(X, Y, W, H)
        @window.viewport = @viewport
        @overlay = Sprite.new(@viewport)
        @overlay.bitmap = Bitmap.new(Graphics.width, Graphics.height)
        @overlay.z = @window.z + 1
        base, shadow = getDefaultTextColors(@window.windowskin)
        ghostly = isDarkWindowskin(@window.windowskin) ? Alone::LAVENDER : Alone::PURPLE
        ghost = UI.ghost_name(note)
        b = @overlay.bitmap
        pbSetSystemFont(b)
        pbDrawTextPositions(b, [[_INTL("{1} {2} is inside {3}.", UI.article(ghost), ghost, pkmn.name), X + 24, Y + 10, 0, ghostly[0], ghostly[1]],
                                [Info.will_hint(note), X + 24, Y + 46, 0, base, shadow],
                                [Info.stay_hint(note), X + 24, Y + 78, 0, base, shadow],
                                [_INTL("Its move: {1}", Info.move_name(note)), X + 24, Y + 114, 0, base, shadow]])
      end

      def dispose
        @overlay.bitmap.dispose if @overlay.bitmap && !@overlay.bitmap.disposed?
        @overlay.dispose unless @overlay.disposed?
        @window.dispose unless @window.disposed?
        @viewport.dispose unless @viewport.disposed?
      end
    end

    #--------------------------------------------------------------------------
    # With Kanto Reloaded: a popup on its Party Screen
    #--------------------------------------------------------------------------
    # scene: the Party Screen, or the Overworld Menu (the readout's A), which
    # has no popup hints of its own: then they're drawn with the popup
    def popup(scene, pkmn, note)
      buttons = [_INTL("Cast It Out"), _INTL("Close")]
      pic = (::Reloaded::PartyIcons.species_bitmap(note[:ghost]) rescue nil)
      choice = tags > 0 ? 0 : 1
      cast = false
      hints = [[:lr, _INTL("Choose")], [button(:C), _INTL("Select")], [button(:B), _INTL("Close")]]
      @own_hints = scene.respond_to?(:with_popup_hints) ? nil : hints
      run = proc { |&body| @own_hints ? body.call : scene.with_popup_hints(hints, &body) }
      run.call do
        draw_popup(scene.overlay, scene.palette, pkmn, note, pic, buttons, choice)
        loop do
          Graphics.update
          Input.update
          scene.update_frame if scene.respond_to?(:update_frame)
          pt = ::Reloaded::Pointer
          picked = nil
          if pt.moved? && (i = pt.hit(@hits)) && i != choice
            choice = i
            pbPlayCursorSE
            draw_popup(scene.overlay, scene.palette, pkmn, note, pic, buttons, choice)
          end
          if pt.right? || Input.trigger?(Input::BACK)
            pbPlayCancelSE
            break
          elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
            choice = 1 - choice
            pbPlayCursorSE
            draw_popup(scene.overlay, scene.palette, pkmn, note, pic, buttons, choice)
          elsif pt.left? && (i = pt.hit(@hits))
            picked = i
          elsif Input.trigger?(Input::USE)
            picked = choice
          end
          next unless picked
          if picked == 1
            pbPlayCancelSE
            break
          elsif tags > 0
            pbPlayDecisionSE
            cast = true
            break
          else
            pbPlayBuzzerSE
          end
        end
      end
      Leave.request(pkmn) if cast
      return cast
    ensure
      @own_hints = nil
      pic.dispose if pic && !pic.disposed?
      scene.overlay.clear if scene.respond_to?(:overlay) && scene.overlay && !scene.overlay.disposed?
      scene.refresh if scene.respond_to?(:refresh)
    end

    def draw_popup(o, c, pkmn, note, pic, buttons, choice)
      kp = ::Reloaded::Pixel
      kf = ::KIF::PixelFont
      dg = ::Reloaded::Dialogs
      ink = PartyLook.ink(c)
      x0 = 76
      w = 360
      o.clear
      dg.send(:dim, o)
      words = GhostBattle.catchable?(note) ? _INTL("If it leaves by itself, you may get a battle to catch it. Cast it out and you always will.") :
                                             _INTL("If it leaves by itself, it may stay to fight. Cast it out and it always will.")
      lines = kp.small_wrap(o, words, w - 28)
      h = 156 + lines.length * 16 + 4 + 18 + 44
      y0 = (384 - kp::HINT_H - h) / 2
      ghost = UI.ghost_name(note)
      dg.send(:panel, o, c, x0, y0, w, h, ink)
      dg.send(:title_bar, o, c, x0, y0, w, _INTL("Possessed by {1}", ghost), ink, ink, ink)
      # the Ghost on a purple disc, its Will, Stay and move beside it
      ::Reloaded::PartyPaint.disc(o, x0 + 58, y0 + 88, 38, ::Reloaded::Palette.mix(c[:panel2], ink, 0.25))
      picture(o, pic, x0 + 58, y0 + 88) if pic
      x = x0 + 112
      [[_INTL("WILL"), will_hint(note)], [_INTL("STAY"), stay_hint(note)]].each_with_index do |(k, v), j|
        y = y0 + 48 + j * 34
        kp.text(o, x, y, 120, 12, k, c[:dim], kf::TINY)
        kp.text(o, x, y + 12, w - 124, 18, v, c[:txt], kf::TEXT)
      end
      y = y0 + 116
      kp.text(o, x, y, 120, 12, _INTL("ITS MOVE"), c[:dim], kf::TINY)
      type = (::GameData::Move.get(note[:move]).type rescue :GHOST)
      rgb = defined?(::Reloaded::PartyScreen) ? ::Reloaded::PartyScreen.type_rgb(type) : Card::GREY_RGB
      o.fill_rect(x, y + 15, 4, 12, Color.new(*rgb))
      kp.text(o, x + 9, y + 12, 160, 18, move_name(note), c[:txt], kf::TEXT)
      o.fill_rect(x0 + 12, y0 + 150, w - 24, 1, c[:line])
      y = y0 + 156
      lines.each do |ln|
        kp.small(o, x0 + 14, y, w - 28, 16, ln, c[:dim])
        y += 16
      end
      # what casting it out costs: green when there's a tag, red when not
      n = tags
      cost = n > 0 ? _INTL("Uses 1 Cleanse Tag (you have {1})", n) : _INTL("Needs a Cleanse Tag (you have none)")
      kp.small(o, x0 + 14, y + 4, w - 28, 16, cost, n > 0 ? c[:green] : c[:red])
      # the buttons, sharing the row
      by = y0 + h - 40
      gap = 8
      bw = (w - 28 - gap * (buttons.length - 1)) / buttons.length
      @hits = []
      buttons.each_with_index do |label, i|
        bx = x0 + 14 + i * (bw + gap)
        @hits << [i, bx, by, bx + bw, by + 28]
        dg.send(:button, o, c, bx, by, bx + bw, by + 28, i == choice)
        kp.text(o, bx, by + 2, bw, 24, label, i == choice ? (c[:strong] || c[:white]) : c[:txt], kf::TEXT, 2)
      end
      # (over a screen with no popup hints of its own: its hints, over the screen's)
      kp.hints(o, o, c, @own_hints, ::Reloaded::Prompts.style) if @own_hints
    end

    # A species picture (Kanto Reloaded's: Big Pokémon Icons too), its first
    # frame, centred on x, y: a small icon at its own size, a bigger one
    # scaled down to fit
    def picture(o, pic, x, y)
      f = [pic.height, 1].max
      size = f > 64 ? 72 : f
      o.stretch_blt(Rect.new(x - size / 2, y - size / 2, size, size), pic, Rect.new(0, 0, f, f))
    end

    def button(sym)
      return ::Reloaded::Prompts.input(sym) || ::Reloaded::Prompts.name(sym)
    end

    #--------------------------------------------------------------------------
    # The command in the party menu
    #--------------------------------------------------------------------------
    # On its own: Possession after Summary in the game's list (not in battle;
    # Kanto Reloaded's Party Screen has its own command)
    module GameCommand
      def pbShowCommands(helptext, commands, index = 0)
        pkmn = gp_possession_for(helptext, commands)
        return super unless pkmn
        at = commands.index(_INTL("Summary")) + 1
        shown = commands.dup.insert(at, _INTL("Possession"))
        ret = super(helptext, shown, index >= at ? index + 1 : index)
        return ret if ret < at
        return ret - 1 if ret > at
        GhostlyPossession::Info.open(self, pkmn)
        pbRefresh rescue nil
        return commands.length - 1      # "Cancel": nothing more to do
      end

      def gp_possession_for(helptext, commands)
        return nil if defined?(::Reloaded::PartyScene) && is_a?(::Reloaded::PartyScene)
        return nil if $game_temp && $game_temp.in_battle
        return nil unless commands.is_a?(Array) && commands.last == _INTL("Cancel") && commands.include?(_INTL("Summary"))
        idx = @kif_last_choice.is_a?(Integer) ? @kif_last_choice : @activecmd
        pkmn = idx.is_a?(Integer) && idx >= 0 && @party ? @party[idx] : nil
        return nil unless pkmn && helptext == _INTL("Do what with {1}?", pkmn.name)
        return GhostlyPossession::Note.possessed?(pkmn) ? pkmn : nil
      rescue StandardError
        return nil
      end
    end

    def boot
      if defined?(::PokemonParty_Scene) && !::PokemonParty_Scene.ancestors.include?(GameCommand)
        ::PokemonParty_Scene.prepend(GameCommand)
      end
      if KR.has?(:PartyScreen)
        ::Reloaded::PartyScreen.add_command(:ghostly_possession,
          :label => proc { |pkmn| GhostlyPossession::Note.possessed?(pkmn) ? _INTL("Possession") : nil },
          :description => _INTL("Which Ghost is inside, its Will, how long it'll stay and its move."),
          :handler => proc { |scene, pkmn, _index| GhostlyPossession::Info.open(scene, pkmn) })
      end
      return true
    end
  end
end
