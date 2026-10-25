#==============================================================================
# Ghostly Possession: the Overworld Menu readout (with Kanto Reloaded)
#==============================================================================
# A readout for Kanto Reloaded's Overworld Menu (Who and How Long, his pick
# 2026-10-24): the possessed teammate's name, and a purple pill with its
# Ghost and roughly how long it'll stay ("GASTLY: A WHILE"; the Stay hints'
# short forms). Shown only while one of your team is possessed. A shows its
# Possession popup over the menu (UI/Info.rb); Cast It Out closes the menu
# and it happens on the map. Like every readout, it starts on no page: the
# player puts it on one (Edit Pages).
#==============================================================================

module GhostlyPossession
  module Readout
    KEY = :ghostly_possession
    STAYS = ["Not Long", "A While", "Settling In"].freeze

    module_function

    # The possessed one in your party, or nil
    def host
      return nil unless $Trainer && Shared.possessed_id
      return $Trainer.party.find { |p| p && Note.possessed?(p) && !Note.wild?(p) }
    end

    # The Stay hint's short form, by the battles it has left (as Info's)
    def stay_word(note)
      left = note[:battles_left].to_i
      return _INTL(STAYS[0]) if left <= Ghosts::STAY_HINTS[0]
      return _INTL(STAYS[1]) if left <= Ghosts::STAY_HINTS[1]
      return _INTL(STAYS[2])
    end

    # The pill, ending at x1; its width (just the Ghost when there's no room)
    def paint(b, x1, y, h, c, room)
      pkmn = host
      return 0 unless pkmn
      note = Note.read(pkmn)
      pf = ::KIF::PixelFont
      words = "#{UI.ghost_name(note)}: #{stay_word(note)}".upcase
      words = UI.ghost_name(note).upcase if room && pf.width(pf::TINY, words) + 12 > room
      ink = ::Reloaded::PartyPaint.ink(c, Card::GHOST_RGB)
      fill = c[:light] ? ::Reloaded::Palette.mix(c[:panel2], ink, 0.22) : ::Reloaded::Palette.mix(c[:panel], ink, 0.25)
      return ::Reloaded::Pixel.pill(b, x1, y + (h - 14) / 2, words, fill, ink, true)
    end

    # A: the Possession popup over the menu; Cast It Out closes the menu
    def open(menu)
      pkmn = host
      return nil unless pkmn
      return Info.popup(menu, pkmn, Note.read(pkmn)) ? :close : nil
    end

    def boot
      return true unless KR.has?(:OverworldMenu)
      ::Reloaded::OverworldMenu.register(KEY, :name => "Possession", :kind => :info, :priority => 5,
        :condition => proc { !GhostlyPossession::Readout.host.nil? },
        :label => proc { (h = GhostlyPossession::Readout.host) ? h.name : "" },
        :paint => proc { |b, x1, y, h, c, room| GhostlyPossession::Readout.paint(b, x1, y, h, c, room) },
        :description => "Which Ghost is in which of your team, and roughly how long it'll stay. A shows the Possession popup.",
        :handler => proc { |menu| GhostlyPossession::Readout.open(menu) })
      return true
    end
  end
end
