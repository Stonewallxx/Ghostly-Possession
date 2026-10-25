#==============================================================================
# Ghostly Possession
#==============================================================================
# KIF Beta loads this file (mod.json "scripts") once at startup, after every
# game script and, when Kanto Reloaded is installed, after Kanto Reloaded
# has booted (mod.json "load_after"); before the game data and
# $PokemonSystem are loaded.
#
#   - Loads every file in FILES, in order, then boots each system in
#     SYSTEMS.
#   - A file or system that fails is logged and skipped; the rest still
#     loads and the game keeps running.
#
# Everything lives in `module GhostlyPossession`. It works on its own; with
# Kanto Reloaded it uses Kanto Reloaded's screens and settings
# (Core/KR.rb).
#==============================================================================

module GhostlyPossession
  ROOT = File.expand_path(File.dirname(__FILE__)) unless const_defined?(:ROOT, false)
  NAME = "Ghostly Possession" unless const_defined?(:NAME, false)
  FILES = ["Core/KR.rb", "Core/Note.rb", "Core/Settings.rb", "Core/Engine.rb", "Core/Battle.rb", "Core/Control.rb",
           "Core/Ghosts.rb", "Core/Team.rb", "Core/Wilds.rb", "Core/Leave.rb", "Core/WildBattle.rb", "Core/CleanseTag.rb",
           "Core/Channeler.rb", "Core/Compat.rb", "Core/Season.rb", "Core/SeasonExtras.rb", "Core/Debug.rb", "Core/Wisps.rb",
           "Core/Spirits.rb", "Core/Fusing.rb", "UI/Shapes.rb", "UI/Moment.rb", "UI/Alone.rb", "UI/Card.rb", "UI/Keep.rb", "UI/Possessed.rb", "UI/PartyLook.rb", "UI/PCLook.rb", "UI/SummaryLook.rb", "UI/Info.rb",
           "UI/BattleLook.rb", "UI/MapAura.rb", "UI/ClerkHat.rb", "UI/WispLook.rb", "UI/SpiritLook.rb", "UI/SeasonDark.rb", "UI/TownLights.rb", "UI/Readout.rb", "UI/TitleLook.rb"].freeze unless const_defined?(:FILES, false)
  SYSTEMS = [:Settings, :Engine, :Battle, :Control, :Team, :Leave, :GhostBattle, :WildBattle, :CleanseTag, :Channeler,
             :Compat, :Season, :SeasonExtras, :Debug, :Wisps, :Spirits, :Fusing, :PartyLook, :PCLook, :SummaryLook, :Info, :BattleLook, :MapAura, :ClerkHat, :WispLook, :SpiritLook, :SeasonDark, :TownLights, :Readout,
             :TitleLook].freeze unless const_defined?(:SYSTEMS, false)

  # The version in mod.json.
  def self.version
    @version ||= begin
      text = File.read(File.join(ROOT, "mod.json"), :encoding => "UTF-8") rescue ""
      text[/"version"\s*:\s*"([^"]+)"/, 1] || "0.0.0"
    end
  end

  # A line in KIF's log, marked as this mod's (and, with Kanto Reloaded, a
  # note in its Bug Report's Recent Steps).
  def self.log(message)
    KIF.log("[#{NAME}] #{message}") if defined?(KIF) && KIF.respond_to?(:log)
    GhostlyPossession::KR.trail("#{NAME}: #{message}") if defined?(GhostlyPossession::KR)
  end

  # What didn't load or boot this session.
  def self.failures
    return Array(@failures).dup
  end

  def self.start
    @failures = []
    FILES.each do |relative|
      begin
        load(File.join(ROOT, relative))
      rescue ScriptError, StandardError => e
        @failures << relative
        log("#{relative} didn't load: #{e.class}: #{e.message.lines.first.to_s.strip}")
      end
    end
    SYSTEMS.each do |name|
      begin
        next unless const_defined?(name, false)
        next if const_get(name, false).boot
        @failures << name.to_s
        log("#{name} didn't boot")
      rescue StandardError => e
        @failures << name.to_s
        log("#{name} failed to boot: #{e.class}: #{e.message.lines.first.to_s.strip}")
      end
    end
    with = GhostlyPossession::KR.on? ? "with Kanto Reloaded" : "on its own"
    log("#{NAME} #{version} loaded #{with}#{@failures.empty? ? "" : " (not loaded: #{@failures.join(", ")})"}")
  end
end

GhostlyPossession.start
