------------------------------------------------------------------------
-- Pro Shop - Database
-- Profession keywords, TBC item database, matching logic
------------------------------------------------------------------------
local _, PS = ...
local C = PS.C

------------------------------------------------------------------------
-- Profession Name Mappings (abbreviation -> full name)
------------------------------------------------------------------------
PS.PROFESSION_ALIASES = {
    -- Enchanting
    ["enchanting"]    = "Enchanting",
    ["enchant"]       = "Enchanting",
    ["enchanter"]     = "Enchanting",
    ["ench"]          = "Enchanting",
    ["chant"]         = "Enchanting",
    ["chanter"]       = "Enchanting",
    -- Alchemy
    ["alchemy"]       = "Alchemy",
    ["alch"]          = "Alchemy",
    ["alchemist"]     = "Alchemy",
    ["transmute"]     = "Alchemy",
    ["xmute"]         = "Alchemy",
    ["flask"]         = "Alchemy",
    -- Jewelcrafting
    ["jewelcrafting"]  = "Jewelcrafting",
    ["jc"]             = "Jewelcrafting",
    ["jeweler"]        = "Jewelcrafting",
    ["jewelcrafter"]   = "Jewelcrafting",
    ["gem"]            = "Jewelcrafting",
    ["gems"]           = "Jewelcrafting",
    ["gem cut"]        = "Jewelcrafting",
    ["gem cuts"]       = "Jewelcrafting",
    -- Tailoring
    ["tailoring"]     = "Tailoring",
    ["tailor"]        = "Tailoring",
    ["sewing"]        = "Tailoring",
    -- Leatherworking
    ["leatherworking"] = "Leatherworking",
    ["leatherworker"]  = "Leatherworking",
    ["lw"]             = "Leatherworking",
    ["leather"]        = "Leatherworking",
    -- Blacksmithing
    ["blacksmithing"]  = "Blacksmithing",
    ["blacksmith"]     = "Blacksmithing",
    ["bs"]             = "Blacksmithing",
    ["smith"]          = "Blacksmithing",
    ["smithing"]       = "Blacksmithing",
    -- Engineering
    ["engineering"]    = "Engineering",
    ["engineer"]       = "Engineering",
    ["eng"]            = "Engineering",
    ["engi"]           = "Engineering",
    -- Cooking
    ["cooking"]        = "Cooking",
    ["cook"]           = "Cooking",
    ["chef"]           = "Cooking",
    -- First Aid
    ["first aid"]      = "First Aid",
    ["firstaid"]       = "First Aid",
    ["bandage"]        = "First Aid",
    ["bandages"]       = "First Aid",
    -- Lockpicking
    ["lockpicking"]    = "Lockpicking",
    ["lockpick"]       = "Lockpicking",
    ["lockpicker"]     = "Lockpicking",
    ["lock pick"]      = "Lockpicking",
    ["picker"]         = "Lockpicking",
    ["pick lock"]      = "Lockpicking",
    ["picks"]          = "Lockpicking",
    ["unlock"]         = "Lockpicking",
    ["open lock"]      = "Lockpicking",
    ["open box"]       = "Lockpicking",
    ["open boxes"]     = "Lockpicking",
    ["locked"]         = "Lockpicking",
    ["lockbox"]        = "Lockpicking",
    ["lockboxes"]      = "Lockpicking",
    ["lock box"]       = "Lockpicking",
    ["lock boxes"]     = "Lockpicking",
    ["rogue"]           = "Lockpicking",  -- "LF rogue" in trade = lockpicking
    ["rogue open"]     = "Lockpicking",
    ["rogue to open"]   = "Lockpicking",
    ["rogue to unlock"] = "Lockpicking",
    ["rogue for lockbox"]  = "Lockpicking",
    ["rogue for lockboxes"] = "Lockpicking",
    ["rogue lockpick"]  = "Lockpicking",
    ["rogue pick"]      = "Lockpicking",
    -- Mage Portals
    ["portal"]          = "Portals",
    ["portals"]         = "Portals",
    ["port"]            = "Portals",
    ["ports"]           = "Portals",
    ["mage port"]       = "Portals",
    ["mage portal"]     = "Portals",
    ["teleport"]        = "Portals",
    ["tele"]            = "Portals",
    -- Warlock Summons
    ["summon"]          = "Summons",
    ["summons"]         = "Summons",
    ["summ"]            = "Summons",
    ["summoner"]        = "Summons",
    ["warlock summon"]  = "Summons",
    ["lock summon"]     = "Summons",
    ["warlock summ"]    = "Summons",
    ["can i get a summon"]  = "Summons",
    ["need a summon"]       = "Summons",
    ["need summon"]         = "Summons",
    ["need summons"]        = "Summons",
    ["need a port"]         = "Portals",
    ["need port"]           = "Portals",
}

------------------------------------------------------------------------
-- Request Prefix Patterns (signals someone is looking for a service)
------------------------------------------------------------------------
PS.REQUEST_PATTERNS = {
    "^lf%s",           -- "LF enchanter"
    "^lfm%s",          -- "LFM enchanter"
    "looking for%s",   -- "looking for an enchanter"
    "need%s",          -- "need enchanter"
    "need a%s",        -- "need a enchanter"
    "need an%s",       -- "need an enchanter"
    "anyone%s",        -- "anyone got JC?"
    "any%s",           -- "any enchanters?"
    "who can%s",       -- "who can do mongoose?"
    "who has%s",       -- "who has enchanting?"
    "can someone%s",   -- "can someone enchant"
    "can anyone%s",    -- "can anyone craft"
    "wtb%s",           -- "WTB mongoose enchant"
    "want to buy%s",   -- "want to buy enchant"
    "buying%s",        -- "buying enchants"
    "where can i get", -- "where can i get mongoose"
    "is there a%s",    -- "is there a JC online?"
    "looking for a%s", -- "looking for a JC"
    "looking for an%s",
    "got a%s",         -- "got a JC?"
    "know a%s",        -- "know a good enchanter?"
    "have a%s",
    "any .-%s?online",
    "lf .-%s?pst",
    "lf .-%s?please",
}

