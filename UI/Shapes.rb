#==============================================================================
# Ghostly Possession: shapes
#==============================================================================
# The game's fonts have no arrow or plus, so they're drawn in pixels, in
# either look (UI/Alone.rb, UI/Card.rb); and the ghost and its badge (the
# party screens, the battle).
#==============================================================================

module GhostlyPossession
  module Shapes
    # a little ghost, 9 x 9: round head, two eyes, a wavy hem
    GHOST = ["..#####..", ".#######.", "##.###.##", "##.###.##", "#########", "#########", "#########", "#.##.##.#",
             ".#..#..#."].freeze
    BADGE_EDGE = Color.new(56, 24, 96)
    BADGE_FILL = Color.new(150, 80, 230)
    BADGE_INK = Color.new(248, 240, 255)
    # gold, once a wild one's grip slips (The Mark Turns Gold, his pick 2026-10-24)
    GOLD_EDGE = Color.new(96, 64, 8)
    GOLD_FILL = Color.new(240, 200, 80)
    GOLD_INK = Color.new(72, 40, 8)

    module_function

    # The ghost, each of its pixels s x s
    def ghost(b, x, y, col, s = 1)
      GHOST.each_with_index do |row, r|
        row.each_char.with_index { |ch, k| b.fill_rect(x + k * s, y + r * s, s, s, col) if ch == "#" }
      end
    end

    # The ghost badge (the battle's mark): a purple box, the ghost in white
    # (gold: a gold box, the ghost in brown); 15 x 15 (s 1) or 22 x 22 (s 2)
    def badge(b, x, y, s = 1, gold = false)
      side = s == 1 ? 15 : 22
      b.fill_rect(x, y, side, side, gold ? GOLD_EDGE : BADGE_EDGE)
      b.fill_rect(x + 1, y + 1, side - 2, side - 2, gold ? GOLD_FILL : BADGE_FILL)
      ghost(b, x + (side - 9 * s) / 2, y + (side - 9 * s) / 2, gold ? GOLD_INK : BADGE_INK, s)
    end

    # A thin arrow from x0 to x1, its middle on y: a 3 px shaft into a
    # chevron head
    def arrow(b, x0, x1, y, col)
      b.fill_rect(x0, y - 1, x1 - x0 - 4, 3, col)
      chevron(b, x1 - 8, y - 5, 11, col)
    end

    # A chevron pointing right, h rows tall, its strokes t wide
    def chevron(b, x, y, h, col, t = 3)
      half = h / 2
      h.times { |i| b.fill_rect(x + (i <= half ? i : h - 1 - i), y + i, t, 1, col) }
    end

    def plus(b, x, y, col)
      b.fill_rect(x - 6, y - 1, 13, 3, col)
      b.fill_rect(x - 1, y - 6, 3, 13, col)
    end
  end
end
