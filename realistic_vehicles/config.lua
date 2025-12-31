Config = {}

-- ================================
-- GTA-LIKE PASSIVE DEGRADATION
-- ================================
Config.EngineWearPerSecond = 0.07
Config.BodyWearPerSecond   = 0.015

Config.MinEngineHealth = 1.0
Config.MinBodyHealth   = 1.0

-- ================================
-- TIRE WEAR (DISTANCE BASED)
-- ================================
Config.TireWearPerMeter = 0.004
Config.MinTireHealth    = 1.0

-- ================================
-- COLLISION DAMAGE
-- ================================
Config.CollisionMultiplier = 0.9
-- Extra body damage on collisions
Config.BodyImpactMultiplier = 1.8
-- Extra engine damage on collisions
Config.EngineMultiplier = 1.8

-- ================================
-- WHEEL LOSS SETTINGS (SYNCED)
-- ================================
Config.WheelDamage = {
    Enabled = true,

    ImpactThreshold = 30,      -- Speed delta needed
    LowTireThreshold = 15,     -- Easier loss below this
    WornTireMultiplier = 1.7,
    DetachChance = 0.70
}

-- ================================
-- HUD SETTINGS
-- ================================
Config.HUD = {
    Enabled = true,
    X = 0.015,
    Y = 0.65,
    Scale = 0.35,
    Spacing = 0.025
}

-- ================================
-- REPAIR SETTINGS 1 second = 1000 ms
-- ================================
Config.RepairTimes = {
    ReplaceTires = 8000,   -- ms
    RepairEngine = 10000,  -- ms
    RepairBody   = 7000    -- ms
}

-- Amount restored
Config.RepairValues = {
    Engine = 1000.0,
    Body   = 1000.0,
    Tires  = 100.0
}

-- Maximum distance (in meters) from the vehicle to repair
Config.RepairDistance = 2.0   -- default: 5 meters, you can adjust