------------------------------------------------------------------------
-- Ignore Patterns  (messages we should NEVER respond to)
------------------------------------------------------------------------
PS.IGNORE_PATTERNS = {
    "^wts%s",          -- "WTS [item]"
    "^wts%W",          -- "WTS: [item]"
    "^selling%s",      -- "selling [item]"
    "^wts$",           -- bare "WTS"
    "%[.*%].*%dg",     -- "[item] 5g" (price listing)
    "pst.*%dg",        -- "pst 10g" (price listing)
    "each%s*$",        -- "5g each"
    "price",           -- "good price"
    "cheap",           -- "cheap [item]"
    "discount",        -- "discount [item]"
    "free tip",        -- "free tip"
    "cod%s",           -- "COD me"
    "c%.o%.d",         -- "C.O.D."
    "in stock",        -- "in stock"
    "have .+ for sale", -- "have X for sale"
    "for sale",        -- "X for sale"
    -- Raid / group recruitment
    "ms>os",           -- loot rules
    "ms > os",         -- loot rules (spaced)
    "ms%s*/%s*os",     -- "MS/OS"
    "gdkp",           -- GDKP runs
    "soft.?res",       -- "soft reserve" / "softres"
    "%d+%s*sr%s",      -- "1 SR" (soft reserve)
    "%d+%s*sr$",       -- "1 SR" at end
    "dkp",             -- DKP runs
    "loot council",    -- loot council
    "boe.?s?%s*hr",    -- "BoE's HR" / "BoE HR"
    "bag of gems",     -- Mag loot reference
    "tank.*heal",      -- "need tank and healer"
    "heal.*tank",      -- "need healer and tank"
    "dps.*tank",       -- "need dps and tank"
    "tank.*dps",       -- "need tank and dps"
    "%d/%d%d[hm]",     -- "2/10H" or "3/25m" (raid comp)
    "arena%s*%d",      -- "arena 2s/3s/5s"
    "%f[%d][235]s%f[%A]",  -- "2s" "3s" "5s" (arena sizes)
    "%f[%d][235]v[235]",   -- "2v2" "3v3" "5v5"
    "rated",           -- rated arena/BG
    "rbg",             -- rated BG
    -- Multi-class/role recruitment (heal/mage/lock, etc.)
    "%w+/%w+/%w+%s+for",   -- "heal/mage/lock for ..."
    "lf%s+%w+/%w+",        -- "LF heal/mage" (slash-separated roles)
    -- Other players advertising THEIR services (not looking for ours)
    "^lfw%s",              -- "LFW" = Looking For Work (advertising)
    "^lfw$",               -- bare "LFW"
    "lf%s+%w+%s+work",     -- "LF lockpicking work" (offering services)
    "can%s+do%s+all",       -- "can do all lockboxes" (offering)
    "^opening%s",          -- "Opening all lockboxes..."
    "^crafting%s",         -- "Crafting [item]..."
    "^enchanting%s",       -- "Enchanting for tips..."
    "^doing%s",            -- "Doing enchants/ports..."
    "^offering%s",         -- "Offering JC cuts..."
    "^cutting%s",          -- "Cutting gems..."
    "^making%s",           -- "Making flasks..."
    "^transmuting%s",      -- "Transmuting..."
    "all%s+lockbox",       -- "all lockboxes" (bulk service ad)
    "free%s+of%s+charge",  -- "free of charge"
    "tips%s+appreciated",  -- "tips appreciated"
    "tips%s+welcome",      -- "tips welcome"
    "tipping%s+optional",  -- "tipping optional"
    "for%s+tips",          -- "enchanting for tips"
    "accepting%s+tips",    -- "accepting tips"
    "open%s+to%s+help",    -- "open to help"
    "whisper%s+me",        -- "whisper me for..."
    "pst%s+for",           -- "pst for enchants"
    "pst%s+me",            -- "pst me"
    "/w%s+me",             -- "/w me for..."
    "^i%s+can%s",          -- "I can enchant/open/craft..."
    "^can%s+do%s",         -- "Can do enchants..."
    "have%s+all%s+cut",    -- "have all cuts"
    "have%s+all%s+enchant", -- "have all enchants"
    "have%s+all%s+recipe",  -- "have all recipes"
    "have%s+all%s+pattern", -- "have all patterns"
    "max%s+lock%s*pick",   -- "max lockpicking" (advertising skill level)
    -- Mage portal sellers (competing mages advertising their services)
    "^port[sz]?%s+to%s",       -- "Ports to Shatt/SW/Org..." (offering)
    "^port[sz]?%s+available",  -- "Ports available"
    "^portal[sz]?%s+to%s",    -- "Portals to Shatt..."
    "^portal[sz]?%s+available", -- "Portals available"
    "selling%s+port",          -- "selling ports/portals"
    "port[sz]?%s+open",        -- "ports open" (offering)
    "portal[sz]?%s+open",      -- "portals open" (offering)
    "port[sz]?%s+up",          -- "ports up" / "port up"
    "portal[sz]?%s+up",        -- "portals up" / "portal up"
    "port[sz]?%s+%d+[gs]",     -- "ports 1g" (price listed)
    "portal[sz]?%s+%d+[gs]",   -- "portals 5g" (price listed)
}

