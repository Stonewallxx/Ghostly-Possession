#==============================================================================
# Ghostly Possession: the Cleanse Tag
#==============================================================================
# The game's Cleanse Tag (CLEANSETAG; held by the lead, it keeps wild
# Pokémon away, and still does) casts a Ghost out (his picks 2026-10-24):
#
#   From the Bag: Use, a yes or no, then the Bag and the menus close and it
#   happens on the map (the game's own way for an item used in the field).
#   From the Possession popup: Cast It Out (UI/Info.rb).
#   In battle, from the battle's Bag (EBDX's: Battle Items), on a possessed
#   wild Pokémon whose Ghost's grip is slipping (in the red; Weaken, Then
#   Cleanse): it's used up, and the Ghost bursts out (Core/WildBattle.rb).
#   Before that, "The Gastly's grip is still too strong."
#   Lavender Town's Poké Mart sells it, at 1,000 (the game's price is 5,000);
#   the Channeler gives the first one (Core/Channeler.rb).
#
# Only how the game sees the item changes (it can be used from the Bag and
# in battle on a foe, as a Poké Ball is; its description says so), as the
# game reads it: nothing in its data is changed.
#==============================================================================

module GhostlyPossession
  module CleanseTag
    ITEM = :CLEANSETAG
    PRICE = 1000

    module_function

    def exists?
      return defined?(::GameData::Item) && ::GameData::Item.exists?(ITEM) ? true : false
    end

    def icon_path
      return (::GameData::Item.icon_filename(ITEM) rescue nil) || "Graphics/Items/#{ITEM}"
    end

    def count
      return $PokemonBag ? ($PokemonBag.pbQuantity(ITEM) rescue 0).to_i : 0
    end

    # The possessed teammate, if one is with you
    def possessed_in_party
      return nil unless $Trainer
      return $Trainer.party.find { |p| p && Note.possessed?(p) }
    end

    # Use, from the Bag: 2 closes the Bag (and the menus) so it acts on the map
    def from_bag
      pkmn = possessed_in_party
      unless pkmn
        pbMessage(_INTL("None of your Pokémon has a Ghost inside. It won't have any effect."))
        return 0
      end
      note = Note.read(pkmn)
      return 0 unless pbConfirmMessage(_INTL("Use the Cleanse Tag on {1}? It will cast out the {2} inside.",
                                             pkmn.name, UI.ghost_name(note)))
      return 2
    end

    # On the map: 3 uses the tag up
    def in_field
      pkmn = possessed_in_party
      return 0 unless pkmn
      return Leave.cast_out(pkmn, :bag) ? 3 : 0
    end

    #--------------------------------------------------------------------------
    # In battle: on the foe it's aimed at (the battle's Bag checks as it's
    # chosen; it's used up when picked, and given back if it can't act)
    #--------------------------------------------------------------------------
    def can_use_in_battle?(battler, battle, scene, show)
      pkmn = battler && battler.pokemon
      return true if battle.wildBattle? && WildBattle.slipping?(pkmn)
      if battle.wildBattle? && pkmn && Engine.applied?(pkmn) && Note.wild?(pkmn)
        scene.pbDisplay(_INTL("The {1}'s grip is still too strong.", WildBattle.ghost_name(Note.read(pkmn)))) if show
      else
        scene.pbDisplay(_INTL("It won't have any effect.")) if show
      end
      return false
    end

    # (guarded as the hits' cast-outs are: if it goes wrong, the battle goes
    # on and the tag comes back)
    def use_in_battle(battler, battle)
      battle.pbUseItemMessage(ITEM, battle.pbPlayer.name)
      out = false
      Battle.safely("The Cleanse Tag in battle") do
        out = battler && WildBattle.slipping?(battler.pokemon) && WildBattle.cast_out(battle, battler, :tag)
      end
      return if out
      battle.pbDisplay(_INTL("But it had no effect!"))
      $PokemonBag.pbStoreItem(ITEM) if $PokemonBag
    end

    #--------------------------------------------------------------------------
    # How the game sees the item
    #--------------------------------------------------------------------------
    module ItemData
      def field_use
        return 2 if id == GhostlyPossession::CleanseTag::ITEM
        return super
      end

      # 4: on a foe, used up (as a Poké Ball)
      def battle_use
        return 4 if id == GhostlyPossession::CleanseTag::ITEM
        return super
      end

      def description
        text = super
        return text unless id == GhostlyPossession::CleanseTag::ITEM
        return text.to_s + " " + _INTL("Used from the Bag, it casts out a Ghost that has possessed one of your Pokémon. In battle, it casts one out of a wild Pokémon once its grip slips.")
      end
    end

    # EBDX's battle Bag: in its Battle Items pocket (its pockets only know
    # the game's own kinds; used from there, it's aimed at the foe as above)
    module EBDXPocket
      def pbIsBattleItem?(item)
        return true if (::GameData::Item.get(item).id rescue nil) == GhostlyPossession::CleanseTag::ITEM
        return super
      end
    end

    # Lavender Town's Poké Mart: the Cleanse Tag too, at its price
    module MartStock
      def get_mart_exclusive_items(city, *rest)
        list = super
        return list unless city == :LAVENDER && GhostlyPossession::CleanseTag.exists? && list.is_a?(Array)
        if $game_temp && $game_temp.respond_to?(:mart_prices) && $game_temp.mart_prices
          price = GhostlyPossession::CleanseTag::PRICE
          $game_temp.mart_prices[GhostlyPossession::CleanseTag::ITEM] = [price, price]   # sells for half, as any item
        end
        return list.include?(GhostlyPossession::CleanseTag::ITEM) ? list : list + [GhostlyPossession::CleanseTag::ITEM]
      end
    end

    # (at load the game's data isn't there yet: what needs it checks as it runs)
    def boot
      ::GameData::Item.prepend(ItemData) if defined?(::GameData::Item) && !::GameData::Item.ancestors.include?(ItemData)
      ::Object.prepend(MartStock) unless ::Object.ancestors.include?(MartStock)
      if ::Object.private_method_defined?(:pbIsBattleItem?) || ::Object.method_defined?(:pbIsBattleItem?)
        ::Object.prepend(EBDXPocket) unless ::Object.ancestors.include?(EBDXPocket)
      end
      if defined?(::ItemHandlers::UseFromBag) && defined?(::ItemHandlers::UseInField)
        ::ItemHandlers::UseFromBag.add(ITEM, proc { |_item| GhostlyPossession::CleanseTag.from_bag })
        ::ItemHandlers::UseInField.add(ITEM, proc { |_item| GhostlyPossession::CleanseTag.in_field })
        if defined?(::ItemHandlers::CanUseInBattle) && defined?(::ItemHandlers::UseInBattle)
          ::ItemHandlers::CanUseInBattle.add(ITEM, proc { |_item, _pkmn, battler, _move, _first, battle, scene, show|
            GhostlyPossession::CleanseTag.can_use_in_battle?(battler, battle, scene, show)
          })
          ::ItemHandlers::UseInBattle.add(ITEM, proc { |_item, battler, battle| GhostlyPossession::CleanseTag.use_in_battle(battler, battle) })
        end
      end
      return true
    end
  end
end
