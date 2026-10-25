#==============================================================================
# Ghostly Possession: Kanto Reloaded
#==============================================================================
# Ghostly Possession works on its own. When Kanto Reloaded is installed and
# booted, it uses Kanto Reloaded's systems instead: its settings section,
# its screens, its hooks. mod.json's "load_after" makes Kanto Reloaded load
# and boot first, so it can be asked about here at load time.
#
#   GhostlyPossession::KR.on?              Kanto Reloaded booted (ready, or
#                                          degraded: some parts failed)
#   GhostlyPossession::KR.has?(:Settings)  that system booted and answers
#                                          what Ghostly Possession calls
#   GhostlyPossession::KR.trail(text)      a note in its Bug Report's Recent
#                                          Steps (every line of this mod's
#                                          log; a line the same as the last
#                                          isn't noted again)
# A screen asks has? when it opens, as a Kanto Reloaded feature can be
# switched Off during play.
#==============================================================================

module GhostlyPossession
  module KR
    # What each Kanto Reloaded system must answer to count as there
    NEEDS = {
      :Settings      => [:register_page, :register, :definition, :get, :set],
      :PartyScreen   => [:add_command, :active?],
      :OverworldMenu => [:register],
      :Toast         => [:show],
      :Notice        => [:show],
      :Hooks         => [:prepend, :guard]
    }.freeze

    module_function

    def on?
      return defined?(::Reloaded::Bootstrap) && ::Reloaded::Bootstrap.respond_to?(:ready?) &&
             ::Reloaded::Bootstrap.ready? ? true : false
    rescue StandardError
      return false
    end

    def has?(system)
      return false unless on?
      return false if ::Reloaded::Bootstrap.failures.any? { |f| f.to_s == system.to_s }
      return false unless ::Reloaded.const_defined?(system, false)
      mod = ::Reloaded.const_get(system, false)
      return Array(NEEDS[system]).all? { |m| mod.respond_to?(m) }
    rescue StandardError
      return false
    end

    def trail(text)
      return unless on? && defined?(::Reloaded::BugReport::Trail) && ::Reloaded::BugReport::Trail.respond_to?(:add)
      return if text == @last_trail
      @last_trail = text
      ::Reloaded::BugReport::Trail.add(:note, text)
    rescue StandardError
      nil
    end
  end
end