------------------------------------------------------------------------
-- TBC Item Keyword Database
-- Maps keywords found in chat -> profession and item/spell info
------------------------------------------------------------------------
PS.ITEM_KEYWORDS = {
    ---------------------
    -- ENCHANTING
    ---------------------
    -- Weapon enchants
    ["mongoose"]           = { profession = "Enchanting", item = "Enchant Weapon - Mongoose" },
    ["executioner"]        = { profession = "Enchanting", item = "Enchant Weapon - Executioner" },
    ["savagery"]           = { profession = "Enchanting", item = "Enchant Weapon - Savagery" },
    ["soulfrost"]          = { profession = "Enchanting", item = "Enchant Weapon - Soulfrost" },
    ["sunfire"]            = { profession = "Enchanting", item = "Enchant Weapon - Sunfire" },
    ["battlemaster"]       = { profession = "Enchanting", item = "Enchant Weapon - Battlemaster" },
    ["spellsurge"]         = { profession = "Enchanting", item = "Enchant Weapon - Spellsurge" },
    ["major intellect"]    = { profession = "Enchanting", item = "Enchant Weapon - Major Intellect" },
    ["potency"]            = { profession = "Enchanting", item = "Enchant Weapon - Potency" },
    ["major agility"]      = { profession = "Enchanting", item = "Enchant 2H Weapon - Major Agility" },
    ["deathfrost"]         = { profession = "Enchanting", item = "Enchant Weapon - Deathfrost" },
    -- Chest
    ["exceptional stats"]  = { profession = "Enchanting", item = "Enchant Chest - Exceptional Stats" },
    ["major spirit"]       = { profession = "Enchanting", item = "Enchant Chest - Major Spirit" },
    ["exceptional health"] = { profession = "Enchanting", item = "Enchant Chest - Exceptional Health" },
    ["major resilience"]   = { profession = "Enchanting", item = "Enchant Chest - Major Resilience" },
    ["defense"]            = { profession = "Enchanting", item = "Enchant Chest - Defense" },
    -- Boots
    ["cat's swiftness"]    = { profession = "Enchanting", item = "Enchant Boots - Cat's Swiftness" },
    ["cats swiftness"]     = { profession = "Enchanting", item = "Enchant Boots - Cat's Swiftness" },
    ["boar's speed"]       = { profession = "Enchanting", item = "Enchant Boots - Boar's Speed" },
    ["boars speed"]        = { profession = "Enchanting", item = "Enchant Boots - Boar's Speed" },
    ["surefooted"]         = { profession = "Enchanting", item = "Enchant Boots - Surefooted" },
    ["fortitude"]          = { profession = "Enchanting", item = "Enchant Boots - Fortitude" },
    ["vitality"]           = { profession = "Enchanting", item = "Enchant Boots - Vitality" },
    ["dexterity"]          = { profession = "Enchanting", item = "Enchant Boots - Dexterity" },
    -- Gloves
    ["major spellpower"]   = { profession = "Enchanting", item = "Enchant Gloves - Major Spellpower" },
    ["spell strike"]       = { profession = "Enchanting", item = "Enchant Gloves - Spell Strike" },
    ["threat"]             = { profession = "Enchanting", item = "Enchant Gloves - Threat" },
    ["major strength"]     = { profession = "Enchanting", item = "Enchant Gloves - Major Strength" },
    ["assault"]            = { profession = "Enchanting", item = "Enchant Gloves - Assault" },
    ["major healing"]      = { profession = "Enchanting", item = "Enchant Gloves - Major Healing" },
    -- Cloak
    ["greater agility"]    = { profession = "Enchanting", item = "Enchant Cloak - Greater Agility" },
    ["subtlety"]           = { profession = "Enchanting", item = "Enchant Cloak - Subtlety" },
    ["steelweave"]         = { profession = "Enchanting", item = "Enchant Cloak - Steelweave" },
    -- Bracers
    ["brawn"]              = { profession = "Enchanting", item = "Enchant Bracer - Brawn" },
    ["spellpower bracer"]  = { profession = "Enchanting", item = "Enchant Bracer - Spellpower" },
    ["stats bracer"]       = { profession = "Enchanting", item = "Enchant Bracer - Stats" },
    ["superior healing"]   = { profession = "Enchanting", item = "Enchant Bracer - Superior Healing" },
    ["restore mana prime"] = { profession = "Enchanting", item = "Enchant Bracer - Restore Mana Prime" },
    -- Shield
    ["shield block"]       = { profession = "Enchanting", item = "Enchant Shield - Shield Block" },
    ["major stamina shield"] = { profession = "Enchanting", item = "Enchant Shield - Major Stamina" },
    ["resilience shield"]  = { profession = "Enchanting", item = "Enchant Shield - Resilience" },
    -- Ring (enchanter-only)
    ["ring stats"]         = { profession = "Enchanting", item = "Enchant Ring - Stats" },
    ["ring spellpower"]    = { profession = "Enchanting", item = "Enchant Ring - Spellpower" },
    ["ring healing"]       = { profession = "Enchanting", item = "Enchant Ring - Healing Power" },
    ["ring striking"]      = { profession = "Enchanting", item = "Enchant Ring - Striking" },

    ---------------------
    -- ALCHEMY
    ---------------------
    -- Transmutes
    ["primal might"]       = { profession = "Alchemy", item = "Transmute: Primal Might" },
    ["transmute primal"]   = { profession = "Alchemy", item = "Transmute: Primal Might" },
    ["primal fire"]        = { profession = "Alchemy", item = "Transmute: Primal Fire" },
    ["primal water"]       = { profession = "Alchemy", item = "Transmute: Primal Water" },
    ["primal earth"]       = { profession = "Alchemy", item = "Transmute: Primal Earth" },
    ["primal air"]         = { profession = "Alchemy", item = "Transmute: Primal Air" },
    ["primal shadow"]      = { profession = "Alchemy", item = "Transmute: Primal Shadow" },
    ["primal life"]        = { profession = "Alchemy", item = "Transmute: Primal Life" },
    ["primal mana"]        = { profession = "Alchemy", item = "Transmute: Primal Mana" },
    ["earthstorm diamond"] = { profession = "Alchemy", item = "Transmute: Earthstorm Diamond" },
    ["skyfire diamond"]    = { profession = "Alchemy", item = "Transmute: Skyfire Diamond" },
    -- Flasks
    ["flask of fortification"]     = { profession = "Alchemy", item = "Flask of Fortification" },
    ["flask of relentless assault"] = { profession = "Alchemy", item = "Flask of Relentless Assault" },
    ["flask of pure death"]        = { profession = "Alchemy", item = "Flask of Pure Death" },
    ["flask of blinding light"]    = { profession = "Alchemy", item = "Flask of Blinding Light" },
    ["flask of mighty restoration"] = { profession = "Alchemy", item = "Flask of Mighty Restoration" },
    ["flask of chromatic wonder"]  = { profession = "Alchemy", item = "Flask of Chromatic Wonder" },
    ["flask of supreme power"]     = { profession = "Alchemy", item = "Flask of Supreme Power" },
    -- Potions
    ["super mana potion"]          = { profession = "Alchemy", item = "Super Mana Potion" },
    ["super healing potion"]       = { profession = "Alchemy", item = "Super Healing Potion" },
    ["haste potion"]               = { profession = "Alchemy", item = "Haste Potion" },
    ["destruction potion"]         = { profession = "Alchemy", item = "Destruction Potion" },
    ["ironshield potion"]          = { profession = "Alchemy", item = "Ironshield Potion" },

    ---------------------
    -- JEWELCRAFTING
    ---------------------
    -- Meta gems
    ["relentless earthstorm"]      = { profession = "Jewelcrafting", item = "Relentless Earthstorm Diamond" },
    ["bracing earthstorm"]         = { profession = "Jewelcrafting", item = "Bracing Earthstorm Diamond" },
    ["chaotic skyfire"]            = { profession = "Jewelcrafting", item = "Chaotic Skyfire Diamond" },
    ["insightful earthstorm"]      = { profession = "Jewelcrafting", item = "Insightful Earthstorm Diamond" },
    ["powerful earthstorm"]        = { profession = "Jewelcrafting", item = "Powerful Earthstorm Diamond" },
    ["swift skyfire"]              = { profession = "Jewelcrafting", item = "Swift Skyfire Diamond" },
    ["mystical skyfire"]           = { profession = "Jewelcrafting", item = "Mystical Skyfire Diamond" },
    ["thundering skyfire"]         = { profession = "Jewelcrafting", item = "Thundering Skyfire Diamond" },
    ["destructive skyfire"]        = { profession = "Jewelcrafting", item = "Destructive Skyfire Diamond" },
    -- Popular cuts
    ["bold living ruby"]           = { profession = "Jewelcrafting", item = "Bold Living Ruby" },
    ["delicate living ruby"]       = { profession = "Jewelcrafting", item = "Delicate Living Ruby" },
    ["brilliant living ruby"]      = { profession = "Jewelcrafting", item = "Brilliant Living Ruby" },
    ["runed living ruby"]          = { profession = "Jewelcrafting", item = "Runed Living Ruby" },
    ["teardrop living ruby"]       = { profession = "Jewelcrafting", item = "Teardrop Living Ruby" },
    ["solid star of elune"]        = { profession = "Jewelcrafting", item = "Solid Star of Elune" },
    ["sparkling star of elune"]    = { profession = "Jewelcrafting", item = "Sparkling Star of Elune" },
    ["stormy star of elune"]       = { profession = "Jewelcrafting", item = "Stormy Star of Elune" },
    ["lustrous star of elune"]     = { profession = "Jewelcrafting", item = "Lustrous Star of Elune" },
    ["smooth dawnstone"]           = { profession = "Jewelcrafting", item = "Smooth Dawnstone" },
    ["rigid dawnstone"]            = { profession = "Jewelcrafting", item = "Rigid Dawnstone" },
    ["gleaming dawnstone"]         = { profession = "Jewelcrafting", item = "Gleaming Dawnstone" },
    ["thick dawnstone"]            = { profession = "Jewelcrafting", item = "Thick Dawnstone" },
    ["shifting nightseye"]         = { profession = "Jewelcrafting", item = "Shifting Nightseye" },
    ["glowing nightseye"]          = { profession = "Jewelcrafting", item = "Glowing Nightseye" },
    ["sovereign nightseye"]        = { profession = "Jewelcrafting", item = "Sovereign Nightseye" },
    ["inscribed noble topaz"]      = { profession = "Jewelcrafting", item = "Inscribed Noble Topaz" },
    ["potent noble topaz"]         = { profession = "Jewelcrafting", item = "Potent Noble Topaz" },
    ["luminous noble topaz"]       = { profession = "Jewelcrafting", item = "Luminous Noble Topaz" },
    ["jagged talasite"]            = { profession = "Jewelcrafting", item = "Jagged Talasite" },
    ["dazzling talasite"]          = { profession = "Jewelcrafting", item = "Dazzling Talasite" },
    ["purified shadow pearl"]      = { profession = "Jewelcrafting", item = "Purified Shadow Pearl" },
    -- Generic
    ["meta gem cut"]               = { profession = "Jewelcrafting", item = "Meta Gem Cut" },
    ["gem cut"]                    = { profession = "Jewelcrafting", item = "Gem Cut" },

    ---------------------
    -- TAILORING
    ---------------------
    ["primal mooncloth"]           = { profession = "Tailoring", item = "Primal Mooncloth" },
    ["shadowcloth"]                = { profession = "Tailoring", item = "Shadowcloth" },
    ["spellcloth"]                 = { profession = "Tailoring", item = "Spellcloth" },
    ["primal mooncloth bag"]       = { profession = "Tailoring", item = "Primal Mooncloth Bag" },
    ["imbued netherweave bag"]     = { profession = "Tailoring", item = "Imbued Netherweave Bag" },
    ["netherweave bag"]            = { profession = "Tailoring", item = "Netherweave Bag" },
    ["runic spellthread"]          = { profession = "Tailoring", item = "Runic Spellthread" },
    ["mystic spellthread"]         = { profession = "Tailoring", item = "Mystic Spellthread" },
    ["silver spellthread"]         = { profession = "Tailoring", item = "Silver Spellthread" },
    ["golden spellthread"]         = { profession = "Tailoring", item = "Golden Spellthread" },
    ["spellfire"]                  = { profession = "Tailoring", item = "Spellfire Set" },
    ["frozen shadoweave"]          = { profession = "Tailoring", item = "Frozen Shadoweave Set" },
    ["battlecast"]                 = { profession = "Tailoring", item = "Battlecast Set" },
    ["spellstrike hood"]           = { profession = "Tailoring", item = "Spellstrike Hood" },
    ["spellstrike pants"]          = { profession = "Tailoring", item = "Spellstrike Pants" },
    ["whitemend hood"]             = { profession = "Tailoring", item = "Whitemend Hood" },
    ["whitemend pants"]            = { profession = "Tailoring", item = "Whitemend Pants" },
    ["belt of blasting"]           = { profession = "Tailoring", item = "Belt of Blasting" },
    ["belt of the long road"]      = { profession = "Tailoring", item = "Belt of the Long Road" },
    ["unyielding bracers"]         = { profession = "Tailoring", item = "Bracers of Havok" },
    ["bracers of havok"]           = { profession = "Tailoring", item = "Bracers of Havok" },

    ---------------------
    -- LEATHERWORKING
    ---------------------
    ["drums of battle"]            = { profession = "Leatherworking", item = "Drums of Battle" },
    ["drums of war"]               = { profession = "Leatherworking", item = "Drums of War" },
    ["drums of restoration"]       = { profession = "Leatherworking", item = "Drums of Restoration" },
    ["drums of speed"]             = { profession = "Leatherworking", item = "Drums of Speed" },
    ["drums of panic"]             = { profession = "Leatherworking", item = "Drums of Panic" },
    ["nethercobra leg armor"]      = { profession = "Leatherworking", item = "Nethercobra Leg Armor" },
    ["cobrahide leg armor"]        = { profession = "Leatherworking", item = "Cobrahide Leg Armor" },
    ["clefthide leg armor"]        = { profession = "Leatherworking", item = "Clefthide Leg Armor" },
    ["nethercleft leg armor"]      = { profession = "Leatherworking", item = "Nethercleft Leg Armor" },
    ["riding crop"]                = { profession = "Leatherworking", item = "Riding Crop" },
    ["heavy knothide armor kit"]   = { profession = "Leatherworking", item = "Heavy Knothide Armor Kit" },
    ["vindicator's armor kit"]     = { profession = "Leatherworking", item = "Vindicator's Armor Kit" },
    ["shadowprowler's chestguard"] = { profession = "Leatherworking", item = "Shadowprowler's Chestguard" },
    ["primalstrike"]               = { profession = "Leatherworking", item = "Primalstrike Set" },
    ["windhawk"]                   = { profession = "Leatherworking", item = "Windhawk Set" },
    ["thick netherscale"]          = { profession = "Leatherworking", item = "Thick Netherscale Set" },
    ["living crystal breastplate"] = { profession = "Leatherworking", item = "Living Crystal Breastplate" },

    ---------------------
    -- BLACKSMITHING
    ---------------------
    ["weapon chain"]               = { profession = "Blacksmithing", item = "Weapon Chain" },
    ["adamantite weapon chain"]    = { profession = "Blacksmithing", item = "Adamantite Weapon Chain" },
    ["felsteel longblade"]         = { profession = "Blacksmithing", item = "Felsteel Longblade" },
    ["khorium champion"]           = { profession = "Blacksmithing", item = "Khorium Champion" },
    ["blazefury"]                  = { profession = "Blacksmithing", item = "Blazefury" },
    ["lionheart blade"]            = { profession = "Blacksmithing", item = "Lionheart Blade" },
    ["lionheart champion"]         = { profession = "Blacksmithing", item = "Lionheart Champion" },
    ["lionheart executioner"]      = { profession = "Blacksmithing", item = "Lionheart Executioner" },
    ["thunder"]                    = { profession = "Blacksmithing", item = "Thunder" },
    ["deep thunder"]               = { profession = "Blacksmithing", item = "Deep Thunder" },
    ["stormherald"]                = { profession = "Blacksmithing", item = "Stormherald" },
    ["dragonmaw"]                  = { profession = "Blacksmithing", item = "Dragonmaw" },
    ["dragonstrike"]               = { profession = "Blacksmithing", item = "Dragonstrike" },
    ["bulwark of kings"]           = { profession = "Blacksmithing", item = "Bulwark of Kings" },
    ["felsteel shield spike"]      = { profession = "Blacksmithing", item = "Felsteel Shield Spike" },
    ["belt of the guardian"]       = { profession = "Blacksmithing", item = "Belt of the Guardian" },
    ["red belt of battle"]         = { profession = "Blacksmithing", item = "Red Belt of Battle" },
    ["red havoc boots"]            = { profession = "Blacksmithing", item = "Red Havoc Boots" },
    ["boots of the protector"]     = { profession = "Blacksmithing", item = "Boots of the Protector" },

    ---------------------
    -- ENGINEERING
    ---------------------
    ["field repair bot"]           = { profession = "Engineering", item = "Field Repair Bot 110G" },
    ["repair bot"]                 = { profession = "Engineering", item = "Field Repair Bot 110G" },
    ["flying machine"]             = { profession = "Engineering", item = "Flying Machine" },
    ["turbo-charged flying machine"] = { profession = "Engineering", item = "Turbo-Charged Flying Machine" },
    ["zapthrottle"]                = { profession = "Engineering", item = "Zapthrottle Mote Extractor" },
    ["mote extractor"]             = { profession = "Engineering", item = "Zapthrottle Mote Extractor" },
    ["khorium scope"]              = { profession = "Engineering", item = "Khorium Scope" },
    ["stabilized eternium scope"]  = { profession = "Engineering", item = "Stabilized Eternium Scope" },
    ["deathblow x11 goggles"]      = { profession = "Engineering", item = "Deathblow X11 Goggles" },
    ["tankatronic goggles"]        = { profession = "Engineering", item = "Tankatronic Goggles" },
    ["wonderheal xt68"]            = { profession = "Engineering", item = "Wonderheal XT68 Sheath" },
    ["goblin rocket launcher"]     = { profession = "Engineering", item = "Goblin Rocket Launcher" },
    ["gnomish poultryizer"]        = { profession = "Engineering", item = "Gnomish Poultryizer" },
    ["adamantite rifle"]           = { profession = "Engineering", item = "Adamantite Rifle" },
    ["gyro-balanced khorium destroyer"] = { profession = "Engineering", item = "Gyro-Balanced Khorium Destroyer" },

    ---------------------
    -- COOKING (popular)
    ---------------------
    ["blackened basilisk"]         = { profession = "Cooking", item = "Blackened Basilisk" },
    ["grilled mudfish"]            = { profession = "Cooking", item = "Grilled Mudfish" },
    ["spicy crawdad"]              = { profession = "Cooking", item = "Spicy Crawdad" },
    ["golden fish sticks"]         = { profession = "Cooking", item = "Golden Fish Sticks" },
    ["fisherman's feast"]          = { profession = "Cooking", item = "Fisherman's Feast" },
    ["ravager dog"]                = { profession = "Cooking", item = "Ravager Dog" },
    ["warp burger"]                = { profession = "Cooking", item = "Warp Burger" },
    ["roasted clefthoof"]          = { profession = "Cooking", item = "Roasted Clefthoof" },

    ---------------------
    -- LOCKPICKING (requiredSkill = minimum lockpicking skill to open)
    ---------------------
    ["khorium lockbox"]            = { profession = "Lockpicking", item = "Khorium Lockbox", requiredSkill = 325 },
    ["khorium"]                    = { profession = "Lockpicking", item = "Khorium Lockbox", requiredSkill = 325 },
    ["eternium lockbox"]           = { profession = "Lockpicking", item = "Eternium Lockbox", requiredSkill = 225 },
    ["felsteel lockbox"]           = { profession = "Lockpicking", item = "Felsteel Lockbox", requiredSkill = 300 },
    ["adamantite lockbox"]         = { profession = "Lockpicking", item = "Adamantite Lockbox", requiredSkill = 275 },
    ["mithril lockbox"]            = { profession = "Lockpicking", item = "Mithril Lockbox", requiredSkill = 175 },
    ["thorium lockbox"]            = { profession = "Lockpicking", item = "Thorium Lockbox", requiredSkill = 225 },
    ["locked box"]                 = { profession = "Lockpicking", item = "Locked Box", requiredSkill = 1 },
    ["locked chest"]               = { profession = "Lockpicking", item = "Locked Chest", requiredSkill = 1 },
    ["strong junkbox"]             = { profession = "Lockpicking", item = "Strong Junkbox", requiredSkill = 175 },
    ["heavy junkbox"]              = { profession = "Lockpicking", item = "Heavy Junkbox", requiredSkill = 250 },

    ---------------------
    -- MAGE PORTALS
    ---------------------
    -- Shattrath
    ["portal shattrath"]           = { profession = "Portals", item = "Portal: Shattrath" },
    ["port shattrath"]             = { profession = "Portals", item = "Portal: Shattrath" },
    ["port shatt"]                 = { profession = "Portals", item = "Portal: Shattrath" },
    ["portal shatt"]               = { profession = "Portals", item = "Portal: Shattrath" },
    ["port shat"]                  = { profession = "Portals", item = "Portal: Shattrath" },
    ["portal shat"]                = { profession = "Portals", item = "Portal: Shattrath" },
    ["port to shattrath"]          = { profession = "Portals", item = "Portal: Shattrath" },
    ["port to shatt"]              = { profession = "Portals", item = "Portal: Shattrath" },
    ["port to shat"]               = { profession = "Portals", item = "Portal: Shattrath" },
    ["portal to shattrath"]        = { profession = "Portals", item = "Portal: Shattrath" },
    ["portal to shatt"]            = { profession = "Portals", item = "Portal: Shattrath" },
    ["portal to shat"]             = { profession = "Portals", item = "Portal: Shattrath" },
    -- Stormwind
    ["portal stormwind"]           = { profession = "Portals", item = "Portal: Stormwind" },
    ["port stormwind"]             = { profession = "Portals", item = "Portal: Stormwind" },
    ["port sw"]                    = { profession = "Portals", item = "Portal: Stormwind" },
    ["portal sw"]                  = { profession = "Portals", item = "Portal: Stormwind" },
    ["port to stormwind"]          = { profession = "Portals", item = "Portal: Stormwind" },
    ["port to sw"]                 = { profession = "Portals", item = "Portal: Stormwind" },
    ["portal to stormwind"]        = { profession = "Portals", item = "Portal: Stormwind" },
    ["portal to sw"]               = { profession = "Portals", item = "Portal: Stormwind" },
    ["port storm"]                 = { profession = "Portals", item = "Portal: Stormwind" },
    ["portal storm"]               = { profession = "Portals", item = "Portal: Stormwind" },
    -- Ironforge
    ["portal ironforge"]           = { profession = "Portals", item = "Portal: Ironforge" },
    ["port ironforge"]             = { profession = "Portals", item = "Portal: Ironforge" },
    ["port if"]                    = { profession = "Portals", item = "Portal: Ironforge" },
    ["portal if"]                  = { profession = "Portals", item = "Portal: Ironforge" },
    ["port to ironforge"]          = { profession = "Portals", item = "Portal: Ironforge" },
    ["port to if"]                 = { profession = "Portals", item = "Portal: Ironforge" },
    ["portal to ironforge"]        = { profession = "Portals", item = "Portal: Ironforge" },
    ["portal to if"]               = { profession = "Portals", item = "Portal: Ironforge" },
    -- Darnassus
    ["portal darnassus"]           = { profession = "Portals", item = "Portal: Darnassus" },
    ["port darnassus"]             = { profession = "Portals", item = "Portal: Darnassus" },
    ["port darn"]                  = { profession = "Portals", item = "Portal: Darnassus" },
    ["port to darnassus"]          = { profession = "Portals", item = "Portal: Darnassus" },
    ["port to darn"]               = { profession = "Portals", item = "Portal: Darnassus" },
    ["portal to darnassus"]        = { profession = "Portals", item = "Portal: Darnassus" },
    ["portal to darn"]             = { profession = "Portals", item = "Portal: Darnassus" },
    -- Exodar
    ["portal exodar"]              = { profession = "Portals", item = "Portal: Exodar" },
    ["port exodar"]                = { profession = "Portals", item = "Portal: Exodar" },
    ["port to exodar"]             = { profession = "Portals", item = "Portal: Exodar" },
    ["portal to exodar"]           = { profession = "Portals", item = "Portal: Exodar" },
    ["port exo"]                   = { profession = "Portals", item = "Portal: Exodar" },
    ["port to exo"]                = { profession = "Portals", item = "Portal: Exodar" },
    -- Orgrimmar
    ["portal orgrimmar"]           = { profession = "Portals", item = "Portal: Orgrimmar" },
    ["port orgrimmar"]             = { profession = "Portals", item = "Portal: Orgrimmar" },
    ["port org"]                   = { profession = "Portals", item = "Portal: Orgrimmar" },
    ["portal org"]                 = { profession = "Portals", item = "Portal: Orgrimmar" },
    ["port to orgrimmar"]          = { profession = "Portals", item = "Portal: Orgrimmar" },
    ["port to org"]                = { profession = "Portals", item = "Portal: Orgrimmar" },
    ["portal to orgrimmar"]        = { profession = "Portals", item = "Portal: Orgrimmar" },
    ["portal to org"]              = { profession = "Portals", item = "Portal: Orgrimmar" },
    -- Undercity
    ["portal undercity"]           = { profession = "Portals", item = "Portal: Undercity" },
    ["port undercity"]             = { profession = "Portals", item = "Portal: Undercity" },
    ["port uc"]                    = { profession = "Portals", item = "Portal: Undercity" },
    ["portal uc"]                  = { profession = "Portals", item = "Portal: Undercity" },
    ["port to undercity"]          = { profession = "Portals", item = "Portal: Undercity" },
    ["port to uc"]                 = { profession = "Portals", item = "Portal: Undercity" },
    ["portal to undercity"]        = { profession = "Portals", item = "Portal: Undercity" },
    ["portal to uc"]               = { profession = "Portals", item = "Portal: Undercity" },
    -- Thunder Bluff
    ["portal thunder bluff"]       = { profession = "Portals", item = "Portal: Thunder Bluff" },
    ["port thunder bluff"]         = { profession = "Portals", item = "Portal: Thunder Bluff" },
    ["port tb"]                    = { profession = "Portals", item = "Portal: Thunder Bluff" },
    ["port to thunder bluff"]      = { profession = "Portals", item = "Portal: Thunder Bluff" },
    ["port to tb"]                 = { profession = "Portals", item = "Portal: Thunder Bluff" },
    ["portal to thunder bluff"]    = { profession = "Portals", item = "Portal: Thunder Bluff" },
    ["portal to tb"]               = { profession = "Portals", item = "Portal: Thunder Bluff" },
    -- Silvermoon
    ["portal silvermoon"]          = { profession = "Portals", item = "Portal: Silvermoon" },
    ["port silvermoon"]            = { profession = "Portals", item = "Portal: Silvermoon" },
    ["port smc"]                   = { profession = "Portals", item = "Portal: Silvermoon" },
    ["port to silvermoon"]         = { profession = "Portals", item = "Portal: Silvermoon" },
    ["port to smc"]                = { profession = "Portals", item = "Portal: Silvermoon" },
    ["portal to silvermoon"]       = { profession = "Portals", item = "Portal: Silvermoon" },
    ["portal to smc"]              = { profession = "Portals", item = "Portal: Silvermoon" },
    ["port sm"]                    = { profession = "Portals", item = "Portal: Silvermoon" },
    ["port to sm"]                 = { profession = "Portals", item = "Portal: Silvermoon" },
    -- Stonard
    ["portal stonard"]             = { profession = "Portals", item = "Portal: Stonard" },
    ["port stonard"]               = { profession = "Portals", item = "Portal: Stonard" },
    ["port ston"]                  = { profession = "Portals", item = "Portal: Stonard" },
    ["port stone"]                 = { profession = "Portals", item = "Portal: Stonard" },
    ["port to stonard"]            = { profession = "Portals", item = "Portal: Stonard" },
    ["port to ston"]               = { profession = "Portals", item = "Portal: Stonard" },
    ["port to stone"]              = { profession = "Portals", item = "Portal: Stonard" },
    ["portal to stonard"]          = { profession = "Portals", item = "Portal: Stonard" },
    ["portal to ston"]             = { profession = "Portals", item = "Portal: Stonard" },
    ["port blasted"]               = { profession = "Portals", item = "Portal: Stonard" },
    ["port to blasted"]            = { profession = "Portals", item = "Portal: Stonard" },
    ["port outland"]               = { profession = "Portals", item = "Portal: Stonard" },
    ["port to outland"]            = { profession = "Portals", item = "Portal: Stonard" },
    ["port outlands"]              = { profession = "Portals", item = "Portal: Stonard" },
    ["port to outlands"]           = { profession = "Portals", item = "Portal: Stonard" },
    ["portal outland"]             = { profession = "Portals", item = "Portal: Stonard" },
    ["portal outlands"]            = { profession = "Portals", item = "Portal: Stonard" },
    ["portal to outland"]          = { profession = "Portals", item = "Portal: Stonard" },
    ["portal to outlands"]         = { profession = "Portals", item = "Portal: Stonard" },
    -- Theramore
    ["portal theramore"]           = { profession = "Portals", item = "Portal: Theramore" },
    ["port theramore"]             = { profession = "Portals", item = "Portal: Theramore" },
    ["port thera"]                 = { profession = "Portals", item = "Portal: Theramore" },
    ["port to theramore"]          = { profession = "Portals", item = "Portal: Theramore" },
    ["port to thera"]              = { profession = "Portals", item = "Portal: Theramore" },
    ["portal to theramore"]        = { profession = "Portals", item = "Portal: Theramore" },
    ["portal to thera"]            = { profession = "Portals", item = "Portal: Theramore" },
    -- Food & Water (mage conjured)
    ["mage food"]                  = { profession = "Portals", item = "Conjured Food" },
    ["mage water"]                 = { profession = "Portals", item = "Conjured Water" },
    ["mage food and water"]        = { profession = "Portals", item = "Conjured Food & Water" },
    ["mage food water"]            = { profession = "Portals", item = "Conjured Food & Water" },
    ["conjure food"]               = { profession = "Portals", item = "Conjured Food" },
    ["conjure water"]              = { profession = "Portals", item = "Conjured Water" },
    ["conjured food"]              = { profession = "Portals", item = "Conjured Food" },
    ["conjured water"]             = { profession = "Portals", item = "Conjured Water" },
    ["free food"]                  = { profession = "Portals", item = "Conjured Food" },
    ["free water"]                 = { profession = "Portals", item = "Conjured Water" },
    ["food and water"]             = { profession = "Portals", item = "Conjured Food & Water" },
    ["food water"]                 = { profession = "Portals", item = "Conjured Food & Water" },
    ["food pls"]                   = { profession = "Portals", item = "Conjured Food" },
    ["water pls"]                  = { profession = "Portals", item = "Conjured Water" },
    ["food plz"]                   = { profession = "Portals", item = "Conjured Food" },
    ["water plz"]                  = { profession = "Portals", item = "Conjured Water" },
    ["can i get food"]             = { profession = "Portals", item = "Conjured Food" },
    ["can i get water"]            = { profession = "Portals", item = "Conjured Water" },
    ["got food"]                   = { profession = "Portals", item = "Conjured Food" },
    ["got water"]                  = { profession = "Portals", item = "Conjured Water" },
}

