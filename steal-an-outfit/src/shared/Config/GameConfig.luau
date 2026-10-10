--!strict
-- Timers, sizes and durations. Gameplay code reads every tunable number from the Config folder.
local Types = require(script.Parent.Parent.Types)

local Slots: { Types.SlotDef } = {
	{ id = "Head", attachment = "HatAttachment", displayName = "Голова" },
	{ id = "Face", attachment = "FaceFrontAttachment", displayName = "Лицо" },
	{ id = "Neck", attachment = "NeckAttachment", displayName = "Шея" },
	{ id = "Chest", attachment = "BodyFrontAttachment", displayName = "Грудь" },
	{ id = "Back", attachment = "BodyBackAttachment", displayName = "Спина" },
	{ id = "Waist", attachment = "WaistCenterAttachment", displayName = "Пояс" },
}

local GameConfig = {
	-- Order of the body slots in the HUD and everywhere else.
	Slots = Slots,

	RespawnSeconds = 3,

	Map = {
		ArenaRadius = 92, -- inner face of the outer wall (diameter ~184 studs)
		WallHeight = 30,
		WallThickness = 2,
		WallSegments = 48, -- must be a multiple of BaseCount so doors land on segment centers

		PodiumRadius = 18,
		PodiumHeight = 2,
		PodiumTiers = 3, -- shallow steps around the podium act as a ramp

		CatwalkCount = 4,
		CatwalkWidth = 6,
		CatwalkHeight = 1,

		MannequinCount = 12,
		MannequinRingRadius = 45,
		GrandMannequinScale = 1.6,

		BaseCount = 8,
		BaseWidth = 20,
		BaseDepth = 22,
		BaseHeight = 14,
		DoorWidth = 10,
		DoorHeight = 11,
	},

	Drops = {
		WaveIntervalSeconds = 60,
		FirstWaveDelaySeconds = 5,
		MaxAnnouncementsPerWave = 3,

		MannequinHoldSeconds = 0.6,
		FloorHoldSeconds = 0.3,
		PromptDistance = 8,
		PickupDistanceSlack = 6, -- extra studs tolerated on the server on top of PromptDistance

		FloorItemLifetimeSeconds = 30,
		FloorSettleSeconds = 1.2, -- physics time before a dropped item is anchored and becomes pickable
		DropPopHorizontal = 12,
		DropPopVertical = 26,

		SwapOfferSeconds = 8,
		SwapMaxDistance = 18, -- the item can be this far away when the player confirms a swap
	},

	Economy = {
		StartingCash = 0,
		IncomeTickSeconds = 1,
		SellMultiplier = 30, -- sell price = income per second * this
	},

	Zones = {
		PollSeconds = 0.2,
	},

	Combat = {
		ImmunitySeconds = 4, -- after getting up from a knockout nobody can knock you out again (anti-stunlock)
		ExitProtectionSeconds = 3, -- after leaving your dressing room: can't be hit and can't hit
		RangeSlack = 3, -- extra studs tolerated on the server (positions lag behind the attacker's screen)
		MaxHeightDifference = 6,
		SpinSpeed = 7, -- radians per second the knocked-out body tumbles with
		-- Horizontal and upward speed (studs per second) of each knockback strength.
		Knockback = {
			Weak = { push = 25, lift = 12 },
			Medium = { push = 50, lift = 20 },
			Strong = { push = 80, lift = 28 },
			VeryStrong = { push = 110, lift = 35 },
		} :: { [Types.KnockbackStrength]: { push: number, lift: number } },
	},

	-- Built-in Roblox sounds as placeholders; swap for uploaded sound ids (rbxassetid://...).
	Sounds = {
		Swing = "rbxasset://sounds/swordlunge.wav",
		Hit = "rbxasset://sounds/action_jump_land.mp3",
		GetUp = "rbxasset://sounds/action_get_up.mp3",
		RareDrop = "rbxasset://sounds/electronicpingshort.wav",
	},

	RateLimits = {
		SwapResponsePerSecond = 4,
		UseToolPerSecond = 6,
		ClientReadyPerMinute = 6,
	},
}

return GameConfig
