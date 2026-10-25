#==============================================================================
# Ghostly Possession: settings
#==============================================================================
# Two switches and how often each happens (his picks, 2026-10-24), and the
# battle aura. They're KIF settings (KIF::Options): the four kept per save
# (in the save's KIF settings), the aura for all saves; so they survive the
# mod being removed and added again:
#
#   Team Possession   Off / On                a Ghost possesses one of your
#     How Often       Normal / Often          team now and then
#   Haunted Wilds     Off / On                wild Pokémon with a Ghost inside
#     How Often       Normal / Often
#   Restless Spirits  Off / On                in a Nuzlocke, a wisp may lead
#                                             you to a fallen one's grave
#   Aura              Both / Outline / Echo   how a possessed Pokémon looks in
#                                             battle (his ask, 2026-10-25; all
#                                             saves)
#   Nights            (his ask 2026-10-25: their own heading, not tied to
#                     Spooky Season)
#   Darkness          Off / Deepest Violet / Midnight Violet / Pitch Black
#     Town Lights     Off / On                (both hide while Darkness is Off)
#     Light Patches   Off / Self / On / On + Self   (his picks 2026-10-25: its
#                                             own row, On; Self is the light
#                                             round you, Pitch Black's always)
#   Spooky Season     Off / On                Halloween in the game (his picks
#                                             2026-10-24; its rows hide while
#                                             it's Off)
#     Haunted Music   Off / On
#
# (His calls 2026-10-24: Rarely went and Sometimes became Normal. The rates
# moved to new keys, so a save that had Sometimes now has Normal, the same
# rate.)
#
# On their own, they're a "Ghostly Possession" heading in KIF Settings'
# Pokémon section, after Fusion, then "Nights" and "Spooky Season" headings.
# With Kanto Reloaded, they're its "Ghostly Possession" section with "Nights"
# and "Spooky Season" pages under it instead (Kanto Reloaded reads and writes
# the same values straight through, so there's one value for each).
#
#   GhostlyPossession::Settings.team?        Team Possession is On
#   GhostlyPossession::Settings.team_rate    0 Normal, 1 Often
#   GhostlyPossession::Settings.wilds? / wilds_rate
#   GhostlyPossession::Settings.spirits?     Restless Spirits is On
#   GhostlyPossession::Settings.aura         0 Both, 1 Outline, 2 Echo
#   GhostlyPossession::Settings.darkness     0 Off, 1 Deepest Violet, 2 Midnight Violet, 3 Pitch Black
#   GhostlyPossession::Settings.town_lights? / light_patches? / self_patch?   (false while Darkness is Off)
#   GhostlyPossession::Settings.season?      Spooky Season is On
#   GhostlyPossession::Settings.haunted_music?   (false while Spooky Season is Off)
#==============================================================================

