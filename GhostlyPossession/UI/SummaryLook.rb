#==============================================================================
# Ghostly Possession: the Summary look
#==============================================================================
# A possessed Pokémon's Summary shows it possessed, as it is in battle (his
# picks 2026-10-25: Show It Possessed, Purple Marks): the fusion's picture,
# species and Ghost-first types (the Info page's Head and Body rows say
# which), its stats as possession makes them, and the Ghost's move in its
# slot. Its name, level, nature, IVs, EVs, ability, item and Exp stay its own.
#
#   Purple Marks   The Ghost small in the picture's corner; the name lavender
#                  with the ghost badge after it; what possession changes in
#                  ghost purple: each stat it raises and that stat's base, the
#                  Ghost's move with the badge.
#
# Only the drawing sees the fusion (Engine.battle_view: a copy, let go of at
# once); the Summary's own actions (reordering moves, marking...) keep the
# Pokémon itself. Learning a move shows its own moves: the one you replace.
#==============================================================================

module GhostlyPossession
  module SummaryLook
    LAVENDER = [Color.new(224, 184, 255), Color.new(72, 32, 112)].freeze
    INK = [Color.new(160, 96, 232), Color.new(216, 192, 248)].freeze        # on the light pages
    INK_DARK = [Color.new(208, 168, 255), Color.new(72, 32, 112)].freeze    # on dark mode's
    GHOST_AT = [176, 150].freeze      # the Ghost's picture: the big picture's top right
    GHOST_SIZE = 48
    NAME_AT = [46, 56].freeze         # (the game's: drawPage writes the name there)
    GENDER_X = 178                    # ...and the gender mark
    STAT_YS = [70, 114, 146, 178, 210, 242].freeze
    @marks = nil

    module_function

    def marks
      return @marks
    end

    # [text, x, y, colours]: those of the page's texts drawn in another colour
    def with_marks(list)
      before = @marks
      @marks = list
      return yield
    ensure
      @marks = before
    end

    def ink
      return defined?(isDarkMode) && isDarkMode ? INK_DARK : INK
    end

    # what possession changes on a page, to mark
    def page_marks(view, raised, slot)
      list = [[view.name, NAME_AT[0], NAME_AT[1], LAVENDER]]
      values = [view.totalhp, view.attack, view.defense, view.spatk, view.spdef, view.speed]
      keys = [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED]
      base = view.respond_to?(:kif_effective_base_stats) ? view.kif_effective_base_stats : view.baseStats
      raised.each do |i|
        y = STAT_YS[i]
        list << [values[i].to_s, 380, y, ink]                      # KIF's Skills page (IVs and EVs)
        list << [base[keys[i]].to_s, 500, y, ink]
        list << (i == 0 ? [format("%d/%d", view.hp, view.totalhp), 462, y, ink] : [values[i].to_s, 456, y, ink])   # the game's own
      end
      move = view.moves[slot]
      list << [move.name, 316, 92 + slot * 64, ink] if move
      return list
    rescue StandardError
      return list || []
    end

    # The page's texts in their marked colours (only while the Summary draws)
    module Colour
      def pbDrawTextPositions(bitmap, textpos)
        marks = GhostlyPossession::SummaryLook.marks
        if marks && textpos.is_a?(Array)
          textpos = textpos.map do |t|
            next t unless t.is_a?(Array)
            m = marks.find { |text, x, y, _c| t[0] == text && t[1] == x && t[2] == y }
            next t unless m
            t2 = t.dup
            t2[4], t2[5] = m[3]
            t2
          end
        end
        return super(bitmap, textpos)
      end
    end

    #--------------------------------------------------------------------------
    # The game's Summary
    #--------------------------------------------------------------------------
    module Scene
      def drawPage(page)
        view = gp_view
        return gp_plain_picture && super unless view
        look, raised, slot = view
        real = @pokemon
        @pokemon = look
        begin
          ret = GhostlyPossession::SummaryLook.with_marks(GhostlyPossession::SummaryLook.page_marks(look, raised, slot)) { super }
        ensure
          @pokemon = real
        end
        gp_extras(look, page, slot)
        return ret
      end

      # a move's details (picking one on the Moves page): the Ghost's in its slot
      def drawSelectedMove(move_to_learn, selected_move)
        view = move_to_learn ? nil : gp_view
        return super unless view
        look, raised, slot = view
        real = @pokemon
        i = real.moves.index { |m| m.equal?(selected_move) }
        selected_move = look.moves[i] if i && look.moves[i]
        @pokemon = look
        begin
          return GhostlyPossession::SummaryLook.with_marks(GhostlyPossession::SummaryLook.page_marks(look, raised, slot)) { super }
        ensure
          @pokemon = real
          # (the details hide the big picture: the Ghost's goes with it)
          ghost = @sprites && @sprites["gp_ghost"]
          ghost.visible = false if ghost && !ghost.disposed? && @sprites["pokemon"] && !@sprites["pokemon"].visible
        end
      end

      def gp_view
        return nil unless @pokemon && GhostlyPossession::PartyLook.possessed?(@pokemon)
        return GhostlyPossession::Engine.battle_view(@pokemon)
      end

      # the picture back to its own when the one shown isn't possessed
      def gp_plain_picture
        if @gp_shown && @sprites && @sprites["pokemon"] && @pokemon
          @sprites["pokemon"].setPokemonBitmap(@pokemon) unless @pokemon.egg?
          @gp_shown = nil
        end
        ghost = @sprites && @sprites["gp_ghost"]
        ghost.visible = false if ghost && !ghost.disposed?
        return true
      end

      # the fusion's picture, the Ghost in its corner, the badges
      def gp_extras(look, page, slot)
        pic = @sprites["pokemon"]
        if pic && !@gp_shown.equal?(@pokemon)
          pic.setPokemonBitmap(look)
          @gp_shown = @pokemon
        end
        ghost = GhostlyPossession::PartyLook.ghost_of(@pokemon)
        if ghost && pic
          s = @sprites["gp_ghost"]
          if s.nil? || s.disposed? || !s.pokemon.equal?(ghost)
            s.dispose if s && !s.disposed?
            s = @sprites["gp_ghost"] = GhostlyPossession::PCLook::GhostPicture.new(pic.viewport, ghost,
                                                                                    GhostlyPossession::SummaryLook::GHOST_AT,
                                                                                    GhostlyPossession::SummaryLook::GHOST_SIZE)
          end
          s.z = pic.z + 1
          s.visible = pic.visible && !s.bitmap.nil?
        end
        overlay = @sprites["overlay"].bitmap
        x = GhostlyPossession::SummaryLook::NAME_AT[0] + overlay.text_size(look.name.to_s).width + 8
        if x + GhostlyPossession::PCLook::BADGE <= GhostlyPossession::SummaryLook::GENDER_X - 2
          GhostlyPossession::Shapes.badge(overlay, x, GhostlyPossession::SummaryLook::NAME_AT[1] + 4)
        end
        move = look.moves[slot]
        if page == 4 && move
          GhostlyPossession::Shapes.badge(overlay, 316 + overlay.text_size(move.name.to_s).width + 8, 92 + slot * 64 + 10)
        end
      rescue StandardError => e
        GhostlyPossession.log("The Summary's possessed look couldn't be drawn: #{e.class}: #{e.message}")
      end
    end

    def boot
      return true unless defined?(::PokemonSummary_Scene)
      ::Object.prepend(Colour) unless ::Object.ancestors.include?(Colour)
      unless ::PokemonSummary_Scene.ancestors.include?(Scene)
        if [:drawPage, :drawSelectedMove].all? { |m| ::PokemonSummary_Scene.method_defined?(m) || ::PokemonSummary_Scene.private_method_defined?(m) }
          ::PokemonSummary_Scene.prepend(Scene)
        else
          GhostlyPossession.log("The game's Summary has changed: it doesn't show the possessed look")
        end
      end
      return true
    end
  end
end
