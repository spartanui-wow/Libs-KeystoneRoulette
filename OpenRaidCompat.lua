-- LibOpenRaid only creates this table in its Retail data files. Every other client
-- still reads it when the player casts a spell, so give it an empty table first.
LIB_OPEN_RAID_PLAYERCOOLDOWNS = LIB_OPEN_RAID_PLAYERCOOLDOWNS or {}