module GhostlyPossession
  module Settings
    SECTION = :ghostly_possession     # KIF's menu id for the rows, and Kanto Reloaded's page
    KIF_SECTION = :pokemon            # the KIF Settings section they show in on their own
    RATES = ["Normal", "Often"].freeze
    # id => [KIF setting, default, name, description]; a rate's parent first
    ROWS = [
      [:team, :ghostly_team, 1, "Team Possession",
       "Now and then a Ghost possesses one of your team. It battles as their fusion for a while, and the Ghost acts on its own at times."],
      [:team_rate, :ghostly_team_how_often, 0, "How Often",
       "How often a Ghost possesses one of your team. More often at night and in haunted places."],
      [:wilds, :ghostly_wilds, 1, "Haunted Wilds",
       "Some wild Pokémon have a Ghost inside. Catch one and keep the Ghost or the Pokémon, or cast the Ghost out to try for both."],
      [:wilds_rate, :ghostly_wilds_how_often, 0, "How Often",
       "How often a wild Pokémon has a Ghost inside. More often at night and in haunted places."],
      [:spirits, :ghostly_restless_spirits, 1, "Restless Spirits",
       "In a Nuzlocke, a will-o'-wisp may now and then lead you to a fallen Pokémon's grave. Its spirit gets one restless chance to come back."],
      [:aura, :ghostly_aura, 0, "Aura",
       "How a possessed Pokémon looks in battle: a purple outline and a ghostly double behind it, or just one of them."],
      [:darkness, :ghostly_darkness, 1, "Darkness",
       "How dark the nights are outdoors. Off keeps KIF's own nights. Pitch Black: you only see round you and by lights; Flash or a Lantern helps."],
      [:lights, :ghostly_town_lights, 1, "Town Lights",
       "At night, windows, doors and lamps light up and cast warm light round them."],
      [:patches, :ghostly_light_patches_mode, 2, "Light Patches",
       "At night every light lifts the dark round it: lamps, windows, doors, wisps and graves. Self: a light round you too, or only that. Off: the night is one even shade (Pitch Black always has the light round you)."],
      [:season, :ghostly_spooky_season, 1, "Spooky Season",
       "Halloween in the game: fog over haunted places, more Ghost-types at night, haunted music, Poké Mart clerks in Witchy Hats and a Witchy Hat of your own on 31 October."],
      [:music, :ghostly_haunted_music, 1, "Haunted Music",
       "Spooky music on routes at night: Lavender Town, the Pokémon Tower, the Strange House or the Mansion."]
    ].freeze
    PARENTS = { :team_rate => :team, :wilds_rate => :wilds, :lights => :darkness, :patches => :darkness, :music => :season }.freeze
    RATE_ROWS = [:team_rate, :wilds_rate].freeze
    AURAS = ["Both", "Outline", "Echo"].freeze
    DARKNESS = ["Off", "Deepest Violet", "Midnight Violet", "Pitch Black"].freeze
    PATCHES = ["Off", "Self", "On", "On + Self"].freeze    # (a new key: Off / On was 0 / 1)
    # a row's values when it isn't a switch or a rate, and its scope when it isn't per save
    VALUES = { :aura => AURAS, :darkness => DARKNESS, :patches => PATCHES }.freeze
    SCOPES = { :aura => :global }.freeze
    NIGHTS_HEADING = "Nights"
    SEASON_HEADING = "Spooky Season"
    NIGHTS = [:darkness, :lights, :patches].freeze     # (the Nights heading's rows)
    SEASON = [:season, :music].freeze                  # (the Spooky Season heading's)
    NIGHTS_PAGE = :ghostly_nights                      # Kanto Reloaded's pages for them
    SEASON_PAGE = :ghostly_spooky_season

    module_function

    def team?;      return value(:team) == 1;  end
    def wilds?;     return value(:wilds) == 1; end
    def spirits?;   return value(:spirits) == 1; end
    def season?;    return value(:season) == 1; end
    def darkness;   return value(:darkness).clamp(0, DARKNESS.length - 1); end
    def town_lights?;   return darkness >= 1 && value(:lights) == 1; end
    def light_patches?; return darkness >= 1 && [2, 3].include?(value(:patches)); end    # every light's
    def self_patch?;    return darkness >= 1 && [1, 3].include?(value(:patches)); end    # the light round you
    def haunted_music?; return season? && value(:music) == 1; end
    def team_rate;  return value(:team_rate).clamp(0, RATES.length - 1);  end
    def wilds_rate; return value(:wilds_rate).clamp(0, RATES.length - 1); end
    def aura;       return value(:aura).clamp(0, AURAS.length - 1);       end

    def scope(id)
      return SCOPES[id] || :save
    end

    # Where the settings show: :kanto_reloaded or :kif (decided at boot)
    def place
      return @place
    end

    def row(id)
      return ROWS.find { |r| r[0] == id }
    end

    def value(id)
      _id, key, default = row(id)
      return default unless $PokemonSystem && $PokemonSystem.respond_to?(key)
      return $PokemonSystem.send(key).to_i
    rescue StandardError
      return default
    end

    def boot
      ROWS.each { |id, key, default| ::KIF::Options.define(key, default, scope(id)) }
      @place = GhostlyPossession::KR.has?(:Settings) && register_kr ? :kanto_reloaded : :kif
      register_kif if @place == :kif
      return true
    end

    #--------------------------------------------------------------------------
    # On its own: a heading in KIF Settings' Pokémon section
    #--------------------------------------------------------------------------
    def register_kif
      unless ::KIF::Options.menu_info(SECTION)
        ::KIF::Options.register_menu(SECTION, NAME, "Ghosts that possess Pokémon.",
                                     Color.new(248, 248, 248), Color.new(64, 64, 64), NAME)
      end
      ROWS.each { |id, *_rest| ::KIF::Options.add(SECTION, scope(id)) { GhostlyPossession::Settings.kif_option(id) } }
      return unless defined?(::KIF::SettingsScreen::SECTIONS)
      # a heading in the Pokémon section, after Fusion (his ask, 2026-10-25)
      pokemon = ::KIF::SettingsScreen::SECTIONS.find { |s| s[0] == KIF_SECTION }
      unless pokemon
        GhostlyPossession.log("KIF Settings has no Pokémon section; the settings show under Game > Other")
        return
      end
      groups = pokemon[3]
      groups.delete_if { |heading, _names| [NAME, NIGHTS_HEADING, SEASON_HEADING].include?(heading) }
      after = groups.index { |heading, _names| heading == "Fusion" }
      at = after ? after + 1 : groups.length
      groups.insert(at, [NAME, [row(:team)[3], row(:wilds)[3], row(:spirits)[3], row(:aura)[3]]])
      groups.insert(at + 1, [NIGHTS_HEADING, [row(:darkness)[3]]])
      groups.insert(at + 2, [SEASON_HEADING, [row(:season)[3]]])
    end

    # A child row (its name starts with a space): KIF shows it under its
    # switch, and hides it while the switch is Off.
    def kif_option(id)
      _id, key, _default, name, desc = row(id)
      child = PARENTS.has_key?(id)
      values = VALUES[id] || (RATE_ROWS.include?(id) ? RATES : ["Off", "On"])
      return EnumOption.new(_INTL(child ? " #{name}" : name), values.map { |v| _INTL(v) },
                            proc { $PokemonSystem.send(key) },
                            proc { |v| $PokemonSystem.send(:"#{key}=", v); GhostlyPossession::Settings.changed(id) },
                            _INTL(desc))
    end

    # The season's night follows its rows at once
    def changed(id)
      return unless [:season, :darkness, :patches].include?(id) && defined?(GhostlyPossession::Season)
      GhostlyPossession::Season.refresh
    end

    #--------------------------------------------------------------------------
    # With Kanto Reloaded: a heading in its section, the same values
    #--------------------------------------------------------------------------
    def kr_key(id)
      return :"ghostly_possession.#{id}"
    end

    # Kanto Reloaded's improved screen gives each page nobody listed a section
    # of its own: its three pages are one Ghostly Possession section, Nights
    # and Spooky Season headers in it (his ask 2026-10-25; Kanto Reloaded
    # drops the "Ghostly Possession - " from a header in its section)
    module KRSections
      PAGES = [SECTION, NIGHTS_PAGE, SEASON_PAGE].freeze

      def all
        list = super
        mine = list.select { |e| (e[2] & PAGES).any? }
        return list if mine.length <= 1
        at = list.index(mine[0])
        list -= mine
        list.insert(at, [SECTION, NAME, mine.flat_map { |e| e[2] }, "Ghosts that possess Pokémon, will-o'-wisps, the nights and the Spooky Season."])
        return list
      end

      def of_page(page_id)
        return SECTION if PAGES.include?(page_id)
        return super
      end
    end

    def kr_one_section
      return unless defined?(::Reloaded::SettingsSections)
      sc = ::Reloaded::SettingsSections.singleton_class
      sc.prepend(KRSections) unless sc.ancestors.include?(KRSections)
    end

    def register_kr
      s = ::Reloaded::Settings
      s.register_page(SECTION, :group => :general, :name => NAME, :icon => :features, :priority => 800,
                      :description => "Ghosts that possess Pokémon, and will-o'-wisps.")
      s.register_page(NIGHTS_PAGE, :group => :general, :name => "#{NAME} - #{NIGHTS_HEADING}", :icon => :features, :priority => 800.1,
                      :description => "How dark the nights are, and the lights in them.")
      s.register_page(SEASON_PAGE, :group => :general, :name => "#{NAME} - #{SEASON_HEADING}", :icon => :features, :priority => 800.2,
                      :description => "Halloween in the game.")
      ROWS.each_with_index do |(id, key, default, name, desc), i|
        parent = PARENTS[id]
        page = NIGHTS.include?(id) ? NIGHTS_PAGE : SEASON.include?(id) ? SEASON_PAGE : SECTION
        options = { :page => page, :name => name, :description => desc, :scope => scope(id),
                    :priority => (i + 1) * 10, :preset => false, :owner => :ghostly_possession }
        if VALUES[id] || RATE_ROWS.include?(id)
          options.update(:type => :enum, :values => VALUES[id] || RATES, :default => default,
                         :bind => s::Bind.direct(proc { $PokemonSystem ? $PokemonSystem.send(key) : nil },
                                                 proc { |v|
                                                   $PokemonSystem.send(:"#{key}=", v.to_i) if $PokemonSystem
                                                   GhostlyPossession::Settings.changed(id)
                                                 }))
        else
          options.update(:type => :toggle, :default => default == 1,
                         :bind => s::Bind.direct(proc { $PokemonSystem ? $PokemonSystem.send(key) == 1 : nil },
                                                 proc { |v|
                                                   $PokemonSystem.send(:"#{key}=", v ? 1 : 0) if $PokemonSystem
                                                   GhostlyPossession::Settings.changed(id)
                                                 }))
        end
        options[:needs] = kr_key(parent) if parent
        s.register(kr_key(id), options)
      end
      kr_one_section
      return true
    rescue StandardError => e
      GhostlyPossession.log("Kanto Reloaded's settings didn't take Ghostly Possession's page " \
                            "(#{e.class}: #{e.message}); its own section of KIF Settings instead")
      return false
    end
  end
end