------------------------------------------------------------------------
-- Profession Cooldown Database (daily/specialty cooldowns)
------------------------------------------------------------------------
PS.PROFESSION_COOLDOWNS = {
    ["Tailoring"] = {
        { name = "Primal Mooncloth",  spellName = "Primal Mooncloth",  cooldown = 92400 },
        { name = "Shadowcloth",       spellName = "Shadowcloth",       cooldown = 92400 },
        { name = "Spellcloth",        spellName = "Spellcloth",        cooldown = 92400 },
    },
    ["Alchemy"] = {
        { name = "Transmute",         spellName = "Transmute: Primal Might", cooldown = 72000 },
    },
    ["Leatherworking"] = {
        { name = "Salt Shaker",       spellName = "Salt Shaker",       cooldown = 72000 },
    },
}

------------------------------------------------------------------------
-- Notable Recipes Database (most popular/sought-after per profession)
-- recipe  = exact name from GetTradeSkillInfo (matched case-insensitive)
-- display = short name for ads (what people call it in trade chat)
-- Ordered by popularity/desirability (first = most wanted)
------------------------------------------------------------------------
PS.NOTABLE_RECIPES = {
    ["Engineering"] = {
        { recipe = "Stabilized Eternium Scope",        display = "Eternium Scope" },
        { recipe = "Khorium Scope",                    display = "Khorium Scope" },
        { recipe = "Field Repair Bot 110G",            display = "Repair Bot" },
        { recipe = "Zapthrottle Mote Extractor",       display = "Mote Extractor" },
        { recipe = "Turbo-Charged Flying Machine",     display = "Turbo Flying Machine" },
        { recipe = "Flying Machine",                   display = "Flying Machine" },
        { recipe = "Gyro-Balanced Khorium Destroyer",  display = "Khorium Destroyer" },
        { recipe = "Adamantite Rifle",                 display = "Adamantite Rifle" },
        { recipe = "Deathblow X11 Goggles",            display = "Deathblow Goggles" },
        { recipe = "Tankatronic Goggles",              display = "Tankatronic Goggles" },
        { recipe = "Wonderheal XT68 Sheath",           display = "Wonderheal Goggles" },
        { recipe = "Goblin Rocket Launcher",           display = "Rocket Launcher" },
        { recipe = "Gnomish Poultryizer",              display = "Poultryizer" },
    },
    ["Jewelcrafting"] = {
        { recipe = "Chaotic Skyfire Diamond",          display = "Chaotic Skyfire" },
        { recipe = "Relentless Earthstorm Diamond",    display = "Relentless Earthstorm" },
        { recipe = "Insightful Earthstorm Diamond",    display = "Insightful Earthstorm" },
        { recipe = "Bracing Earthstorm Diamond",       display = "Bracing Earthstorm" },
        { recipe = "Powerful Earthstorm Diamond",      display = "Powerful Earthstorm" },
        { recipe = "Swift Skyfire Diamond",            display = "Swift Skyfire" },
        { recipe = "Mystical Skyfire Diamond",         display = "Mystical Skyfire" },
        { recipe = "Thundering Skyfire Diamond",       display = "Thundering Skyfire" },
        { recipe = "Destructive Skyfire Diamond",      display = "Destructive Skyfire" },
        { recipe = "Bold Living Ruby",                 display = "Bold Living Ruby" },
        { recipe = "Delicate Living Ruby",             display = "Delicate Living Ruby" },
        { recipe = "Runed Living Ruby",                display = "Runed Living Ruby" },
        { recipe = "Teardrop Living Ruby",             display = "Teardrop Living Ruby" },
        { recipe = "Brilliant Living Ruby",            display = "Brilliant Living Ruby" },
        { recipe = "Solid Star of Elune",              display = "Solid Star" },
        { recipe = "Sparkling Star of Elune",          display = "Sparkling Star" },
        { recipe = "Smooth Dawnstone",                 display = "Smooth Dawnstone" },
        { recipe = "Rigid Dawnstone",                  display = "Rigid Dawnstone" },
        { recipe = "Gleaming Dawnstone",               display = "Gleaming Dawnstone" },
        { recipe = "Shifting Nightseye",               display = "Shifting Nightseye" },
        { recipe = "Sovereign Nightseye",              display = "Sovereign Nightseye" },
        { recipe = "Glowing Nightseye",                display = "Glowing Nightseye" },
        { recipe = "Inscribed Noble Topaz",            display = "Inscribed Topaz" },
        { recipe = "Potent Noble Topaz",               display = "Potent Topaz" },
        { recipe = "Luminous Noble Topaz",             display = "Luminous Topaz" },
        { recipe = "Jagged Talasite",                  display = "Jagged Talasite" },
        { recipe = "Dazzling Talasite",                display = "Dazzling Talasite" },
        { recipe = "Purified Shadow Pearl",            display = "Purified Shadow Pearl" },
    },
    ["Enchanting"] = {
        { recipe = "Enchant Weapon - Mongoose",        display = "Mongoose" },
        { recipe = "Enchant Boots - Cat's Swiftness",  display = "Cat's Swiftness" },
        { recipe = "Enchant Boots - Boar's Speed",     display = "Boar's Speed" },
        { recipe = "Enchant Weapon - Executioner",     display = "Executioner" },
        { recipe = "Enchant Weapon - Soulfrost",       display = "Soulfrost" },
        { recipe = "Enchant Weapon - Sunfire",         display = "Sunfire" },
        { recipe = "Enchant Weapon - Savagery",        display = "Savagery" },
        { recipe = "Enchant Weapon - Battlemaster",    display = "Battlemaster" },
        { recipe = "Enchant Weapon - Spellsurge",      display = "Spellsurge" },
        { recipe = "Enchant Weapon - Deathfrost",      display = "Deathfrost" },
        { recipe = "Enchant Chest - Exceptional Stats", display = "Exceptional Stats" },
        { recipe = "Enchant Gloves - Major Spellpower", display = "Major Spellpower" },
        { recipe = "Enchant Gloves - Major Healing",   display = "Major Healing" },
        { recipe = "Enchant Gloves - Threat",          display = "Threat" },
        { recipe = "Enchant Boots - Surefooted",       display = "Surefooted" },
        { recipe = "Enchant Boots - Fortitude",        display = "Fortitude" },
        { recipe = "Enchant Boots - Vitality",         display = "Vitality" },
        { recipe = "Enchant Cloak - Subtlety",         display = "Subtlety" },
        { recipe = "Enchant Cloak - Steelweave",       display = "Steelweave" },
        { recipe = "Enchant 2H Weapon - Major Agility", display = "2H Major Agility" },
        { recipe = "Enchant Weapon - Major Intellect", display = "Major Intellect" },
        { recipe = "Enchant Weapon - Potency",         display = "Potency" },
        { recipe = "Enchant Gloves - Assault",         display = "Assault" },
        { recipe = "Enchant Gloves - Major Strength",  display = "Major Strength" },
        { recipe = "Enchant Bracer - Spellpower",      display = "SP Bracer" },
        { recipe = "Enchant Bracer - Stats",           display = "Stats Bracer" },
    },
    ["Alchemy"] = {
        { recipe = "Transmute: Primal Might",          display = "Primal Might" },
        { recipe = "Transmute: Earthstorm Diamond",    display = "Earthstorm Diamond" },
        { recipe = "Transmute: Skyfire Diamond",       display = "Skyfire Diamond" },
        { recipe = "Flask of Pure Death",              display = "Flask of Pure Death" },
        { recipe = "Flask of Relentless Assault",      display = "Flask of Relentless Assault" },
        { recipe = "Flask of Fortification",           display = "Flask of Fortification" },
        { recipe = "Flask of Blinding Light",          display = "Flask of Blinding Light" },
        { recipe = "Flask of Mighty Restoration",      display = "Flask of Mighty Restoration" },
        { recipe = "Flask of Chromatic Wonder",        display = "Flask of Chromatic Wonder" },
        { recipe = "Haste Potion",                     display = "Haste Pot" },
        { recipe = "Destruction Potion",               display = "Destruction Pot" },
        { recipe = "Ironshield Potion",                display = "Ironshield Pot" },
        { recipe = "Super Mana Potion",                display = "Super Mana Pot" },
        { recipe = "Super Healing Potion",             display = "Super Healing Pot" },
        { recipe = "Transmute: Primal Fire",           display = "Xmute Fire" },
        { recipe = "Transmute: Primal Water",          display = "Xmute Water" },
        { recipe = "Transmute: Primal Air",            display = "Xmute Air" },
        { recipe = "Transmute: Primal Shadow",         display = "Xmute Shadow" },
    },
    ["Tailoring"] = {
        { recipe = "Spellstrike Hood",                 display = "Spellstrike Hood" },
        { recipe = "Spellstrike Pants",                display = "Spellstrike Pants" },
        { recipe = "Belt of Blasting",                 display = "Belt of Blasting" },
        { recipe = "Belt of the Long Road",            display = "Belt of Long Road" },
        { recipe = "Bracers of Havok",                 display = "Bracers of Havok" },
        { recipe = "Whitemend Hood",                   display = "Whitemend Hood" },
        { recipe = "Whitemend Pants",                  display = "Whitemend Pants" },
        { recipe = "Runic Spellthread",                display = "Runic Spellthread" },
        { recipe = "Mystic Spellthread",               display = "Mystic Spellthread" },
        { recipe = "Golden Spellthread",               display = "Golden Spellthread" },
        { recipe = "Silver Spellthread",               display = "Silver Spellthread" },
        { recipe = "Primal Mooncloth Bag",             display = "PMC Bag" },
        { recipe = "Imbued Netherweave Bag",           display = "Imbued NW Bag" },
        { recipe = "Primal Mooncloth",                 display = "Primal Mooncloth" },
        { recipe = "Shadowcloth",                      display = "Shadowcloth" },
        { recipe = "Spellcloth",                       display = "Spellcloth" },
        { recipe = "Netherweave Bag",                  display = "NW Bag" },
    },
    ["Leatherworking"] = {
        { recipe = "Drums of Battle",                  display = "Drums of Battle" },
        { recipe = "Drums of War",                     display = "Drums of War" },
        { recipe = "Drums of Restoration",             display = "Drums of Restoration" },
        { recipe = "Drums of Speed",                   display = "Drums of Speed" },
        { recipe = "Nethercobra Leg Armor",            display = "Nethercobra Legs" },
        { recipe = "Nethercleft Leg Armor",            display = "Nethercleft Legs" },
        { recipe = "Cobrahide Leg Armor",              display = "Cobrahide Legs" },
        { recipe = "Clefthide Leg Armor",              display = "Clefthide Legs" },
        { recipe = "Riding Crop",                      display = "Riding Crop" },
        { recipe = "Heavy Knothide Armor Kit",         display = "Heavy Knothide Kit" },
        { recipe = "Vindicator's Armor Kit",           display = "Vindicator's Kit" },
    },
    ["Blacksmithing"] = {
        { recipe = "Stormherald",                      display = "Stormherald" },
        { recipe = "Deep Thunder",                     display = "Deep Thunder" },
        { recipe = "Lionheart Executioner",            display = "Lionheart Executioner" },
        { recipe = "Lionheart Champion",               display = "Lionheart Champion" },
        { recipe = "Lionheart Blade",                  display = "Lionheart Blade" },
        { recipe = "Dragonstrike",                     display = "Dragonstrike" },
        { recipe = "Dragonmaw",                        display = "Dragonmaw" },
        { recipe = "Blazefury",                        display = "Blazefury" },
        { recipe = "Belt of the Guardian",             display = "Belt of Guardian" },
        { recipe = "Red Belt of Battle",               display = "Red Belt of Battle" },
        { recipe = "Red Havoc Boots",                  display = "Red Havoc Boots" },
        { recipe = "Boots of the Protector",           display = "Boots of Protector" },
        { recipe = "Adamantite Weapon Chain",          display = "Weapon Chain" },
        { recipe = "Felsteel Shield Spike",            display = "Shield Spike" },
        { recipe = "Bulwark of Kings",                 display = "Bulwark of Kings" },
    },
    ["Cooking"] = {
        { recipe = "Spicy Crawdad",                    display = "Spicy Crawdad" },
        { recipe = "Blackened Basilisk",               display = "Blackened Basilisk" },
        { recipe = "Warp Burger",                      display = "Warp Burger" },
        { recipe = "Grilled Mudfish",                  display = "Grilled Mudfish" },
        { recipe = "Ravager Dog",                      display = "Ravager Dog" },
        { recipe = "Golden Fish Sticks",               display = "Golden Fish Sticks" },
        { recipe = "Roasted Clefthoof",                display = "Roasted Clefthoof" },
        { recipe = "Fisherman's Feast",                display = "Fisherman's Feast" },
    },
}

