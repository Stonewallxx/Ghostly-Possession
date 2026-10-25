#==============================================================================
# Ghostly Possession: Keep Which?
#==============================================================================
# A possessed wild Pokémon caught: the Ghost and its host were caught
# together, and one stays (his ask 2026-10-24; his pick: the Keep Which?
# Card). Asked in battle, where the game asks for a nickname.
#
#   With Kanto Reloaded: the mod's card, the host and the Ghost with the ball
#   they were caught in between, the chosen one on the disc and in the
#   card's colour, both one's types; Keep Growlithe / Keep Gastly. B
#   doesn't close it.
#   On its own: a window up top (the Growlithe "or" the Gastly) over the
#   battle's own question and choice list.
#
#   i = GhostlyPossession::Keep.ask(battle, host, ghost, note, disabled)
#   # => 0 the host, 1 the Ghost
#
# disabled: the ones that can't be kept (KIF's Nuzlocke Dupes Clause: a
# line you have already).
#==============================================================================

module GhostlyPossession
  module Keep
    module_function

    def ask(battle, host, ghost, note, disabled = [])
      disabled = Array(disabled)
      return UI.kr? ? card(battle, host, ghost, disabled) : alone(battle, host, ghost, disabled)
    end

    def card(battle, host, ghost, disabled)
      ball = (::GameData::Item.icon_filename(host.poke_ball) rescue nil) || "Graphics/Items/POKEBALL"
      return Card.keep(:title => _INTL("Keep Which?"), :rgb => Card::GHOST_RGB, :before => host, :after => ghost, :middle => ball,
                       :buttons => [_INTL("Keep {1}", host.name), _INTL("Keep {1}", ghost.name)],
                       :body => _INTL("The {1} and the {2} were caught together, but only one can stay. The other goes free.",
                                      ghost.name, host.name),
                       :note => nuzlocke_line(battle, host, ghost, disabled), :disabled => disabled,
                       :choice => disabled.include?(0) ? 1 : 0)
    end

    def alone(battle, host, ghost, disabled)
      window = Alone::Pair.new(host, ghost)
      begin
        loop do
          i = battle.scene.pbShowCommands(_INTL("The {1} and {2} were caught together. Which will you keep?", ghost.name, host.name),
                                          [host.name, ghost.name], -1)
          return i if [0, 1].include?(i) && !disabled.include?(i)
          name = i == 1 ? ghost.name : host.name
          battle.pbDisplayPaused(_INTL("Nuzlocke: You already have the {1}'s line.", name)) if [0, 1].include?(i)
        end
      ensure
        window.dispose
      end
    end

    # KIF's Nuzlocke: whichever is kept is the route's catch
    def nuzlocke_line(battle, host, ghost, disabled)
      return nil unless battle.respond_to?(:kif_nz) && battle.kif_nz == :first
      if disabled.length == 1
        return _INTL("Nuzlocke: You already have the {1}'s line (Dupes Clause).", disabled[0] == 1 ? ghost.name : host.name)
      end
      place = battle.respond_to?(:kif_nz_place) ? battle.kif_nz_place : nil
      return place ? _INTL("Nuzlocke: Either one counts as your catch on {1}.", place) : _INTL("Nuzlocke: Either one counts as your catch here.")
    end
  end

  module Card
    module_function

    # Keep Which?'s card: Card.show's arguments with both Pokémon shown alike
    def keep(args)
      scene = KeepScene.new({ :cancel => false, :pills => true }.merge(args))
      begin
        return scene.run(args[:choice] || 0)
      ensure
        scene.dispose
      end
    end

    # The card with both Pokémon shown alike, the chosen one on the disc
    class KeepScene < Scene
      def draw(choice, pictures = true)
        a = @args
        c = ::Reloaded::Palette.map_menu
        paint = ::Reloaded::PartyPaint
        dg = ::Reloaded::Dialogs
        tint = paint.ink(c, a[:rgb])
        o = @sprite.bitmap
        o.clear
        o.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 110))
        body = P.wrap(a[:body].to_s, CW - 28)
        note = a[:note] ? P.small_wrap(o, a[:note].to_s, CW - 28) : []
        split = 178
        h = split + 8 + body.length * 18 + (note.empty? ? 0 : 6 + note.length * 16) + 50
        y0 = [(H - P::HINT_H - h) / 2, 6].max
        y1 = y0 + h
        dg.send(:panel, o, c, X0, y0, CW, h, tint)
        dg.send(:title_bar, o, c, X0, y0, CW, a[:title].to_s, tint, tint, tint)
        sides = [[a[:before], X0 + 80], [a[:after], X0 + CW - 80]]
        paint.disc(o, sides[choice][1], y0 + 92, 40, ::Reloaded::Palette.mix(c[:panel2], tint, 0.22))
        middle(o, a[:middle], X0 + CW / 2, y0 + 92) if a[:middle]
        sides.each_with_index do |(pkmn, x), i|
          picture(pkmn, x, y0 + 92) if pictures
          ink = Array(a[:disabled]).include?(i) ? c[:dim] : (i == choice ? tint : c[:txt])
          name(o, pkmn.name, x, y0 + 134, ink)
          type_pills(o, c, pkmn, x, y0 + 156)
        end
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
        P.hints(o, o, c, [[:lr, _INTL("Choose")], [button(:C), _INTL("Keep")]], ::Reloaded::Prompts.style)
      end
    end
  end
end