------------------------------------------------------------------------
-- Matching Logic
------------------------------------------------------------------------

-- Check if a message contains a request pattern
function PS:HasRequestPattern(msg)
    local lower = msg:lower()
    for _, pattern in ipairs(self.REQUEST_PATTERNS) do
        if lower:find(pattern) then
            return true
        end
    end
    return false
end

-- Check if a message should be ignored (WTS / selling)
function PS:ShouldIgnoreMessage(msg)
    local lower = msg:lower()
    for _, pattern in ipairs(self.IGNORE_PATTERNS) do
        if lower:find(pattern) then
            return true
        end
    end
    return false
end

-- Try to match a message to a specific item keyword
-- Uses word-boundary matching to prevent "eng" matching inside "vengeance" etc.
function PS:MatchItemKeyword(msg)
    local lower = msg:lower()
    -- Try longest matches first (sort by length descending)
    local sortedKeys = {}
    for keyword, _ in pairs(self.ITEM_KEYWORDS) do
        table.insert(sortedKeys, keyword)
    end
    table.sort(sortedKeys, function(a, b) return #a > #b end)

    for _, keyword in ipairs(sortedKeys) do
        -- Use word-boundary matching: keyword must not be embedded inside another word
        local s, e = lower:find(keyword, 1, true)
        if s then
            -- Check character before match (must be non-alpha or start of string)
            local charBefore = s > 1 and lower:sub(s - 1, s - 1) or " "
            -- Check character after match (must be non-alpha or end of string)
            local charAfter = e < #lower and lower:sub(e + 1, e + 1) or " "
            if not charBefore:match("%a") and not charAfter:match("%a") then
                return self.ITEM_KEYWORDS[keyword]
            end
        end
    end
    return nil
end

-- Try to match a message to a profession via alias
-- Uses word-boundary matching to prevent false matches inside other words
function PS:MatchProfessionAlias(msg)
    local lower = msg:lower()
    -- Sort by length descending to match longer aliases first
    local sortedAliases = {}
    for alias, _ in pairs(self.PROFESSION_ALIASES) do
        table.insert(sortedAliases, alias)
    end
    table.sort(sortedAliases, function(a, b) return #a > #b end)

    for _, alias in ipairs(sortedAliases) do
        local s, e = lower:find(alias, 1, true)
        if s then
            -- Word-boundary check: must not be embedded inside another word
            local charBefore = s > 1 and lower:sub(s - 1, s - 1) or " "
            local charAfter = e < #lower and lower:sub(e + 1, e + 1) or " "
            if not charBefore:match("%a") and not charAfter:match("%a") then
                return self.PROFESSION_ALIASES[alias]
            end
        end
    end
    return nil
end

-- Match a message against player's known recipes (from scanning)
function PS:MatchKnownRecipe(msg)
    local lower = msg:lower()
    -- Also check extracted item names from links
    local linkedItems = self:ExtractLinkedItems(msg)
    for _, itemName in ipairs(linkedItems) do
        local lowerItem = itemName:lower()
        if self.knownRecipes[lowerItem] then
            return self.knownRecipes[lowerItem]
        end
    end

    -- Check plain text against known recipes
    for recipeName, data in pairs(self.knownRecipes) do
        if lower:find(recipeName, 1, true) then
            return data
        end
    end
    return nil
end

-- Full message analysis: returns match info or nil
-- Returns: { profession = "...", item = "...", matchType = "keyword"|"recipe"|"profession", requiredSkill = n }
function PS:AnalyzeMessage(msg)
    -- First check for direct item keyword matches
    local itemMatch = self:MatchItemKeyword(msg)
    if itemMatch then
        return {
            profession = itemMatch.profession,
            item = itemMatch.item,
            matchType = "keyword",
            requiredSkill = itemMatch.requiredSkill or 0,
        }
    end

    -- Check against known recipes
    local recipeMatch = self:MatchKnownRecipe(msg)
    if recipeMatch then
        return {
            profession = recipeMatch.profession,
            item = recipeMatch.name,
            matchType = "recipe",
        }
    end

    -- Fall back to generic profession alias match
    local profMatch = self:MatchProfessionAlias(msg)
    if profMatch then
        return {
            profession = profMatch,
            item = nil, -- generic profession request
            matchType = "profession",
        }
    end

    return nil
end
