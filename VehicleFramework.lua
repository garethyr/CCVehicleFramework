require("BaseClassModifications");
require("SpringFramework/SpringFramework");

VehicleFramework = {};

-------------
--Constants--
-------------
VehicleFramework.AUTO_GENERATE = "autoGenerate";

---------
--Enums--
---------
VehicleFramework.SuspensionVisualsType = {NONE = 1, SPRITE = 2, DRAWN = 3};
VehicleFramework.TrackAnchorType = {ALL = 1, FIRST_AND_LAST = 2};
VehicleFramework.EventType = {IS_DRIVING = 1, NOT_DRIVING = 2, CHANGED_DIRECTION = 3, IS_STUCK = 4, LANDED_ON_GROUND = 5, FIRED_WEAPON = 6, SUSPENSION_CHANGED_LENGTH = 7, SUSPENSION_REACHED_LIMIT = 8};
VehicleFramework.TraversalOrderType = {FORWARDS = 1, BACKWARDS = 2, RANDOM = 3, STATELESS_RANDOM = 4};
VehicleFramework.OperatorType = {EQUAL = "==", NOT_EQUAL = "~", LESS_THAN = "<", GREATER_THAN = ">", LESS_THAN_OR_EQUAL = "<=", GREATER_THAN_OR_EQUAL = ">="};

--------------------
--Static Functions--
--------------------
function VehicleFramework.getVersion()
	return "0.9.1"
end

-------------------------------------------------------------------------------------------------------------------------
--*********************************************************************************************************************--
----------------------------------------------------FRAMEWORK BEGINS!----------------------------------------------------
--*********************************************************************************************************************--
-------------------------------------------------------------------------------------------------------------------------
function VehicleFramework.createVehicle(self, vehicleConfig)
	local vehicle = vehicleConfig;
	vehicle.self = self; --TODO integrate this properly, I'm so dumb I didn't think to do this ages ago
	
	--Initialize necessary configs if they don't exist
	vehicle.general = vehicle.general or {};
	vehicle.chassis = vehicle.chassis or {};
	vehicle.suspension = vehicle.suspension or {};
	vehicle.wheel = vehicle.wheel or {};
	vehicle.tensioner = vehicle.tensioner or nil;
	vehicle.track = vehicle.track == true and {} or vehicle.track;
	vehicle.destruction = vehicle.destruction or {};
	vehicle.layer = vehicle.layer or {};
	vehicle.events = vehicle.events or {};
	vehicle.audio = vehicle.audio or {};
	
	--------------------
	--GENERAL SETTINGS--
	--------------------
	--Necessary setup before setting defaults and limits
	vehicle.general.RTE = string.sub(self:GetModuleAndPresetName(), 1, string.find(self:GetModuleAndPresetName(), "/") - 1);
	vehicle.general.humanPlayers = {};
	for player = 0, ActivityMan:GetActivity().PlayerCount - 1 do
		if (ActivityMan:GetActivity():PlayerHuman(player)) then
			table.insert(vehicle.general.humanPlayers, player);
		end
	end
	vehicle.general.playerScreens = {};
	for _, player in ipairs(vehicle.general.humanPlayers) do
		vehicle.general.playerScreens[player] = ActivityMan:GetActivity():ScreenOfPlayer(player);
	end
	
	VehicleFramework.setCustomisationDefaultsAndLimits(self, vehicle);
	VehicleFramework.ensureVehicleConfigIsValid(vehicle);
	
	vehicle.general.team = self.Team;
	vehicle.general.pos = self.Pos;
	vehicle.general.vel = self.Vel;
	vehicle.general.controller = self:GetController();
	vehicle.general.throttle = 0;
	vehicle.general.isInAir = false;
	vehicle.general.halfOrMoreInAir = false;
	vehicle.general.distanceFallen = 0
	vehicle.general.resetDistanceFallenForGround = true;
	vehicle.general.isDriving = false;
	vehicle.general.isStronglyDecelerating = false;
	
	vehicle.previous = {};
	vehicle.previous.pos = Vector(vehicle.general.pos.X, vehicle.general.pos.Y);
	vehicle.previous.vel = Vector(vehicle.general.vel.X, vehicle.general.vel.Y);
	vehicle.previous.hFlipped = self.HFlipped;
	vehicle.previous.springDistanceFromRest = {};
	
	--------------------
	--CHASSIS SETTINGS--
	--------------------
	vehicle.chassis.size = self.SpriteOffset * -2;
	
	-----------------------
	--Suspension SETTINGS--
	-----------------------
	vehicle.suspension.springs = {};
	vehicle.suspension.objects = {};
	vehicle.suspension.offsets = {main = {}, midPoint = {}};
	vehicle.suspension.length = {};
	vehicle.suspension.longest = {max = 0};
	
	for i = 1, vehicle.wheel.count do
		if (vehicle.suspension.defaultLength ~= VehicleFramework.AUTO_GENERATE) then
			vehicle.suspension.length[i] = {min = vehicle.suspension.defaultLength.min, normal = vehicle.suspension.defaultLength.normal, max = vehicle.suspension.defaultLength.max};
		else
			vehicle.suspension.length[i] = VehicleFramework.AUTO_GENERATE;
		end
		if (vehicle.suspension.lengthOverride ~= nil and vehicle.suspension.lengthOverride[i] ~= nil) then
			vehicle.suspension.length[i] = {min = vehicle.suspension.lengthOverride[i].min, normal = vehicle.suspension.lengthOverride[i].normal, max = vehicle.suspension.lengthOverride[i].max};
		end
		if (vehicle.suspension.length[i] ~= VehicleFramework.AUTO_GENERATE) then
			vehicle.suspension.length[i].difference = vehicle.suspension.length[i].max - vehicle.suspension.length[i].min;
			vehicle.suspension.length[i].mid = vehicle.suspension.length[i].min + vehicle.suspension.length[i].difference * 0.5;
			vehicle.suspension.length[i].normal = vehicle.suspension.length[i].normal or vehicle.suspension.length[i].mid;
		end
	end
	vehicle.suspension.defaultLength = nil; vehicle.suspension.lengthOverride = nil; --Clean these up so we don't use them accidentally in future
	
	if (vehicle.suspension.visualsType == VehicleFramework.SuspensionVisualsType.DRAWN) then
		vehicle.suspension.visualsConfig.widths = {};
		for i = 1, vehicle.wheel.count do
			vehicle.suspension.visualsConfig.widths[i] = vehicle.suspension.visualsConfig.width;
		end
		vehicle.suspension.visualsConfig.width = nil; --Clean this up so we don't use it accidentally in future
	end
	
	------------------
	--WHEEL SETTINGS--
	------------------
	vehicle.wheel.objects = {};
	vehicle.wheel.size = {};
	vehicle.wheel.evenWheelCount = vehicle.wheel.count % 2 == 0;
	vehicle.wheel.midWheel = vehicle.wheel.evenWheelCount and vehicle.wheel.count * 0.5 or math.ceil(vehicle.wheel.count * 0.5);
	vehicle.wheel.isInAir = {};
	vehicle.wheel.terrainBelowWheels = {};
	vehicle.wheel.checkTerrainBelowWheelsTimer = vehicle.wheel.checkTerrainBelowWheels ~= false and Timer() or nil;
	
	-----------------------
	--TENSIONER SETTINGS--
	-----------------------
	if (vehicle.tensioner ~= nil) then
		vehicle.tensioner.objects = {};
		vehicle.tensioner.unrotatedOffsets = {};
		vehicle.tensioner.spacing = vehicle.tensioner.spacing or vehicle.wheel.spacing;
		vehicle.tensioner.size = {};
		vehicle.tensioner.evenTensionerCount = vehicle.tensioner.count % 2 == 0;
		vehicle.tensioner.midTensioner = vehicle.tensioner.evenTensionerCount and vehicle.tensioner.count * 0.5 or math.ceil(vehicle.tensioner.count * 0.5);
	end
	
	------------------
	--TRACK SETTINGS--
	------------------
	if (vehicle.track ~= nil) then
		vehicle.track.count = 0;
		vehicle.track.unrotatedOffsets = {};
		vehicle.track.trackStarts = {};
		vehicle.track.trackEnds = {};
		vehicle.track.extraFillers = {};
		vehicle.track.skippedEnds = {};
		vehicle.track.directions = {};
		vehicle.track.objects = {};
	end
	
	------------------------
	--DESTRUCTION SETTINGS--
	------------------------
	vehicle.destruction.overturnedTimer = Timer();
	vehicle.destruction.overturnedInterval = 1000;
	vehicle.destruction.overturnedCounter = 0;
	
	------------------
	--EVENT SETTINGS--
	------------------
	
	------------------
	--AUDIO SETTINGS--
	------------------
	for _, audioConfig in ipairs(vehicle.audio) do
		audioConfig.sounds = {};
		for __, player in ipairs(vehicle.general.humanPlayers) do
			audioConfig.sounds[player] = {};
		end
	end
	
	------------------
	--LAYER SETTINGS--
	------------------
	vehicle.layer.current = 1;
	vehicle.layer.allObjectsAddedForCurrentLayer = true;
	vehicle.layer.allLayersAdded = false;
	vehicle.layer.addLayerTimer = Timer();
	
	-----------------------------
	--OBJECT CREATION AND SETUP--
	-----------------------------
	VehicleFramework.setCreationFunctionsForObjects(vehicle);
	
	if (vehicle.suspension.visualsType == VehicleFramework.SuspensionVisualsType.SPRITE) then
		VehicleFramework.createSuspensionSprites(vehicle);
	end
	
	VehicleFramework.createWheels(self, vehicle);
	
	--Handle AUTO_GENERATE for vehicle.suspension.visualsConfig.widths
	if (vehicle.suspension.visualsType == VehicleFramework.SuspensionVisualsType.DRAWN) then
		for i = 1, vehicle.wheel.count do
			vehicle.suspension.visualsConfig.widths[i] = vehicle.suspension.visualsConfig.widths[i] == VehicleFramework.AUTO_GENERATE and vehicle.wheel.size[i]/3 or vehicle.suspension.visualsConfig.widths[i];
		end
	end
	
	VehicleFramework.createSprings(self, vehicle);
	
	VehicleFramework.createTensioners(self, vehicle);
	
	VehicleFramework.createTrack(self, vehicle);
	
	VehicleFramework.Audio.createSoundTablesAndTimersAndEvents(vehicle);
	
	return vehicle;
end

function VehicleFramework.setCustomisationDefaultsAndLimits(self, vehicle)
	--General
	vehicle.general.maxSpeed = vehicle.general.maxSpeed or vehicle.general.maxThrottle;
	assert(vehicle.general.maxSpeed, "Only one of vehicle.general.maxSpeed and vehicle.general.maxThrottle can be nil. Please check the Vehicle Configuration Documentation.");
	vehicle.general.maxSpeed = Clamp(vehicle.general.maxSpeed, 0, 1000000000);
	
	vehicle.general.maxThrottle = vehicle.general.maxThrottle or vehicle.general.maxSpeed;
	vehicle.general.maxThrottle = Clamp(vehicle.general.maxThrottle, 0, 1000000000);
	
	vehicle.general.acceleration = vehicle.general.acceleration or vehicle.general.maxThrottle/40;
	vehicle.general.acceleration = Clamp(vehicle.general.acceleration, 0, vehicle.general.maxThrottle);
	
	vehicle.general.deceleration = vehicle.general.deceleration or vehicle.general.acceleration/20;
	vehicle.general.deceleration = Clamp(vehicle.general.deceleration, 0, vehicle.general.maxThrottle);
	
	vehicle.general.maxErasableTerrainStrength = vehicle.general.maxErasableTerrainStrength or 100;
	vehicle.general.maxErasableTerrainStrength = Clamp(vehicle.general.maxErasableTerrainStrength, 0, 1000000000);
	
	if (vehicle.general.forceWheelHorizontalLocking == nil) then
		vehicle.general.forceWheelHorizontalLocking = (vehicle.track ~= nil or vehicle.tensioner ~= nil) and true or false;
	end
	
	vehicle.general.allowSlidingWhileStopped = vehicle.general.allowSlidingWhileStopped or false;
	
	vehicle.general.checkTerrainBelowWheels = vehicle.general.checkTerrainBelowWheels == nil and 50 or vehicle.general.checkTerrainBelowWheels;
	
	vehicle.general.showDebug = vehicle.general.showDebug == nil and false or vehicle.general.showDebug;
	
	--Chassis
	vehicle.chassis.rotAngleCorrectionRate = vehicle.chassis.rotAngleCorrectionRate or 0.04;
	vehicle.chassis.rotAngleCorrectionRate = Clamp(vehicle.chassis.rotAngleCorrectionRate, 0, 2*math.pi);
	
	vehicle.chassis.rotAngleCorrectionRateInAir = vehicle.chassis.rotAngleCorrectionRateInAir or vehicle.chassis.rotAngleCorrectionRate;
	vehicle.chassis.rotAngleCorrectionRateInAir = Clamp(vehicle.chassis.rotAngleCorrectionRateInAir, 0, 2*math.pi);
	
	vehicle.chassis.rotationAffectingWheels = vehicle.chassis.rotationAffectingWheels or {};
	if (vehicle.chassis.rotationAffectingWheels[1] == nil) then
		table.insert(vehicle.chassis.rotationAffectingWheels, 1);
	end
	--TODO properly support single wheel vehicles, this is commented out to avoid errors elsewhere
	if (vehicle.chassis.rotationAffectingWheels[2] == nil) then-- and vehicle.wheel.count > 1) then
		table.insert(vehicle.chassis.rotationAffectingWheels, vehicle.wheel.count);
	end
	assert(vehicle.wheel.count == 1 and #vehicle.chassis.rotationAffectingWheels == 1 or #vehicle.chassis.rotationAffectingWheels == 2, (vehicle.wheel.count == 1 and "You can only have 1 entry in vehicle.chassis.rotationAffectingWheels" or "You can only have 2 entries in vehicle.chassis.rotationAffectingWheels")..". Please check the Vehicle Configuration Documentation.");
	assert(type(vehicle.chassis.rotationAffectingWheels[1]) == "number", "vehicle.chassis.rotationAffectingWheels entries must be numbers. Please check the Vehicle Configuration Documentation.");
	assert(type(vehicle.chassis.rotationAffectingWheels[2]) == "nil" or type(vehicle.chassis.rotationAffectingWheels[2]) == "number", "vehicle.chassis.rotationAffectingWheels must be numbers. Please check the Vehicle Configuration Documentation.");
	
	--Suspension
	vehicle.suspension.defaultLength = vehicle.suspension.defaultLength or VehicleFramework.AUTO_GENERATE;
	
	--vehicle.suspension.lengthOverride is handled separately elsewhere
	
	vehicle.suspension.stiffness = Clamp(vehicle.suspension.stiffness, 0, 1000000000);
	
	vehicle.suspension.chassisStiffnessModifier = vehicle.suspension.chassisStiffnessModifier or VehicleFramework.AUTO_GENERATE;
	if (type(vehicle.suspension.chassisStiffnessModifier) == number) then
		vehicle.suspension.chassisStiffnessModifier = Clamp(vehicle.suspension.chassisStiffnessModifier, 1, 1000000000);
	end

	vehicle.suspension.wheelStiffnessModifier = vehicle.suspension.wheelStiffnessModifier or VehicleFramework.AUTO_GENERATE;
	if (type(vehicle.suspension.wheelStiffnessModifier) == number) then
		vehicle.suspension.wheelStiffnessModifier = Clamp(vehicle.suspension.wheelStiffnessModifier, 1, 1000000000);
	end
	
	vehicle.suspension.visualsType = vehicle.suspension.visualsType or (vehicle.track ~= nil or vehicle.tensioner ~= nil) and VehicleFramework.SuspensionVisualsType.NONE or VehicleFramework.SuspensionVisualsType.DRAWN;
	
	vehicle.suspension.visualsConfig = vehicle.suspension.visualsConfig or {};
	if (vehicle.suspension.visualsType == VehicleFramework.SuspensionVisualsType.NONE) then
		vehicle.suspension.visualsConfig = nil;
	elseif (vehicle.suspension.visualsType == VehicleFramework.SuspensionVisualsType.SPRITE) then
		vehicle.suspension.visualsConfig.objectName = vehicle.suspension.visualsConfig.objectName or self.PresetName.." Suspension";
		
		vehicle.suspension.visualsConfig.objectRTE = vehicle.suspension.visualsConfig.objectRTE or vehicle.general.RTE;
	elseif (vehicle.suspension.visualsType == VehicleFramework.SuspensionVisualsType.DRAWN) then
		vehicle.suspension.visualsConfig.width = vehicle.suspension.visualsConfig.width or VehicleFramework.AUTO_GENERATE;
		if (type(vehicle.suspension.visualsConfig.width) == number) then
			vehicle.suspension.visualsConfig.width = Clamp(vehicle.suspension.visualsConfig.width, 1, 1000000000);
		end
		
		vehicle.suspension.visualsConfig.colourIndex = vehicle.suspension.visualsConfig.colourIndex or 247;
		vehicle.suspension.visualsConfig.colourIndex = Clamp(vehicle.suspension.visualsConfig.colourIndex, 0, 255);
	end
	
	--Wheel
	assert(vehicle.wheel.count ~= nil, "You must specify the number of wheels for your Vehicle. Please check the Vehicle Configuration Documentation.")
	
	vehicle.wheel.spacing = vehicle.wheel.spacing or VehicleFramework.AUTO_GENERATE;
	if (type(vehicle.wheel.spacing) == "number") then
		vehicle.wheel.spacing = Clamp(vehicle.wheel.spacing, 0, 1000000000);
	end
	
	vehicle.wheel.objectName = vehicle.wheel.objectName or self.PresetName.." Wheel";
	
	vehicle.wheel.objectRTE = vehicle.wheel.objectRTE or vehicle.general.RTE;
	
	--Tensioner
	if (vehicle.tensioner ~= nil) then
		vehicle.tensioner.count = vehicle.tensioner.count or vehicle.wheel.count + 1;
		vehicle.tensioner.count = Clamp(vehicle.tensioner.count, 0, 1000000000);
		
		assert(vehicle.tensioner.offsetLength, "You must specify an offsetLength for your tensioners. Please check the Vehicle Configuration Documentation.");
		if (type(vehicle.tensioner.offsetLength) == "number") then
			local offsetLength = vehicle.tensioner.offsetLength;
			vehicle.tensioner.offsetLength = {};
			
			for i = 1, vehicle.tensioner.count do
				vehicle.tensioner.offsetLength[i] = offsetLength;
			end
		elseif (type(vehicle.tensioner.offsetLength) == "table") then
			if (vehicle.tensioner.offsetLength.inside ~= nil and vehicle.tensioner.offsetLength.outside ~= nil) then
				for i = 1, vehicle.tensioner.count do
					if (i == 1 or i == vehicle.tensioner.count) then
						vehicle.tensioner.offsetLength[i] = vehicle.tensioner.offsetLength.outside;
					else
						vehicle.tensioner.offsetLength[i] = vehicle.tensioner.offsetLength.inside;
					end
				end
				vehicle.tensioner.offsetLength.inside = nil;
				vehicle.tensioner.offsetLength.outside = nil;
			elseif (vehicle.tensioner.offsetLength[1] ~= nil) then
				for i = 1, vehicle.tensioner.count do
					assert(type(vehicle.tensioner.offsetLength[i]) == "number", "You have specified displacements for individual tensioners but are missing a number for tensioner "..tostring(i)..". Please check the Vehicle Configuration Documentation.");
				end
			else
				error("You have used a table for your tensioner displacements, but have not populated it properly. Please check the Vehicle Configuration Documentation.");
			end
		end
		
		vehicle.tensioner.spacing = vehicle.tensioner.spacing or vehicle.wheel.spacing;
		if (type(vehicle.tensioner.spacing) == "number") then
			vehicle.tensioner.spacing = Clamp(vehicle.tensioner.spacing, 0, 1000000000);
		end
		
		vehicle.tensioner.objectName = vehicle.tensioner.objectName or self.PresetName.." Tensioner";
		
		vehicle.tensioner.objectRTE = vehicle.tensioner.objectRTE or vehicle.general.RTE;
	end
	
	--Track
	if (vehicle.track ~= nil) then
		--vehicle.track.size is handled elsewhere
		
		vehicle.track.tightness = vehicle.track.tightness or 1.5;
		vehicle.track.tightness = Clamp(vehicle.track.tightness, 0.000001, 1000000000);
		
		vehicle.track.maxRotationDeviation = vehicle.track.maxRotationDeviation or (15 * math.pi)/180;
		vehicle.track.maxRotationDeviation = Clamp(vehicle.track.maxRotationDeviation, 0, math.pi * 2);
	
		vehicle.track.maxWounds = vehicle.track.maxWounds or 50;
		vehicle.track.maxWounds = Clamp(vehicle.track.maxWounds, 0, 1000000000);
		
		vehicle.track.tensionerAnchorType = vehicle.track.tensionerAnchorType or VehicleFramework.TrackAnchorType.ALL;
		
		vehicle.track.wheelAnchorType = vehicle.track.wheelAnchorType or VehicleFramework.TrackAnchorType.ALL;
		
		vehicle.track.objectName = vehicle.track.objectName or self.PresetName.." Track";
		
		vehicle.track.objectRTE = vehicle.track.objectRTE or vehicle.general.RTE;
		
		vehicle.track.inflectionStartOffsetDirection = vehicle.track.inflectionStartOffsetDirection or Vector(0, -1);
	end
	
	--Destruction
	vehicle.destruction.overturnedLimit = vehicle.destruction.overturnedLimit or 10;
	vehicle.destruction.overturnedLimit = Clamp(vehicle.destruction.overturnedLimit, 1, 1000000000);
	
	--Layer
	--If there's a custom layer config, ensure it has required layers
	if (next(vehicle.layer) ~= nil) then
		local necessaryLayers = {};
		
		if (vehicle.suspension.visualsType == VehicleFramework.SuspensionVisualsType.SPRITE) then
			necessaryLayers.suspension = false;
		end
		necessaryLayers.wheel = false;
		if (vehicle.tensioner ~= nil) then
			necessaryLayers.tensioner = false;
		end
		if (vehicle.track ~= nil) then
			necessaryLayers.track = false;
		end
		
		for necessaryLayer, value in pairs(necessaryLayers) do
			for _, layer in ipairs(vehicle.layer) do
				if (layer == necessaryLayer) then
					value = true;
					break;
				end
			end
			assert(value == true, "Your layer config is missing the necessary layer entry for "..necessaryLayer..". Please check the Vehicle Configuration Documentation.");
		end
	else
		if (vehicle.suspension.visualsType == VehicleFramework.SuspensionVisualsType.SPRITE) then
			table.insert(vehicle.layer, "suspension");
		end
		table.insert(vehicle.layer, "wheel");
		if (vehicle.tensioner ~= nil) then
			table.insert(vehicle.layer, "tensioner");
		end
		if (vehicle.track ~= nil) then
			table.insert(vehicle.layer, "track");
		end
	end
	
	vehicle.layer.addLayerInterval = vehicle.layer.addLayerInterval or 10;
	vehicle.layer.addLayerInterval = Clamp(vehicle.layer.addLayerInterval, 1, 1000000000);
	
	vehicle.layer.numberOfObjectsToAddPerInterval = vehicle.layer.numberOfObjectsToAddPerInterval or 0;
	vehicle.layer.numberOfObjectsToAddPerInterval = Clamp(vehicle.layer.numberOfObjectsToAddPerInterval, 0, 1000000000);
	
	--Events
	for eventTypeKey, eventType in pairs(VehicleFramework.EventType) do
		vehicle.events[eventType] = vehicle.events[eventType] or {};
	end
	for eventType, eventTable in ipairs(vehicle.events) do
		assert(type(eventTable) == "table", "Custom event config for eventType "..tostring(eventType).." is a "..type(eventTable).." when it should be a table. Please check the Vehicle Configuration Documentation.");
		for eventHandlerIndex, eventHandler in ipairs(eventTable) do
			assert(type(eventFunction) == "function", "Custom event handler "..tostring(eventHandlerIndex).." for eventType "..tostring(eventType).." is a "..type(eventHandler).." when it should be a function. Please check the Vehicle Configuration Documentation.");
		end
	end
	
	--Audio
	VehicleFramework.Audio.doAutoGeneration(vehicle);
	VehicleFramework.Audio.setCustomisationDefaultsAndLimitsAndCheckValidity(vehicle);
	
	return vehicle;
end

function VehicleFramework.ensureVehicleConfigIsValid(vehicle)
	local ignoredKeys = {
		general = {RTE = true, humanPlayers = true, playerScreens = true},
		layer = {_any = {"number"}},
		audio = {allAudioTables = true, allAudioStageTables = true}
	};
	local supportedTypes = {
		general = {
			maxSpeed = "number",
			maxThrottle = "number",
			acceleration = "number",
			deceleration = "number",
			maxErasableTerrainStrength = "number",
			forceWheelHorizontalLocking = "boolean",
			allowSlidingWhileStopped = "boolean",
			checkTerrainBelowWheels = {"boolean", "number"},
			showDebug = "boolean"
		},
		chassis = {
			rotAngleCorrectionRate = "number",
			rotAngleCorrectionRateInAir = "number",
			rotationAffectingWheels = "table"
		},
		suspension = {
			defaultLength = {"table", "string"},
			lengthOverride = {"table", "nil"},
			stiffness = "number",
			chassisStiffnessModifier = {"number", "string"},
			wheelStiffnessModifier = {"number", "string"},
			visualsType = "number",
			visualsConfig = {"table", "nil"}
		},
		wheel = {
			spacing = {"number", "string"},
			count = "number",
			objectName = "string",
			objectRTE = "string"
		},
		tensioner = {
			offsetLength = {"number", "table"},
			spacing = {"number", "string"},
			count = "number",
			objectName = "string",
			objectRTE = "string"
		},
		track = {
			maxWounds = "number",
			objectName = "string",
			objectRTE = "string",
			tightness = "number",
			maxRotationDeviation = "number",
			tensionerAnchorType = "number",
			wheelAnchorType = "number",
			inflectionStartOffsetDirection = {"userdata", "nil"},
			inflection = {"table", "nil"}
		},
		destruction = {
			overturnedLimit = "number"
		},
		layer = {
			addLayerInterval = "number",
			numberOfObjectsToAddPerInterval = "number"
		},
		events = {
			_anyNumber = "table"
		},
		audio = {
			_anyNumber = "table"
		}
	}
	--Ensure everything is a real configuration option and has the correct type
	for categoryKey, categoryTable in pairs(vehicle) do
		if (categoryKey ~= "self") then
			for optionKey, optionValue in pairs(categoryTable) do
				if (ignoredKeys[categoryKey] == nil or (ignoredKeys[categoryKey][optionKey] ~= true and ignoredKeys[categoryKey]._all ~= true)) then
					assert(supportedTypes[categoryKey], "vehicle."..tostring(categoryKey).." is an invalid configuration option category. Please check the Vehicle Configuration Documentation.");
					
					--Handle special _any ignore values to ignore any keys of a given type
					local continueChecks = true;
					if (ignoredKeys[categoryKey] ~= nil and ignoredKeys[categoryKey]._any ~= nil) then
						for _, ignoredKeyType in ipairs(ignoredKeys[categoryKey]._any) do
							if (type(optionKey) == ignoredKeyType) then
								continueChecks = false;
							end
						end
					end
					
					if (continueChecks) then
						for supportedOptionKey, _ in pairs(supportedTypes[categoryKey]) do
							if (supportedOptionKey:find("_any") ~= nil) then
								local dataType = supportedOptionKey:sub(string.len("_any") + 1, supportedOptionKey:len()):lower();
								if (type(optionKey) == dataType) then
									optionKey = supportedOptionKey;
								end
							end
						end
						
						assert(supportedTypes[categoryKey][optionKey], "vehicle."..tostring(categoryKey).."."..tostring(optionKey).." is an invalid configuration option. Please check the Vehicle Configuration Documentation.");
						if (type(supportedTypes[categoryKey][optionKey]) == "string") then
							assert(type(optionValue) == supportedTypes[categoryKey][optionKey], "vehicle."..tostring(categoryKey).."."..tostring(optionKey).." must be a "..tostring(supportedTypes[categoryKey][optionKey]).." but is a "..tostring(type(optionValue))..". Please check the Vehicle Configuration Documentation.");
						elseif (type(supportedTypes[categoryKey][optionKey]) == "table") then
							local typeIsSupported = false;
							for _, supportedType in pairs(supportedTypes[categoryKey][optionKey]) do
								if (type(optionValue) == supportedType) then
									typeIsSupported = true;
									break;
								end
							end
							assert(typeIsSupported, "vehicle."..tostring(categoryKey).."."..tostring(optionKey).." must be one of the following: "..tostring(table.concat(supportedTypes[categoryKey][optionKey], ", "))..". Please check the Vehicle Configuration Documentation.");
						end
					end
				end
			end
		end
	end
end

function VehicleFramework.setCreationFunctionsForObjects(vehicle)
	vehicle.general.allObjectsAreActors = true;
	
	local objectGroupsToSetupCreationFunctionsFor = {suspension = vehicle.suspension.visualsType == VehicleFramework.SuspensionVisualsType.SPRITE, wheel = true, tensioner = vehicle.tensioner ~= nil, track = vehicle.track ~= nil}
	local presetModuleId, preset;
	
	for objectGroup, objectWillBeCreated in pairs(objectGroupsToSetupCreationFunctionsFor) do
		if (objectWillBeCreated) then
			presetModuleId = PresetMan:GetModuleIDFromPath(vehicle[objectGroup].objectRTE);
			assert(presetModuleId > -1, "Your vehicle "..tostring(objectGroup).." objects used a nonexistant RTE, "..tostring(vehicle[objectGroup].objectRTE)..". Please see the Vehicle Configuration Documentation");
			
			for preset in PresetMan:GetDataModule(presetModuleId).Presets do
				if (preset.PresetName == vehicle[objectGroup].objectName) then
					vehicle[objectGroup].creationFunction = loadstring("return Create"..preset.ClassName.."(...)");
					vehicle.general.allObjectsAreActors = vehicle.general.allObjectsAreActors and preset.ClassName == "Actor";
					break;
				end
			end
			
			assert(vehicle[objectGroup].creationFunction ~= nil, "Unable to find a preset named "..tostring(vehicle[objectGroup].objectName).." in RTE "..tostring(vehicle[objectGroup].objectRTE).." so could not set up a creation function for "..tostring(objectGroup).." objects. Please see the Vehicle Configuration Documentation.");
		end
	end
end

function VehicleFramework.createSuspensionSprites(vehicle)
	for i = 1, vehicle.suspension.count do
		if not MovableMan:ValidMO(vehicle.suspension.objects[i]) then
			vehicle.suspension.objects[i] = vehicle.suspension.creationFunction(vehicle.suspension.objectName, vehicle.suspension.objectRTE);
			vehicle.suspension.objects[i].Pos = vehicle.general.pos;
			vehicle.suspension.objects[i].Team = vehicle.general.team;
			vehicle.suspension.objects[i].MissionCritical = true;
		end
	end
end

function VehicleFramework.createWheels(self, vehicle)
	local calculateAutoGeneratedSuspensionLength = function(wheelSize)
		local length = {min = wheelSize * 0.5, normal = wheelSize, max = wheelSize * 1.5};
		
		length.difference = length.max - length.min;
		length.mid = length.min + length.difference * 0.5;
		length.normal = length.normal or length.mid;
		
		return length;
	end

	local calculateWheelOffsetAndPosition = function(rotAngle, vehicle, wheelNumber)
		local xOffset;
		if (wheelNumber == vehicle.wheel.midWheel) then
			xOffset = vehicle.wheel.evenWheelCount and -vehicle.wheel.spacing * 0.5 or 0;
		else
			xOffset = vehicle.wheel.spacing * (wheelNumber - vehicle.wheel.midWheel) + (vehicle.wheel.evenWheelCount and -vehicle.wheel.spacing * 0.5 or 0);
		end
		
		vehicle.wheel.unrotatedOffsets[wheelNumber] = Vector(xOffset, vehicle.suspension.length[wheelNumber].normal);
		return vehicle.general.pos + Vector(vehicle.wheel.unrotatedOffsets[wheelNumber].X, vehicle.wheel.unrotatedOffsets[wheelNumber].Y):RadRotate(rotAngle);
	end

	vehicle.wheel.unrotatedOffsets = {};
	for i = 1, vehicle.wheel.count do
		if not MovableMan:ValidMO(vehicle.wheel.objects[i]) then
			vehicle.wheel.objects[i] = vehicle.wheel.creationFunction(vehicle.wheel.objectName, vehicle.wheel.objectRTE);
			vehicle.wheel.size[i] = vehicle.wheel.objects[i].Diameter/math.sqrt(2);
			
			--Handle AUTO_GENERATE for vehicle.suspension.length
			if (vehicle.suspension.length[i] == VehicleFramework.AUTO_GENERATE) then
				vehicle.suspension.length[i] = calculateAutoGeneratedSuspensionLength(vehicle.wheel.size[i]);
			end
			
			--Handle AUTO_GENERATE for vehicle.wheel.spacing
			if (i == 1 and vehicle.wheel.spacing == VehicleFramework.AUTO_GENERATE) then
				vehicle.wheel.spacing = math.ceil(vehicle.wheel.size[i] * 1.15);
			end
			
			vehicle.wheel.objects[i].Team = vehicle.general.team;
			vehicle.wheel.objects[i].Pos = calculateWheelOffsetAndPosition(self.RotAngle, vehicle, i);
			vehicle.wheel.objects[i].Vel = Vector(0, 0);
			vehicle.wheel.objects[i].IgnoresTeamHits = vehicle.general.forceWheelHorizontalLocking;
			vehicle.wheel.objects[i].MissionCritical = true;
		end
		
		vehicle.suspension.longest = vehicle.suspension.length[i].max > vehicle.suspension.longest.max and vehicle.suspension.length[i] or vehicle.suspension.longest;
	end
end

function VehicleFramework.createSprings(self, vehicle)
	--Handle AUTO_GENERATE for vehicle.suspension.chassisStiffnessModifier
	if (vehicle.suspension.chassisStiffnessModifier == VehicleFramework.AUTO_GENERATE) then
		vehicle.suspension.chassisStiffnessModifier = self.Mass/vehicle.wheel.count;
	end
	
	for i, wheelObject in ipairs(vehicle.wheel.objects) do
		--Handle AUTO_GENERATE for vehicle.suspension.wheelStiffnessModifier
		if (vehicle.suspension.wheelStiffnessModifier == VehicleFramework.AUTO_GENERATE) then
			vehicle.suspension.wheelStiffnessModifier = wheelObject.Mass;
		end
		
		local springConfig = {
			length = {vehicle.suspension.length[i].min, vehicle.suspension.length[i].normal, vehicle.suspension.length[i].max},
			primaryTarget = 1,
			stiffness = vehicle.suspension.stiffness,
			stiffnessMultiplier = {vehicle.suspension.chassisStiffnessModifier, vehicle.suspension.wheelStiffnessModifier},
			offsets = Vector(vehicle.wheel.objects[i].Pos.X - vehicle.general.pos.X, 0),
			applyForcesAtOffset = true,
			lockToSpringRotation = not vehicle.general.forceWheelHorizontalLocking,
			inheritsRotAngle = 1,
			rotAngleOffset = -math.pi*0.5,
			outsideOfConfinesAction = {SpringFramework.OutsideOfConfinesOptions.DO_NOTHING, SpringFramework.OutsideOfConfinesOptions.MOVE_TO_REST_POSITION},
			confinesToCheck = {min = false, absolute = true, max = true},
			showDebug = vehicle.general.showDebug
		}
		vehicle.suspension.springs[i] = SpringFramework.create(self, vehicle.wheel.objects[i], springConfig);
		
		vehicle.previous.springDistanceFromRest[i] = Vector(vehicle.suspension.springs[i].unrotatedDistances[2].rest.X, vehicle.suspension.springs[i].unrotatedDistances[2].rest.Y);
	end
end

function VehicleFramework.createTensioners(self, vehicle)
	if (vehicle.tensioner ~= nil) then
		local xOffset;
		for i = 1, vehicle.tensioner.count do
			if not MovableMan:ValidMO(vehicle.tensioner.objects[i]) then
				vehicle.tensioner.objects[i] = vehicle.tensioner.creationFunction(vehicle.tensioner.objectName, vehicle.tensioner.objectRTE);
				vehicle.tensioner.size[i] = vehicle.tensioner.objects[i].Diameter/math.sqrt(2);
	
				--Handle AUTO_GENERATE for vehicle.tensioner.spacing
				if (vehicle.tensioner.spacing == VehicleFramework.AUTO_GENERATE) then
					vehicle.tensioner.spacing = vehicle.wheel.spacing;
				end
				
				if (i == vehicle.tensioner.midTensioner) then
					xOffset = vehicle.tensioner.evenTensionerCount and -vehicle.tensioner.spacing * 0.5 or 0;
				else
					xOffset = vehicle.tensioner.spacing * (i - vehicle.tensioner.midTensioner) + (vehicle.tensioner.evenTensionerCount and -vehicle.tensioner.spacing * 0.5 or 0);
				end
				vehicle.tensioner.unrotatedOffsets[i] = Vector(xOffset, vehicle.tensioner.offsetLength[i]);
				
				vehicle.tensioner.objects[i].Team = vehicle.general.team;
				vehicle.tensioner.objects[i].Vel = Vector(0, 0);
				vehicle.tensioner.objects[i].IgnoresTeamHits = true;
				vehicle.tensioner.objects[i].MissionCritical = true;
			end
		end
		VehicleFramework.updateTensioners(self, vehicle);
	end
end

function VehicleFramework.createTrack(self, vehicle)
	if (vehicle.track ~= nil) then
		local trackSizer = vehicle.track.creationFunction(vehicle.track.objectName, vehicle.track.objectRTE);
		vehicle.track.size = trackSizer.SpriteOffset * -2;
		trackSizer.ToDelete = true;
		trackSizer = nil;
	
		VehicleFramework.setupTrackInflection(vehicle);
		VehicleFramework.calculateTrackOffsets(vehicle);
		
		for i = 1, vehicle.track.count do
			if not MovableMan:ValidMO(vehicle.track.objects[i]) then
				vehicle.track.objects[i] = vehicle.track.creationFunction(vehicle.track.objectName, vehicle.track.objectRTE);
				vehicle.track.objects[i].Team = vehicle.general.team;
				vehicle.track.objects[i].Vel = Vector();
				vehicle.track.objects[i].Pos = vehicle.general.pos + Vector(vehicle.track.unrotatedOffsets[i].X, vehicle.track.unrotatedOffsets[i].Y):RadRotate(self.RotAngle);
				vehicle.track.objects[i].RotAngle = self.RotAngle + vehicle.track.directions[i];
				vehicle.track.objects[i].IgnoresTeamHits = true;
				vehicle.track.objects[i].MissionCritical = true;
			end
		end
	end
end

function VehicleFramework.setupTrackInflection(vehicle)
	if (vehicle.track.inflection == nil) then
		vehicle.track.inflection = {};
		local inflectionConfig, iteratorIncrement;
		
		if (vehicle.tensioner ~= nil) then
			iteratorIncrement = vehicle.track.tensionerAnchorType == VehicleFramework.TrackAnchorType.FIRST_AND_LAST and (vehicle.tensioner.count - 1) or 1;
			for i = 1, vehicle.tensioner.count, iteratorIncrement do
				inflectionConfig = {
					point = vehicle.tensioner.unrotatedOffsets[i],
					objectTable = vehicle.tensioner,
					objectIndex = i,
					object = vehicle.tensioner.objects[i],
					objectSize = vehicle.tensioner.size[i]
				}
				table.insert(vehicle.track.inflection, inflectionConfig);
			end
		end
		
		iteratorIncrement = vehicle.track.wheelAnchorType == VehicleFramework.TrackAnchorType.FIRST_AND_LAST and (vehicle.wheel.count - 1) or 1;
		for i = vehicle.wheel.count, 1, -iteratorIncrement do
			inflectionConfig = {
				point = vehicle.wheel.unrotatedOffsets[i],
				objectTable = vehicle.wheel,
				objectIndex = i,
				object = vehicle.wheel.objects[i],
				objectSize = vehicle.wheel.size[i]
			}
			table.insert(vehicle.track.inflection, inflectionConfig);
		end
	end
	
	for i, inflection in ipairs(vehicle.track.inflection) do
		inflection.next = vehicle.track.inflection[i%#vehicle.track.inflection + 1];
		inflection.distanceToNext = SceneMan:ShortestDistance(inflection.point, inflection.next.point, SceneMan.SceneWrapsX);
		inflection.directionToNext = inflection.distanceToNext.AbsRadAngle;
		inflection.directionVectorToNext = Vector(math.cos(inflection.directionToNext), -math.sin(inflection.directionToNext)).Normalized;
	end
	
	local offsetDirection;
	local trackTightnessMultiplier = 0.5/vehicle.track.tightness;
	for i, inflection in ipairs(vehicle.track.inflection) do
		local offsetDirection = Vector(vehicle.track.inflectionStartOffsetDirection.X, vehicle.track.inflectionStartOffsetDirection.Y):RadRotate(inflection.directionToNext);
		
		inflection.trackStart = inflection.point + offsetDirection * (inflection.objectSize * trackTightnessMultiplier + vehicle.track.size.Y * trackTightnessMultiplier);
		inflection.trackEnd = inflection.next.point + offsetDirection * (inflection.next.objectSize * trackTightnessMultiplier + vehicle.track.size.Y * trackTightnessMultiplier);
		
		inflection.trackDistance = SceneMan:ShortestDistance(inflection.trackStart, inflection.trackEnd, SceneMan.SceneWrapsX);
		inflection.trackDirection = inflection.trackDistance.AbsRadAngle;
		inflection.trackDirectionVector = Vector(math.cos(inflection.trackDirection), -math.sin(inflection.trackDirection)).Normalized;
	end
end

function VehicleFramework.calculateTrackOffsets(vehicle)
	local numberOfTracks, remainderDistance, extraFillerTrack, extraCornerTrack, stretchTreadMultiplier;
	
	for i, inflection in ipairs(vehicle.track.inflection) do
		numberOfTracks = math.ceil(inflection.trackDistance.Magnitude/vehicle.track.size.X);
		
		--Add an extra track to fill in space if necessary, i.e. the remainder distance is more than 1/10th of number of tracks (so 5 tracks would become 6 if the remainder distance is > 0.5 track width)
		if (numberOfTracks == 1) then
			numberOfTracks = 2;
			remainderDistance = 0;
			extraFillerTrack = false;
		else
			remainderDistance = (inflection.trackDistance.Magnitude%vehicle.track.size.X)/vehicle.track.size.X;
			extraFillerTrack = remainderDistance > numberOfTracks * 0.06;
			if (vehicle.general.showDebug) then
				if (extraFillerTrack == true) then
					print("Adding extra filler track for inflection "..tostring(i));
				else
					print("NOT Adding extra filler track for inflection "..tostring(i));
				end
			end
		end
		numberOfTracks = extraFillerTrack and numberOfTracks + 1 or numberOfTracks;
		
		--Add an extra track if the angle difference between this inflection and the next is significant, to support corners
		extraCornerTrack = false;
		do
		end
		numberOfTracks = extraCornerTrack and numberOfTracks + 1 or numberOfTracks;
		
		stretchTreadMultiplier = (extraFillerTrack == false and remainderDistance > 0) and remainderDistance/numberOfTracks - (extraCornerTrack and 3 or 2) or 1;
		
		for j = 1, numberOfTracks do
			if (j == 1) then
				table.insert(vehicle.track.unrotatedOffsets, inflection.trackStart);-- + (i ~= 1 and Vector(vehicle.track.size.X * 0.5, 0):RadRotate(inflection.trackDirection) or Vector()));
				table.insert(vehicle.track.trackStarts, #vehicle.track.unrotatedOffsets);
				
				--If the last inflection skipped its end cause it would be duplicated by this start, set this start as the previous inflection's
				if (vehicle.track.skippedEnds[i-1] == true) then
					table.insert(vehicle.track.trackEnds, #vehicle.track.unrotatedOffsets);
				end
			elseif (j == numberOfTracks) then
				if (vehicle.general.showDebug) then
					--print("direction difference: "..tostring(math.abs(inflection.next.trackDirection - inflection.trackDirection))..", distance magnitude: "..tostring(SceneMan:ShortestDistance(inflection.trackEnd, inflection.next.trackStart, SceneMan.SceneWrapsX).Magnitude));
				end
				if (math.abs(inflection.next.trackDirection - inflection.trackDirection)  > (30 * math.pi/180) and SceneMan:ShortestDistance(inflection.trackEnd, inflection.next.trackStart, SceneMan.SceneWrapsX).Magnitude > vehicle.track.size.Magnitude * 0.1) then
					table.insert(vehicle.track.unrotatedOffsets, inflection.trackEnd);
					table.insert(vehicle.track.trackEnds, #vehicle.track.unrotatedOffsets);
					vehicle.track.skippedEnds[i] = false;
					if (vehicle.general.showDebug) then
						print("Adding end track for inflection "..tostring(i));
					end
				else
					numberOfTracks = numberOfTracks - 1;
					vehicle.track.skippedEnds[i] = true;
					if (vehicle.general.showDebug) then
						print("Not adding end track for inflection "..tostring(i));
					end
					break;
				end
			--elseif (j == numberOfTracks) then
			--	table.insert(vehicle.track.unrotatedOffsets, (inflection.trackEnd + inflection.next.trackStart) * 0.5);
			else
				table.insert(vehicle.track.unrotatedOffsets, vehicle.track.unrotatedOffsets[#vehicle.track.unrotatedOffsets] + inflection.trackDirectionVector * vehicle.track.size.X * stretchTreadMultiplier);
				if (extraFillerTrack and j == numberOfTracks - 1) then
					table.insert(vehicle.track.extraFillers, #vehicle.track.unrotatedOffsets);
				end
			end
			
			--table.insert(vehicle.track.directions, j == numberOfTracks and (inflection.trackDirection + inflection.next.trackDirection) * 0.5 or inflection.trackDirection);
			table.insert(vehicle.track.directions, inflection.trackDirection);
		end
		--Move filler tracks to the middle of their neighbouring tracks
		if (extraFillerTrack) then
			local fillerNumber = vehicle.track.extraFillers[#vehicle.track.extraFillers];
			vehicle.track.unrotatedOffsets[fillerNumber] = (vehicle.track.unrotatedOffsets[fillerNumber - 1] + (vehicle.track.unrotatedOffsets[fillerNumber + 1] or inflection.trackEnd)) * 0.5;
		end
		vehicle.track.count = vehicle.track.count + numberOfTracks;
	end
end

function VehicleFramework.deleteVehicle(vehicle)
	if (vehicle) then
		if (vehicle.suspension.visualsType == VehicleFramework.SuspensionVisualsType.SPRITE) then
			for _, suspensionObject in ipairs(vehicle.suspension.objects) do
				if MovableMan:ValidMO(suspensionObject) then
					suspensionObject.ToDelete = true;
				end
			end
		end
		for _, wheelObject in ipairs(vehicle.wheel.objects) do
			if MovableMan:ValidMO(wheelObject) then
				wheelObject.ToDelete = true;
			end
		end
		if (vehicle.tensioner ~= nil) then
			for _, tensionerObject in ipairs(vehicle.tensioner.objects) do
				if MovableMan:ValidMO(tensionerObject) then
					tensionerObject.ToDelete = true;
				end
			end
		end
		if (vehicle.track ~= nil) then
			for _, trackObject in ipairs(vehicle.track.objects) do
				if MovableMan:ValidMO(trackObject) then
					trackObject.ToDelete = true;
				end
			end
		end
	end
end

function VehicleFramework.updateVehicle(self, vehicle)
	if (vehicle == nil) then
		print("******************************************************************************************************");
		print("Your vehicle has been incorrectly configured and cannot run. Please check the Vehicle Configuration Documentation.");
		print("******************************************************************************************************");
		vehicle = false;
	end
	
	if (vehicle) then
		if (not vehicle.layer.allLayersAdded) then
			VehicleFramework.updateLayers(vehicle);
		end
		
		local destroyed = VehicleFramework.updateDestruction(self, vehicle);
		
		if (not destroyed) then
			VehicleFramework.updateAltitudeChecks(vehicle);
			
			VehicleFramework.updateThrottle(vehicle);
			
			VehicleFramework.updateWheels(vehicle);
			
			VehicleFramework.updateSprings(vehicle);
			
			VehicleFramework.updateTerrainBelowWheels(vehicle);
			
			VehicleFramework.updateTensioners(self, vehicle);
			
			VehicleFramework.updateTrack(self, vehicle);
			
			VehicleFramework.updateChassis(self, vehicle);
			
			VehicleFramework.Audio.earlyUpdate(vehicle);
			
			VehicleFramework.updateEvents(vehicle);
			
			VehicleFramework.Audio.update(vehicle);
			
			VehicleFramework.updateVisuals(self, vehicle);
		end
		
		VehicleFramework.updatePreviousValues(vehicle);
	end
	
	return vehicle;
end

function VehicleFramework.updateLayers(vehicle)
	if (vehicle.layer.addLayerTimer:IsPastSimMS(vehicle.layer.addLayerInterval)) then
		vehicle.layer.allObjectsAddedForCurrentLayer = true;
		
		local layer = vehicle.layer[vehicle.layer.current];
		local addedObjectCount = 0;
		
		if (type(layer) == "userdata") then
			MovableMan:AddParticle(layer);
		elseif(type(layer) == "table") then
			for layerObjectIndex, layerObject in ipairs(layer) do
				assert(type(layerObject) == "userdata", "Layer "..tostring(vehicle.layer.current).."'s entry with the index "..tostring(layerObjectKey).." is a "..tostring(type(layerObject)).." which is not valid. Please check the Vehicle Configuration Documentation.");
				if (layerObject.ClassName == "AHuman" or layerObject.ClassName == "ACrab" or layerObject.ClassName == "ACRocket" or layerObject.ClassName == "ACDropship" or layerObject.ClassName == "ACraft" or layerObject.ClassName == "Actor") then
					MovableMan:AddActor(layerObject);
				else
					MovableMan:AddParticle(layerObject);
				end
				
				if (vehicle.layer.numberOfObjectsToAddPerInterval > 0) then
					addedObjectCount = addedObjectCount + 1;
					if (addedObjectCount >= vehicle.layer.numberOfObjectsToAddPerInterval) then
						vehicle.layer.allObjectsAddedForCurrentLayer = false;
						break;
					end
				end
			end
		elseif(type(layer) == "string") then
			for _, layerObject in ipairs(vehicle[layer].objects) do
				if (not MovableMan:ValidMO(layerObject)) then
					MovableMan:AddParticle(layerObject);
					
					if (vehicle.layer.numberOfObjectsToAddPerInterval > 0) then
						addedObjectCount = addedObjectCount + 1;
						if (addedObjectCount >= vehicle.layer.numberOfObjectsToAddPerInterval) then
							vehicle.layer.allObjectsAddedForCurrentLayer = false;
							break;
						end
					end
				end
			end
		else
			error("Layer "..tostring(vehicle.layer.current).." is of type "..tostring(type(layer)).." which is not valid. Please check the Vehicle Configuration Documentation.");
		end
		
		vehicle.layer.allLayersAdded = vehicle.layer.allObjectsAddedForCurrentLayer and vehicle.layer.current == #vehicle.layer;
		vehicle.layer.current = vehicle.layer.allObjectsAddedForCurrentLayer and vehicle.layer.current + 1 or vehicle.layer.current;
		
		if (vehicle.layer.allLayersAdded) then
			vehicle.layer.addLayerTimer = nil;
			vehicle.layer.addLayerInterval = nil;
		else
			vehicle.layer.addLayerTimer:Reset();
		end
	end
end

function VehicleFramework.updateDestruction(self, vehicle)
	if (self.Health < 0) then
		self:GibThis();
		return true;
	end
	
	if (vehicle.destruction.overturnedTimer:IsPastSimMS(vehicle.destruction.overturnedInterval)) then
		local rotAngleInDegrees = math.floor(self.RotAngle * 180 / math.pi)%360;
		if ((rotAngleInDegrees > 95 and rotAngleInDegrees < 265) or (rotAngleInDegrees < -95 and rotAngleInDegrees > -265)) then
			vehicle.destruction.overturnedCounter = vehicle.destruction.overturnedCounter + 1;
		end
		
		if (vehicle.destruction.overturnedCounter > vehicle.destruction.overturnedLimit) then
			if (vehicle.general.showDebug) then
				print ("Vehicle was overturned and went boom cause it hit limit "..tostring(vehicle.destruction.overturnedLimit));
			end
			self:GibThis();
			return true;
		else
			vehicle.destruction.overturnedCounter = math.max(vehicle.destruction.overturnedCounter - 1, 0);
		end
		vehicle.destruction.overturnedTimer:Reset();
	end
	
	return false;
end

function VehicleFramework.updateAltitudeChecks(vehicle)
	local checkAltitudeForWheel;
	local inAirWheelCount = 0;
	vehicle.wheel.isInAir = {};
	for i, wheelObject in ipairs(vehicle.wheel.objects) do
		local wheelAltitude = wheelObject:GetAltitude(0, vehicle.wheel.size[i]);
		vehicle.wheel.isInAir[i] = false;
		
		if (wheelAltitude > vehicle.wheel.size[i] * 2) then
			vehicle.wheel.isInAir[i] = true;
			inAirWheelCount = inAirWheelCount + 1;
		end
	end
	vehicle.general.isInAir = inAirWheelCount == vehicle.wheel.count;
	vehicle.general.halfOrMoreInAir = inAirWheelCount > vehicle.wheel.count * 0.5;
	
	if (vehicle.general.isInAir) then
		if (vehicle.general.vel.Y > 0) then
			vehicle.general.distanceFallen = vehicle.general.distanceFallen + SceneMan:ShortestDistance(vehicle.previous.pos, vehicle.general.pos, SceneMan.SceneWrapsX).Y;
			vehicle.general.resetDistanceFallenForGround = false;
		else
			vehicle.general.distanceFallen = 0;
		end
	else
		if (vehicle.general.resetDistanceFallenForGround == false) then
			vehicle.general.resetDistanceFallenForGround = true;
		else
			vehicle.general.distanceFallen = 0;
		end
	end
	
end

function VehicleFramework.updateThrottle(vehicle)
	local isMovingLeft, isMovingRight = vehicle.general.controller:IsState(Controller.MOVE_LEFT), vehicle.general.controller:IsState(Controller.MOVE_RIGHT);
	vehicle.general.isDriving = isMovingLeft or isMovingRight;
	vehicle.general.movingOppositeToThrottle = false;
	
	if (vehicle.general.isDriving) then
		if (isMovingLeft) then
			vehicle.general.movingOppositeToThrottle = vehicle.general.throttle < 0;
			vehicle.general.throttle = math.min(vehicle.general.throttle + vehicle.general.acceleration, vehicle.general.maxThrottle);
		elseif (isMovingRight) then
			vehicle.general.movingOppositeToThrottle = vehicle.general.throttle > 0;
			vehicle.general.throttle = math.max(vehicle.general.throttle - vehicle.general.acceleration, -vehicle.general.maxThrottle);
		end
	else
		if (math.abs(vehicle.general.throttle) < vehicle.general.acceleration * 20) then
			vehicle.general.isStronglyDecelerating = true;
			vehicle.general.throttle = vehicle.general.throttle * (1 - vehicle.general.deceleration * 2);
		else
			vehicle.general.isStronglyDecelerating = false;
			vehicle.general.throttle = vehicle.general.throttle * (1 - vehicle.general.deceleration);
		end
		if (math.abs(vehicle.general.throttle) < vehicle.general.acceleration * 2) then
			vehicle.general.throttle = 0;
		end
	end
	vehicle.general.throttle = math.min(vehicle.general.throttle, vehicle.general.maxThrottle);
end

function VehicleFramework.updateWheels(vehicle)
	for i, wheelObject in ipairs(vehicle.wheel.objects) do
		wheelObject.AngularVel = vehicle.general.throttle;
		
		--At some point rot angle can go too high, reset it if it's past 360 for safety
		if (wheelObject.RotAngle > math.pi*2) then
			wheelObject.RotAngle = wheelObject.RotAngle - math.pi*2;
		elseif (wheelObject.RotAngle < -math.pi*2) then
			wheelObject.RotAngle = wheelObject.RotAngle + math.pi*2;
		end
	end
end

function VehicleFramework.updateSprings(vehicle)
	local wheelObject, forceTerrainCheckForWheels;
	for i, spring in ipairs(vehicle.suspension.springs) do
		wheelObject = vehicle.wheel.objects[i];
		if (spring ~= nil) then
			vehicle.suspension.springs[i] = SpringFramework.update(spring);
			spring = vehicle.suspension.springs[i];
			
			if (vehicle.general.forceWheelHorizontalLocking == true) then
				local wheelDeviation = SceneMan:ShortestDistance(spring.targetPos[1], wheelObject.Pos, SceneMan.SceneWrapsX):RadRotate(-spring.rotAngle);
				wheelObject.Pos = spring.targetPos[1] + Vector(wheelDeviation.X, 0):RadRotate(spring.rotAngle);
			end
		end
		if (spring ~= nil and spring.actionsPerformed ~= nil) then
			if (not spring.actionsPerformed[SpringFramework.SpringActions.APPLY_FORCES]) then
				wheelObject:MoveOutOfTerrain(6); --TODO Consider doing this all the time
				
				if (vehicle.general.maxErasableTerrainStrength > 0 and vehicle.general.vel.Magnitude < vehicle.general.maxSpeed * 0.25 and math.abs(vehicle.general.throttle) > vehicle.general.maxThrottle * 0.75 and math.abs(wheelObject.AngularVel) > vehicle.general.maxThrottle * 0.5) then
					forceTerrainCheckForWheels = true;
				end
			end
		end
	end
	
	if (forceTerrainCheckForWheels) then
		VehicleFramework.updateTerrainBelowWheels(vehicle, true);
		for wheelIndex, wheelObject in ipairs(vehicle.wheel.objects) do
			if (SceneMan:GetMaterialFromID(vehicle.wheel.terrainBelowWheels[wheelIndex]).Strength <= vehicle.general.maxErasableTerrainStrength) then
				wheelObject:EraseFromTerrain();
			end
		end
	end
end

function VehicleFramework.updateTerrainBelowWheels(vehicle, forceUpdate)
	if (forceUpdate == true or vehicle.general.checkTerrainBelowWheels == true or vehicle.wheel.checkTerrainBelowWheelsTimer:IsPastSimMS(vehicle.general.checkTerrainBelowWheels)) then
		for i, wheelObject in ipairs(vehicle.wheel.objects) do
			vehicle.wheel.terrainBelowWheels[i] = SceneMan:GetTerrMatter(wheelObject.Pos + Vector(0, vehicle.wheel.size[i] * 0.55):RadRotate(vehicle.self.RotAngle));
		end
		vehicle.wheel.checkTerrainBelowWheelsTimer:Reset();
	end
end

function VehicleFramework.updateTensioners(self, vehicle)
	if (vehicle.tensioner ~= nil) then
		for i, tensionerObject in ipairs(vehicle.tensioner.objects) do
			--tensionerObject.AngularVel = vehicle.wheel.objects[1].AngularVel;
			tensionerObject.RotAngle = vehicle.wheel.objects[1].RotAngle;
			tensionerObject.Pos = vehicle.general.pos + Vector(vehicle.tensioner.unrotatedOffsets[i].X, vehicle.tensioner.unrotatedOffsets[i].Y):RadRotate(self.RotAngle);
			tensionerObject.Vel = self.Vel;
		end
	end
end

function VehicleFramework.updateTrack(self, vehicle)
	if (vehicle.track ~= nil) then
		--VehicleFramework.validateTrackIntegrity(vehicle);
		
		local prevTrackObject, nextTrackObject, distanceBetweenPrevAndNext;
		local currentInflectionNumber = 1;
		local currentInflection = vehicle.track.inflection[currentInflectionNumber];
		for i, trackObject in ipairs(vehicle.track.objects) do
			prevTrackObject = vehicle.track.objects[(i == 1 and #vehicle.track.objects or i - 1)];
			nextTrackObject = vehicle.track.objects[(i == #vehicle.track.objects and 1 or i + 1)];
			distanceBetweenPrevAndNext = SceneMan:ShortestDistance(prevTrackObject.Pos, nextTrackObject.Pos, SceneMan.SceneWrapsX);
			
			if (i == vehicle.track.trackStarts[currentInflectionNumber]) then
				trackObject.Pos = currentInflection.object.Pos + (vehicle.track.unrotatedOffsets[i] - currentInflection.point):RadRotate(self.RotAngle);
			elseif (i == vehicle.track.trackEnds[currentInflectionNumber]) then
				currentInflectionNumber = currentInflectionNumber == #vehicle.track.inflection and 1 or currentInflectionNumber + 1;
				currentInflection = vehicle.track.inflection[currentInflectionNumber];
				
				trackObject.Pos = currentInflection.object.Pos + (vehicle.track.unrotatedOffsets[i] - currentInflection.point):RadRotate(self.RotAngle);
			else
				if (vehicle.track.skippedEnds[i] == true and i == vehicle.track.trackEnds[currentInflectionNumber] - 1) then
					trackObject.Pos = prevTrackObject.Pos + SceneMan:ShortestDistance(prevTrackObject.Pos, vehicle.general.pos + Vector(currentInflection.next.trackStart.X, currentInflection.next.trackStart.Y):RadRotate(self.RotAngle), SceneMan.SceneWrapsX) * 0.5;
				else
					trackObject.Pos = prevTrackObject.Pos + distanceBetweenPrevAndNext * 0.5;
				end
				
				
			end
			
			
			local angleOffset = SceneMan:ShortestDistance(prevTrackObject.Pos, nextTrackObject.Pos, SceneMan.SceneWrapsX).AbsRadAngle - self.RotAngle - vehicle.track.directions[i];
			--local angleOffset = ((distanceBetweenPrevAndNext.AbsRadAngle + math.pi * 2)%math.pi) - self.RotAngle - vehicle.track.directions[i];
			local clampedAngle = Clamp(angleOffset, -vehicle.track.maxRotationDeviation, vehicle.track.maxRotationDeviation);
			
			--if (i == 8) then
			--	print("i: "..tostring(i)..", angleBetweenPrevAndNext: "..tostring((distanceBetweenPrevAndNext.AbsRadAngle + math.pi * 2)%math.pi)..", angleOffset: "..tostring(angleOffset)..", angleLimits: "..tostring(vehicle.track.maxRotationDeviation)..", clampedAngle: "..tostring(clampedAngle));
			--end
			
			trackObject.RotAngle = self.RotAngle + vehicle.track.directions[i] + clampedAngle;
			
			trackObject.Vel = self.Vel;
			trackObject:ClearForces();
		end
	end
end

function VehicleFramework.validateTrackIntegrity(vehicle)
	for _, trackTable in pairs(vehicle.track) do
		if (type(trackTable) == "table") then
			for _, trackObject in ipairs(trackTable) do
				if MovableMan:ValidMO(trackObject) then
					trackObject.ToDelete = true;
				end
			end
		end
	end
end

function VehicleFramework.updateChassis(self, vehicle)
	--Correct rotangle based either on the direction between wheels or, if one outer wheel is in the air but the other isn't, the direction that rotates the tank to be on the ground
	local desiredRotAngle;
	if (vehicle.general.halfOrMoreInAir and vehicle.wheel.isInAir[1] and not vehicle.wheel.isInAir[vehicle.wheel.count]) then
		desiredRotAngle = self.RotAngle + 1;
	elseif (vehicle.general.halfOrMoreInAir and vehicle.wheel.isInAir[vehicle.wheel.count] and not vehicle.wheel.isInAir[1]) then
		desiredRotAngle = self.RotAngle - 1;
	else
		desiredRotAngle = SceneMan:ShortestDistance(vehicle.wheel.objects[vehicle.chassis.rotationAffectingWheels[1]].Pos - Vector(0, vehicle.suspension.length[vehicle.chassis.rotationAffectingWheels[1]].normal):RadRotate(self.RotAngle), vehicle.wheel.objects[vehicle.chassis.rotationAffectingWheels[2]].Pos - Vector(0, vehicle.suspension.length[vehicle.chassis.rotationAffectingWheels[2]].normal):RadRotate(self.RotAngle), SceneMan.SceneWrapsX).AbsRadAngle;
	end
	local rotAngleCorrectionRateToUse = vehicle.general.isInAir and vehicle.chassis.rotAngleCorrectionRateInAir or vehicle.chassis.rotAngleCorrectionRate;
	if (self.RotAngle < desiredRotAngle - rotAngleCorrectionRateToUse * 1.1) then
		self.RotAngle = self.RotAngle + rotAngleCorrectionRateToUse;
	elseif (self.RotAngle > desiredRotAngle + rotAngleCorrectionRateToUse * 1.1) then
		self.RotAngle = self.RotAngle - rotAngleCorrectionRateToUse;
	else
		self.RotAngle = desiredRotAngle;
	end
	
	if (not vehicle.general.isInAir) then
		self:MoveOutOfTerrain(6);
		self.AngularVel = self.AngularVel * 0.5;
		
		if (vehicle.general.vel.Magnitude > vehicle.general.maxSpeed) then
			self.Vel = Vector(vehicle.general.vel.X, vehicle.general.vel.Y):SetMagnitude(vehicle.general.maxSpeed);
		else
			if (not vehicle.general.isDriving) then
				self.Vel = self.Vel * (1 - vehicle.general.deceleration * (vehicle.general.isStronglyDecelerating and 2 or 1));
		
				if (vehicle.general.throttle == 0) then
					if (self.Vel.Magnitude < vehicle.general.acceleration) then
						self.Vel = Vector();
					end
					
					if (not vehicle.general.allowSlidingWhileStopped and self.Vel.Magnitude < 5 and math.abs(self.RotAngle) > (15 * math.pi/180)) then
						self.Vel = Vector();
						self.Pos = vehicle.previous.pos;
					end
				end
			else
				if (vehicle.general.movingOppositeToThrottle) then
					self.Vel = self.Vel * (1 - vehicle.general.acceleration * 0.1);
				end
			end
		end
	end
end

function VehicleFramework.updateEvents(vehicle)
	local eventFired, callbackFunctionArguments;
	
	for eventType, callbacks in pairs(vehicle.events) do
		eventFired = false;
		callbackFunctionArguments = {};
		
		if (callbacks ~= nil and #callbacks > 0) then
			if (eventType == VehicleFramework.EventType.IS_DRIVING) then
				if (vehicle.general.isDriving) then
					eventFired = true;
					table.insert(callbackFunctionArguments, vehicle.general.throttle);
					table.insert(callbackFunctionArguments, vehicle.general.maxThrottle);
				end
			elseif (eventType == VehicleFramework.EventType.NOT_DRIVING) then
				if (not vehicle.general.isDriving) then
					eventFired = true;
					table.insert(callbackFunctionArguments, vehicle.general.throttle);
					table.insert(callbackFunctionArguments, vehicle.general.maxThrottle);
				end
			elseif (eventType == VehicleFramework.EventType.CHANGED_DIRECTION) then
				if (vehicle.self.HFlipped ~= vehicle.previous.hFlipped) then
					eventFired = true;
					table.insert(callbackFunctionArguments, vehicle.general.throttle);
					table.insert(callbackFunctionArguments, vehicle.general.maxThrottle);
					table.insert(callbackFunctionArguments, vehicle.wheel.terrainBelowWheels)
				end
			elseif (eventType == VehicleFramework.EventType.IS_STUCK) then
				error("Vehicle EventType IS_STUCK is not yet supported, please contact Gacyr if you need it");
			elseif (eventType == VehicleFramework.EventType.LANDED_ON_GROUND) then
				if (not vehicle.general.isInAir and vehicle.general.distanceFallen > 0) then
					eventFired = true;
					table.insert(callbackFunctionArguments, vehicle.general.distanceFallen);
				end
			elseif (eventType == VehicleFramework.EventType.FIRED_WEAPON) then
				if (vehicle.general.controller:IsState(Controller.WEAPON_FIRE)) then --TODO this should only trigger on each separate activation, i.e. using HDFirearm:IsActivated() and/or HDFirearm.FiredFrame
					eventFired = true;
				end
			elseif (eventType == VehicleFramework.EventType.SUSPENSION_CHANGED_LENGTH) then
				local suspensionLengthChanges, suspensionLengthsIncreasedOrDecreased, wheelsInAir, numberOfLengthsChanged = {}, {}, {}, 0;
				local lengthChange;
				
				for springIndex, spring in ipairs(vehicle.suspension.springs) do
					lengthChange = math.abs(spring.unrotatedDistances[2].rest.Magnitude - vehicle.previous.springDistanceFromRest[springIndex].Magnitude);
					if (lengthChange >= 1) then
						suspensionLengthChanges[springIndex] = lengthChange;
						suspensionLengthsIncreasedOrDecreased[springIndex] = spring.unrotatedDistances[2].rest.Magnitude > vehicle.previous.springDistanceFromRest[springIndex].Magnitude;
						wheelsInAir[springIndex] = vehicle.wheel.isInAir[springIndex];
						numberOfLengthsChanged = numberOfLengthsChanged + 1;
					end
				end
				
				if (numberOfLengthsChanged > 0) then
					eventFired = true;
					table.insert(callbackFunctionArguments, suspensionLengthChanges);
					table.insert(callbackFunctionArguments, suspensionLengthsIncreasedOrDecreased);
					table.insert(callbackFunctionArguments, wheelsInAir);
					table.insert(callbackFunctionArguments, numberOfLengthsChanged);
				end
			elseif (eventType == VehicleFramework.EventType.SUSPENSION_REACHED_LIMIT) then
				local reachedMinLimit, reachedMaxLimit = {}, {};
				
				for springIndex, spring in ipairs(vehicle.suspension.springs) do
					if (spring.unrotatedDistances[2].min.X <= -spring.minimumValuesForActions[SpringFramework.SpringActions.OUTSIDE_OF_CONFINES]) then
						table.insert(reachedMinLimit, springIndex);
					elseif (spring.unrotatedDistances[2].max.X >= spring.minimumValuesForActions[SpringFramework.SpringActions.OUTSIDE_OF_CONFINES]) then
						table.insert(reachedMaxLimit, springIndex);
					end
				end
				
				if (#reachedMinLimit > 0 or #reachedMaxLimit > 0) then
					eventFired = true;
					table.insert(callbackFunctionArguments, reachedMinLimit);
					table.insert(callbackFunctionArguments, reachedMaxLimit);
				end
			else
				error("Callback table with "..tostring(#callbacks).." elements used invalid event type "..tostring(eventType)..". Please check the Vehicle Configuration Documentation.");
			end
		
			if (eventFired) then
				for _, callbackFunction in ipairs(callbacks) do
					callbackFunction(vehicle, unpack(callbackFunctionArguments));
				end
			end
		end
	end
end

function VehicleFramework.updateVisuals(self, vehicle)
	VehicleFramework.updateSuspensionVisuals(self, vehicle);
end

function VehicleFramework.updateSuspensionVisuals(self, vehicle)
	if (vehicle.suspension.visualsType ~= VehicleFramework.SuspensionVisualsType.NONE) then
		for i, spring in ipairs(vehicle.suspension.springs) do
			vehicle.suspension.offsets.main[i] = spring.targetPos[1];
			if (i ~= vehicle.wheel.count) then
				vehicle.suspension.offsets.midPoint[i] = vehicle.suspension.offsets.main[i] + Vector(vehicle.wheel.spacing * 0.5, 0):RadRotate(self.RotAngle);
			end
		end

		if (vehicle.suspension.visualsType == VehicleFramework.SuspensionVisualsType.DRAWN) then
			for i, wheelObject in ipairs(vehicle.wheel.objects) do
				VehicleFramework.Util.drawArrow(vehicle.suspension.offsets.main[i], Vector(wheelObject.Pos.X, wheelObject.Pos.Y), self.RotAngle, vehicle.suspension.visualsConfig.widths[i], vehicle.suspension.visualsConfig.colourIndex);
				if (i ~= 1) then
					VehicleFramework.Util.drawArrow(vehicle.suspension.offsets.midPoint[i - 1], Vector(wheelObject.Pos.X, wheelObject.Pos.Y), self.RotAngle, vehicle.suspension.visualsConfig.widths[i], vehicle.suspension.visualsConfig.colourIndex);
				end
				if (i ~= vehicle.wheel.count) then
					VehicleFramework.Util.drawArrow(vehicle.suspension.offsets.midPoint[i], wheelObject.Pos, self.RotAngle, vehicle.suspension.visualsConfig.widths[i], vehicle.suspension.visualsConfig.colourIndex);
				end
			end
		elseif (vehicle.suspension.visualsType == VehicleFramework.SuspensionVisualsType.SPRITE) then
			--VehicleFramework.updateSpriteSuspension(self, vehicle);
		end
	end
end

--[[function VehicleFramework.updateDrawnSuspension(self, vehicle)
end

function VehicleFramework.updateSpriteSuspension(self, vehicle)
end--]]

--[[
	self.CenterPos = self.Pos + self:RotateOffset(Vector(0, -5))
	
	--Wheel 1 (right when not flipped)
	self.Suspension[2].Pos = (self.Wheels[1].Pos + RightPos)/2
	self.Suspension[2].RotAngle = (self.Wheels[1].Pos - RightPos).AbsRadAngle + 1.57
	
	self.Suspension[4].Pos = (self.Wheels[1].Pos + self.CenterPos)/2
	self.Suspension[4].RotAngle = (self.Wheels[1].Pos - self.CenterPos).AbsRadAngle + 1.57
	
	
	--Wheel 2 (middle)
	self.Suspension[1].Pos = (self.Wheels[2].Pos + self.CenterPos)/2
	self.Suspension[1].RotAngle = (self.Wheels[2].Pos - self.CenterPos).AbsRadAngle + 1.57
	
	self.Suspension[6].Pos = (self.Wheels[2].Pos + RightPos)/2
	self.Suspension[6].RotAngle = (self.Wheels[2].Pos - RightPos).AbsRadAngle + 1.57
	
	self.Suspension[7].Pos = (self.Wheels[2].Pos + LeftPos)/2
	self.Suspension[7].RotAngle = (self.Wheels[2].Pos - LeftPos).AbsRadAngle + 1.57
	
	--Wheel 3 (left when not flipped)
	self.Suspension[3].Pos = (self.Wheels[3].Pos + LeftPos)/2
	self.Suspension[3].RotAngle = (self.Wheels[3].Pos - LeftPos).AbsRadAngle + 1.57
	
	self.Suspension[5].Pos = (self.Wheels[3].Pos + self.CenterPos)/2
	self.Suspension[5].RotAngle = (self.Wheels[3].Pos - self.CenterPos).AbsRadAngle + 1.57
	--]]
	

	-- Update suspension
	--[[
	self.CenterPos = self.Pos + self:RotateOffset(Vector(0, -5))
	
	self.Suspension[1].Pos = (self.Wheels[2].Pos + self.CenterPos)/2
	self.Suspension[1].RotAngle = (self.Wheels[2].Pos - self.CenterPos).AbsRadAngle + 1.57
	
	self.Suspension[2].Pos = (self.Wheels[1].Pos + RightPos)/2
	self.Suspension[2].RotAngle = (self.Wheels[1].Pos - RightPos).AbsRadAngle + 1.57
	
	self.Suspension[3].Pos = (self.Wheels[3].Pos + LeftPos)/2
	self.Suspension[3].RotAngle = (self.Wheels[3].Pos - LeftPos).AbsRadAngle + 1.57
	
	self.Suspension[4].Pos = (self.Wheels[1].Pos + self.CenterPos)/2
	self.Suspension[4].RotAngle = (self.Wheels[1].Pos - self.CenterPos).AbsRadAngle + 1.57
	
	self.Suspension[5].Pos = (self.Wheels[3].Pos + self.CenterPos)/2
	self.Suspension[5].RotAngle = (self.Wheels[3].Pos - self.CenterPos).AbsRadAngle + 1.57
	
	self.Suspension[6].Pos = (self.Wheels[2].Pos + RightPos)/2
	self.Suspension[6].RotAngle = (self.Wheels[2].Pos - RightPos).AbsRadAngle + 1.57
	
	self.Suspension[7].Pos = (self.Wheels[2].Pos + LeftPos)/2
	self.Suspension[7].RotAngle = (self.Wheels[2].Pos - LeftPos).AbsRadAngle + 1.57
	--]]

function VehicleFramework.updatePreviousValues(vehicle)
	vehicle.previous.pos:SetXY(vehicle.general.pos.X, vehicle.general.pos.Y);
	vehicle.previous.vel:SetXY(vehicle.general.vel.X, vehicle.general.vel.Y);
	vehicle.previous.hFlipped = vehicle.self.HFlipped;
	for springIndex, spring in ipairs(vehicle.suspension.springs) do
		vehicle.previous.springDistanceFromRest[springIndex]:SetXY(spring.unrotatedDistances[2].rest.X, spring.unrotatedDistances[2].rest.Y);
	end
end

-------------------
--AUDIO FUNCTIONS--
-------------------
VehicleFramework.Audio = {};
function VehicleFramework.Audio:______________________() end; --This is just a spacer for the notepad++ function list

VehicleFramework.Audio.StateType = {ANY = 1, IS_PLAYING_SOUND = 2, NOT_PLAYING_SOUND = 3, HAS_FINISHED_PLAYING_SOUND = 4, INCREMENTED_STAGE_IS_PLAYING_SOUND = 5};
VehicleFramework.Audio.TriggerType = VehicleFramework.EventType; --This will need to remove any events which aren't supported by audio, or be written manually
VehicleFramework.Audio.ActionType = {ADVANCE_STAGE = 1, PLAY_SOUND = 2, PLAY_SOUND_AND_ADVANCE_STAGE = 3, STOP_SOUND = 4, STOP_SOUND_AND_ADVANCE_STAGE = 5, STOP_INCREMENTED_STAGE_SOUND = 6};
VehicleFramework.Audio.AdvanceStageActionTypes = table.listToSet({VehicleFramework.Audio.ActionType.ADVANCE_STAGE, VehicleFramework.Audio.ActionType.PLAY_SOUND_AND_ADVANCE_STAGE, VehicleFramework.Audio.ActionType.STOP_SOUND_AND_ADVANCE_STAGE});
VehicleFramework.Audio.PlaySoundActionTypes = table.listToSet({VehicleFramework.Audio.ActionType.PLAY_SOUND, VehicleFramework.Audio.ActionType.PLAY_SOUND_AND_ADVANCE_STAGE});
VehicleFramework.Audio.StopSoundActionTypes = table.listToSet({VehicleFramework.Audio.ActionType.STOP_SOUND, VehicleFramework.Audio.ActionType.STOP_SOUND_AND_ADVANCE_STAGE, VehicleFramework.Audio.ActionType.STOP_INCREMENTED_STAGE_SOUND});

VehicleFramework.Audio.PossibleFileEndings = {"wav", "ogg", "mp3"};

function VehicleFramework.Audio.doAutoGeneration(vehicle)
	if (vehicle.audio[VehicleFramework.AUTO_GENERATE] == true or type(vehicle.audio[VehicleFramework.AUTO_GENERATE]) == "table") then
		if (vehicle.audio[VehicleFramework.AUTO_GENERATE] == true) then
			vehicle.audio[VehicleFramework.AUTO_GENERATE] = {};
		end
		
		vehicle.audio[VehicleFramework.AUTO_GENERATE].RTE = vehicle.audio[VehicleFramework.AUTO_GENERATE].RTE or vehicle.general.RTE;
		local possibleAudioDirectories = {vehicle.audio[VehicleFramework.AUTO_GENERATE].soundFolderName};
		possibleAudioDirectories = next(possibleAudioDirectories) == nil and {"Sound", "sound", "Sounds", "sounds", "Audio", "audio"} or possibleAudioDirectories;
		local possibleAudioFileEndings = {"wav", "ogg", "mp3"};
		
		
		local defaultTriggerValueTable = {
			[VehicleFramework.Audio.TriggerType.STARTED_MOVING] = {}
		};
		local defaultLoopChoicesTable = {};
		local defaultPlayAllChoicesTable = {};
		local defaultOverwriteOnTriggerRepeatTable = {};
		
		local autoGeneratedAudioFilenames = {};
		
		local autoGeneratedAudioChoiceSuffixes = {"", "Light", "Medium", "Heavy"};
		local autoGeneratedLoopOptions = {""}
		
		for triggerNameKey, triggerType in pairs(VehicleFramework.Audio.TriggerType) do
			vehicle.audio[VehicleFramework.AUTO_GENERATE][triggerType] = vehicle.audio[VehicleFramework.AUTO_GENERATE][triggerType] == nil and true or vehicle.audio[VehicleFramework.AUTO_GENERATE][triggerType];
			autoGeneratedAudioFilenames[triggerType] = triggerNameKey:sub(1, 1)..triggerNameKey:sub(2):lower():gsub("_.", function(underscoreAndLetter) return underscoreAndLetter:sub(2):upper(); end); --Get the trigger name converted to PascalCase
		end
		
		local fileString, validFilePaths, audioTableEntry, choiceTables;
		
		for eventType, doAutoGeneration in ipairs(vehicle.audio[VehicleFramework.AUTO_GENERATE]) do
			if (doAutoGeneration == true) then
				validFilePaths = {};
				for _, soundDirectory in ipairs(possibleAudioDirectories) do
					fileString = vehicle.audio[VehicleFramework.AUTO_GENERATE].RTE.."/"..soundDirectory.."/"..autoGeneratedAudioFilenames[eventType];
					print("filestring is "..fileString);
					
					for choiceIndex, choiceSuffix in ipairs(autoGeneratedAudioChoiceSuffixes) do
						for ___, fileEnding in ipairs(possibleAudioFileEndings) do
							if (LuaMan:FileOpen(fileString..choiceSuffix..fileEnding) >= 0 or LuaMan:FileOpen(fileString..choiceSuffix.."1"..fileEnding) >= 0) then
								table.insert(validFilePaths, {filePath = fileString..choiceSuffix, choiceIndex = choiceIndex,  ending = fileEnding});
								break;
							end
						end
						--Break out of this subloop if we've already found a valid file path
						--if (validFilePaths[#validFilePaths].path == fileString..choiceSuffix) then
						--	break;
						--end --Actually I think I want to keep looping to get all valid file paths
					end
				end
				if (#validFilePaths > 0) then
					choiceTables = {};
					
					for _, validFilePathTable in ipairs(validFilePaths) do
						table.insert(choiceTables, {
							filePath = validFilePathTable.path,
							fileEnding = validFilePathTable.ending,
							triggers = defaultTriggerValueTable[eventType][validFilePathTable.choiceIndex]
						});
					end
					--TODO define defaultTriggerValueTable, defaultLoopChoicesTable, defaultPlayAllChoicesTable and defaultOverwriteOnTriggerRepeatTable
					audioTableEntry = {
						loopSound = defaultLoopChoicesTable[eventType],
						triggerType = eventType,
						playAllChoices = defaultPlayAllChoicesTable[eventType],
						overwriteOnTriggerRepeat = defaultOverwriteOnTriggerRepeatTable[eventType],
						choices = choiceTables
					};
					
					table.insert(vehicle.audio, audioTableEntry);
				end
			end
		end
	end
end

function VehicleFramework.Audio.setCustomisationDefaultsAndLimitsAndCheckValidity(vehicle)
	vehicle.audio.allAudioTables = {};
	vehicle.audio.allAudioStageTables = {};

	for _, audioConfigOrStages in ipairs(vehicle.audio) do
		if (audioConfigOrStages.stages ~= nil) then
			table.insert(vehicle.audio.allAudioStageTables, audioConfigOrStages);
			audioConfigOrStages.isStageTable = true;
			audioConfigOrStages.currentStage = 1;
			audioConfigOrStages.stopSoundsFromOtherStages = audioConfigOrStages.stopSoundsFromOtherStages == nil and true or audioConfigOrStages.stopSoundsFromOtherStages;
			for stageNumber, audioConfig in ipairs(audioConfigOrStages.stages) do
				VehicleFramework.Audio.setupAndValidateAndPopulateAudioConfig(vehicle, audioConfig, audioConfigOrStages, stageNumber);
			end
		else
			VehicleFramework.Audio.setupAndValidateAndPopulateAudioConfig(vehicle, audioConfigOrStages);
		end
	end
end

function VehicleFramework.Audio.setupAndValidateAndPopulateAudioConfig(vehicle, audioConfig, parentTable, indexInParent, isAdditionalAction)
	table.insert(vehicle.audio.allAudioTables, audioConfig);
	
	audioConfig.parentTable = parentTable;
	audioConfig.indexInParent = indexInParent;
	if (parentTable) then
		audioConfig.topLevelTable = parentTable.topLevelTable or parentTable;
		audioConfig.topLevelAudioConfig = parentTable.topLevelAudioConfig or (parentTable.isStageTable and audioConfig or parentTable);
	else
		audioConfig.topLevelTable = audioConfig;
		audioConfig.topLevelAudioConfig = audioConfig;
	end
	
	assert(type(audioConfig) == "table", "Audio configuration must be a table, not a "..type(audioConfig)..". Please check the Vehicle Configuration Documentation.");
	
	audioConfig.stateType = audioConfig.stateType or (not isAdditionalAction and VehicleFramework.Audio.StateType.ANY or audioConfig.stateType);
	assert(audioConfig.stateType ~= nil, "Audio configuration additionActions must have a state type set, to avoid mishaps with missing state types. Please check the Vehicle Configuration Documentation.");
	
	assert(type(audioConfig.triggerType) == "number", "Audio configuration triggerType must be a number (preferably using the VehicleFramework.Audio.TriggerType enum), not a "..type(audioConfig.triggerType)..". Please check the Vehicle Configuration Documentation.");

	audioConfig.soundConfig = audioConfig.soundConfig or {};
	
	audioConfig.soundConfig.looped = audioConfig.soundConfig.looped or false;
	
	audioConfig.soundConfig.affectedByPitch = audioConfig.soundConfig.affectedByPitch == nil and true or audioConfig.soundConfig.affectedByPitch;
	
	audioConfig.soundConfig.overwrittenOnRepeat = audioConfig.soundConfig.overwrittenOnRepeat or false;
	
	audioConfig.includeActionDelayTimer = audioConfig.includeActionDelayTimer or false;
	
	audioConfig.forceStopSoundsFromOtherStages = audioConfig.forceStopSoundsFromOtherStages or false;
	
	audioConfig.mainActionType = (audioConfig.mainActionType == nil and not isAdditionalAction) and VehicleFramework.Audio.ActionType.PLAY_SOUND or audioConfig.mainActionType;
	assert(type(audioConfig.mainActionType) == "number", "Audio configuration additionalActions must have mainActionType specified. Please check the Vehicle Configuration Documentation.");
	
	--Handle syntactic sugar of specifying neither main action options nor conditions, wherein conditions defaults to true
	if (audioConfig.mainActionOptions == nil and audioConfig.conditions == nil) then
		audioConfig.conditions = true;
	end
	
	audioConfig.mainActionOptions = audioConfig.mainActionOptions or {};
	
	if (audioConfig.topLevelTable.isStageTable) then
		--Handle syntactic sugar of having numberOfStagesToIncrementBy in the main audioConfig
		if (audioConfig.numberOfStagesToIncrementBy) then
			audioConfig.mainActionOptions.numberOfStagesToIncrementBy = audioConfig.numberOfStagesToIncrementBy;
			audioConfig.numberOfStagesToIncrementBy = nil;
		end
		audioConfig.mainActionOptions.numberOfStagesToIncrementBy = audioConfig.mainActionOptions.numberOfStagesToIncrementBy or 1;
		audioConfig.mainActionOptions.numberOfStagesToIncrementBy = Clamp(audioConfig.mainActionOptions.numberOfStagesToIncrementBy, -#audioConfig.topLevelTable.stages, #audioConfig.topLevelTable.stages);
	end
	
	--Handle syntactic sugar of just specifying conditions for non play sound actions by manually moving conditions into mainActionOptions
	if (audioConfig.conditions ~= nil) then
		audioConfig.mainActionOptions.conditions = audioConfig.conditions;
		audioConfig.conditions = nil;
	end
	
	assert(type(audioConfig.mainActionOptions) == "table", "Audio configuration mainActionOptions must be a table, not a "..type(audioConfig.mainActionOptions)..". Please check the Vehicle Configuration Documentation.");
	VehicleFramework.Util.moveEntriesInTableToNumberedSubtableIfNeeded(audioConfig.mainActionOptions, {"performAllOptionsWithSatisfiedConditions", "numberOfStagesToIncrementBy"});
	
	audioConfig.mainActionOptions.performAllOptionsWithSatisfiedConditions = audioConfig.mainActionOptions.performAllOptionsWithSatisfiedConditions or false;
	
	for _, actionOption in ipairs(audioConfig.mainActionOptions) do
		actionOption.stopAdditionalActionsFromBeingPerformed = actionOption.stopAdditionalActionsFromBeingPerformed == nil and true or actionOption.stopAdditionalActionsFromBeingPerformed;
		
		if (audioConfig.mainActionType == VehicleFramework.Audio.ActionType.PLAY_SOUND or audioConfig.mainActionType == VehicleFramework.Audio.ActionType.PLAY_SOUND_AND_ADVANCE_STAGE) then
			actionOption.fileRTE = actionOption.fileRTE or vehicle.general.RTE;
			
			assert(type(actionOption.filePathModifier) == "string", "Audio configuration mainActionOption filePathModifier must be a string, not a "..type(actionOption.filePathModifier)..". Please check the Vehicle Configuration Documentation.");
			
			actionOption.fileEnding, actionOption.fileCount = VehicleFramework.Util.findValidFileEndingAndCountForFilePath(actionOption.fileRTE.."/"..actionOption.filePathModifier, VehicleFramework.Audio.PossibleFileEndings, actionOption.fileEnding, actionOption.fileCount);
			assert(type(actionOption.fileEnding) == "string", "The vehicle framework was unable to determine the correct file ending for your audio file with path "..actionOption.fileRTE.."/"..actionOption.filePathModifier..". It was probably formatted incorrectly, in the wrong folder or had an invalid file ending. Please check the Vehicle Configuration Documentation.");
			assert(type(actionOption.fileCount) == "number", "The vehicle framework was unable to determine the correct file count for your audio file with path "..actionOption.fileRTE.."/"..actionOption.filePathModifier..". It was probably formatted incorrectly, in the wrong folder or had an invalid file ending. Please check the Vehicle Configuration Documentation.");
			
			actionOption.fileTraversalOrder = actionOption.fileTraversalOrder or VehicleFramework.TraversalOrderType.STATELESS_RANDOM;
		end
		
		actionOption.conditions = actionOption.conditions == nil and true or actionOption.conditions;
		assert(type(actionOption.conditions) == "table" or type(actionOption.conditions) == "boolean", "Audio configuration mainActionOption conditions must be either a table or a boolean, not a "..type(actionOption.conditions)..". Please check the Vehicle Configuration Documentation.");
		if (type(actionOption.conditions) == "table") then
			actionOption.conditions.allConditionsRequired = actionOption.conditions.allConditionsRequired == nil and true or actionOption.conditions.allConditionsRequired;
			VehicleFramework.Util.moveEntriesInTableToNumberedSubtableIfNeeded(actionOption.conditions, {"allConditionsRequired"});
			
			for conditionIndex, condition in ipairs(actionOption.conditions) do
				if (type(condition) == "table") then
					if (condition.triggerDelay) ~= nil then
						assert(type(condition.triggerDelay) == "number", "Audio configuration condition triggerDelay must be a number, not a "..type(condition.triggerDelay)..". Please check the Vehicle Configuration Documentation.");

						audioConfig.actionDelayTimer = audioConfig.actionDelayTimer or Timer();
					end
					
					if (condition.operatorType ~= nil or condition.value ~= nil) then
						assert(type(condition.operatorType) == "string", "Audio configuration condition operatorType must be a string (preferably using the VehicleFramework.OperatorType enum), not a "..type(condition.operatorType)..". Please check the Vehicle Configuration Documentation.");
						
						assert(type(condition.value) ~= "nil", "Audio configuration condition value must not be nil. Please check the Vehicle Configuration Documentation.");
						if (condition.operatorType == VehicleFramework.OperatorType.GREATER_THAN or condition.operatorType == VehicleFramework.OperatorType.LESS_THAN or condition.operatorType == VehicleFramework.OperatorType.GREATER_THAN_OR_EQUAL or condition.operatorType == VehicleFramework.OperatorType.LESS_THAN_OR_EQUAL) then
							if (type(condition.value) == "table") then
								for _, value in ipairs(condition.value) do
									assert(type(condition.value) == "number", "Audio configuration condition value table entries must be numbers for operator type "..tostring(condition.operatorType)..", not "..type(condition.value).."s. Please check the Vehicle Configuration Documentation.");
								end
							else
								assert(type(condition.value) == "number", "Audio configuration condition value must be a number for operator type "..tostring(condition.operatorType)..", not a "..type(condition.value)..". Please check the Vehicle Configuration Documentation.");
							end
						end
						
						condition.argumentNumber = condition.argumentNumber or conditionIndex;
					end
				end
			end
		end
		
	end
	
	audioConfig.additionalActions = audioConfig.additionalActions or {};
	assert(type(audioConfig.mainActionOptions) == "table", "Audio configuration additionalActions must be a table, not a "..type(audioConfig.mainActionOptions)..". Please check the Vehicle Configuration Documentation.");
	VehicleFramework.Util.moveEntriesInTableToNumberedSubtableIfNeeded(audioConfig.additionalActions);
	
	
	if (audioConfig.advanceStageOnComplete == nil and audioConfig.topLevelTable.isStageTable and VehicleFramework.Audio.PlaySoundActionTypes[audioConfig.mainActionType]) then
		audioConfig.advanceStageOnComplete = audioConfig.soundConfig.looped == false and true or false; --cases where this don't get set will remain nil, which gets treated as false later
	end
	if (audioConfig.advanceStageOnComplete and audioConfig.mainActionType == VehicleFramework.Audio.ActionType.PLAY_SOUND) then
		audioConfig.advanceStageOnComplete = nil;
		local additionalActionEntry = {
			stateType = VehicleFramework.Audio.StateType.NOT_PLAYING_SOUND,
			triggerType = audioConfig.triggerType,
			mainActionType = VehicleFramework.Audio.ActionType.ADVANCE_STAGE
		};
		
		table.insert(audioConfig.additionalActions, additionalActionEntry);
		if (vehicle.general.showDebug) then
			print("Adding advanceStageOnComplete entry for table with option[1] filePath "..tostring(audioConfig.mainActionOptions[1].filePathModifier));
		end
	end
	
	for additionalActionIndex, additionalActionTable in ipairs(audioConfig.additionalActions) do
		VehicleFramework.Audio.setupAndValidateAndPopulateAudioConfig(vehicle, additionalActionTable, audioConfig, additionalActionIndex, true);
	end
end

function VehicleFramework.Audio.createSoundTablesAndTimersAndEvents(vehicle)
	for _, audioConfig in ipairs(vehicle.audio.allAudioTables) do
		if (VehicleFramework.Audio.PlaySoundActionTypes[audioConfig.mainActionType]) then
			audioConfig.soundObjects = {};
			for optionIndex, optionTable in ipairs(audioConfig.mainActionOptions) do
				audioConfig.soundObjects[optionIndex] = {};
			end
		end
		
		if (audioConfig.includeActionDelayTimer) then
			audioConfig.actionDelayTimer = Timer();
		elseif (type(audioConfig.conditions) == "table") then
			for _, condition in ipairs(audioConfig.conditions) do
				if (condition.triggerDelay ~= nil) then
					audioConfig.actionDelayTimer = Timer();
				end
			end
		end
		
		table.insert(vehicle.events[audioConfig.triggerType], function(vehicle, ...) VehicleFramework.Audio.doActionFromEvent(audioConfig, vehicle, ...) end);
	end
end

function VehicleFramework.Audio.earlyUpdate(vehicle)
	for _, audioConfig in ipairs(vehicle.audio.allAudioTables) do
		audioConfig.eventOccuredThisFrame = false;
	end
end

function VehicleFramework.Audio.update(vehicle)
	for _, audioConfig in ipairs(vehicle.audio.allAudioTables) do
		--Update sound positions
		if (audioConfig.soundObjects ~= nil) then
			local forceStopSounds = audioConfig.topLevelTable.isStageTable and audioConfig.topLevelAudioConfig.indexInParent ~= audioConfig.topLevelTable.currentStage and (audioConfig.topLevelTable.stopSoundsFromOtherStages or audioConfig.topLevelTable.stages[audioConfig.topLevelTable.currentStage].forceStopSoundsFromOtherStages);
			for soundOptionIndex, soundOptionTable in ipairs(audioConfig.soundObjects) do
				for playerNumber, sound in pairs(soundOptionTable) do
					if (sound:IsPlaying()) then
						sound:UpdateDistance(SceneMan:TargetDistanceScalar(vehicle.self.Pos, vehicle.general.playerScreens[playerNumber]));
					elseif (forceStopSounds or not sound:IsPlaying()) then
						if (audioConfig.soundAlreadyPlayed and not audioConfig.topLevelTable.isStageTable) then
							audioConfig.soundAlreadyPlayed = false;
						end
						soundOptionTable[playerNumber] = nil;
					end
				end
			end
		end
		
		--Reset delay timers
		if (audioConfig.eventOccuredThisFrame == false and type(audioConfig.actionDelayTimer) == "userdata") then
			audioConfig.actionDelayTimer:Reset();
		end
	end
end

function VehicleFramework.Audio.doActionFromEvent(audioConfig, vehicle, ...)
	if (VehicleFramework.Audio.checkIfAudioConfigStateAndStageAreCorrect(audioConfig, vehicle)) then
		if (VehicleFramework.Audio.PlaySoundActionTypes[audioConfig.mainActionType]) then
			VehicleFramework.Audio.doPlaySoundActionFromEvent(audioConfig, vehicle, ...);
		elseif (VehicleFramework.Audio.StopSoundActionTypes[audioConfig.mainActionType]) then
			VehicleFramework.Audio.doStopSoundActionFromEvent(audioConfig, vehicle, ...);
		end
		
		if (VehicleFramework.Audio.AdvanceStageActionTypes[audioConfig.mainActionType]) then
			VehicleFramework.Audio.doAdvanceStageActionFromEvent(audioConfig, vehicle, ...);
		end
	end
	audioConfig.eventOccuredThisFrame = true;
end

function VehicleFramework.Audio.checkIfAudioConfigStateAndStageAreCorrect(audioConfig, vehicle)
	if (not audioConfig.topLevelTable.isStageTable or audioConfig.topLevelTable.currentStage == audioConfig.topLevelAudioConfig.indexInParent) then
		if (audioConfig.stateType == VehicleFramework.Audio.StateType.ANY) then
			return true;
		end
		
		local soundObjectsTable = audioConfig.soundObjects or (audioConfig.parentTable ~= nil and audioConfig.parentTable.soundObjects);
		local soundToCheck;
		local soundExistsAndIsPlaying = false;
		
		if (audioConfig.stateType == VehicleFramework.Audio.StateType.INCREMENTED_STAGE_IS_PLAYING_SOUND) then
			assert(audioConfig.topLevelTable.isStageTable, "Tried check stateType INCREMENTED_STAGE_IS_PLAYING_SOUND on an audio configuration that is not set up to support stages, which suggests an error in your overall audio configuration setup. Please see the Vehicle Configuration Documentation.");
			soundObjectsTable = audioConfig.topLevelTable.stages[VehicleFramework.Util.loopedIncrementalClamp(audioConfig.topLevelTable.currentStage + audioConfig.mainActionOptions.numberOfStagesToIncrementBy, 1, #audioConfig.topLevelTable.stages)].soundObjects;
		end
		
		for optionIndex, optionTable in ipairs(audioConfig.mainActionOptions) do
			soundToCheck = soundObjectsTable[optionIndex] ~= nil and soundObjectsTable[optionIndex][vehicle.general.humanPlayers[1]] or nil;
			soundExistsAndIsPlaying = type(soundToCheck) == "userdata" and soundToCheck:IsPlaying();
			
			if (soundExistsAndIsPlaying) then
				break;
			end
		end
		
		if (audioConfig.stateType == VehicleFramework.Audio.StateType.IS_PLAYING_SOUND or audioConfig.stateType == VehicleFramework.Audio.StateType.INCREMENTED_STAGE_IS_PLAYING_SOUND) then
			return soundExistsAndIsPlaying;
		elseif (audioConfig.stateType == VehicleFramework.Audio.StateType.NOT_PLAYING_SOUND) then
			return not soundExistsAndIsPlaying;
		elseif (audioConfig.stateType == VehicleFramework.Audio.StateType.HAS_FINISHED_PLAYING_SOUND) then
			return not soundExistsAndIsPlaying and (audioConfig.soundAlreadyPlayed or (audioConfig.parentTable and audioConfig.parentTable.soundAlreadyPlayed) or false);
		else
			error("Audio config stateType "..tostring(audioConfig.stateType).." does not exist. Please check the Vehicle Configuration Documentation.");
		end
	end
	
	return false;
end
	
function VehicleFramework.Audio.doPlaySoundActionFromEvent(audioConfig, vehicle, ...)
	local soundExistsAndIsPlaying, satisfiedOptions = {}, {};
	local soundObjectsTableToCheck = audioConfig.soundObjects or (audioConfig.parentTable ~= nil and audioConfig.parentTable.soundObjects);
	local soundToCheck, filePath;
	
	--Do not repeat sounds for non-looped sounds. This is needed because events execute sequentially so the sound will keep replying before stage advancement
	if (audioConfig.soundConfig.looped == false and audioConfig.soundAlreadyPlayed == true) then
		return;
	end
	
	for optionIndex, optionTable in ipairs(audioConfig.mainActionOptions) do
		if (next(satisfiedOptions) == nil or audioConfig.mainActionOptions.performAllOptionsWithSatisfiedConditions == true or optionTable.stopAdditionalActionsFromBeingPerformed == false) then
			if (VehicleFramework.Audio.checkIfConditionsAreSatisfied(audioConfig, vehicle, optionTable.conditions, ...)) then
				satisfiedOptions[optionIndex] = optionTable;
			end
		end
		
		soundToCheck = soundObjectsTableToCheck[optionIndex] ~= nil and soundObjectsTableToCheck[optionIndex][vehicle.general.humanPlayers[1]] or nil;
		if (type(soundToCheck) == "userdata" and soundToCheck:IsPlaying()) then
			table.insert(soundExistsAndIsPlaying, optionIndex);
		end
	end
	
	--Play new sounds if there's none or it's set to overwrite
	if (#soundExistsAndIsPlaying == 0 or audioConfig.soundConfig.overwrittenOnRepeat == true) then
		for _, optionIndex in ipairs(soundExistsAndIsPlaying) do
			for _, playerNumber in ipairs(vehicle.general.humanPlayers) do
				soundObjectsTableToCheck[optionIndex][playerNumber]:Stop(playerNumber);
			end
		end
		
		for optionIndex, optionTable in pairs(satisfiedOptions) do
			filePath = optionTable.fileRTE.."/"..optionTable.filePathModifier
				..(optionTable.fileCount > 0 and tostring(VehicleFramework.Util.selectAppropriateNumberForTraversalOrder(optionTable)) or "")
				..optionTable.fileEnding;
			
			for _, playerNumber in ipairs(vehicle.general.humanPlayers) do
				if (vehicle.general.showDebug) then
					print("Playing"..(#soundExistsAndIsPlaying > 0 and audioConfig.soundConfig.overwrittenOnRepeat and " overwriting " or " ").."sound at "..tostring(filePath).." in soundOptionTable "..tostring(audioConfig.soundObjects[optionIndex]));
				end
				
				audioConfig.soundObjects[optionIndex][playerNumber] = AudioMan:PlaySound(filePath,
					SceneMan:TargetDistanceScalar(vehicle.self.Pos, vehicle.general.playerScreens[playerNumber]), --TODO possibly this should be replaced by some sort of calculation to allow overwriting
					audioConfig.soundConfig.looped, audioConfig.soundConfig.affectedByPitch, playerNumber);
			end
			
			if (audioConfig.soundConfig.looped == false) then
				audioConfig.soundAlreadyPlayed = true;
			end
			
			if (audioConfig.mainActionOptions.performAllOptionsWithSatisfiedConditions == false and optionTable.stopAdditionalActionsFromBeingPerformed == true) then
				break;
			end
		end
	end
end

function VehicleFramework.Audio.doStopSoundActionFromEvent(audioConfig, vehicle, ...)
	local audioConfigToStopSoundsFor;
	
	if (audioConfig.mainActionType == VehicleFramework.Audio.ActionType.STOP_INCREMENTED_STAGE_SOUND) then
		assert(audioConfig.topLevelTable.isStageTable, "Tried to trigger a STOP_INCREMENTED_STAGE_SOUND action from an audio configuration that is not set up to support stages, which suggests an error in your overall audio configuration setup. Please see the Vehicle Configuration Documentation.");
		
		audioConfigToStopSoundsFor = audioConfig.topLevelTable.stages[VehicleFramework.Util.loopedIncrementalClamp(audioConfig.topLevelTable.currentStage + audioConfig.mainActionOptions.numberOfStagesToIncrementBy, 1, #audioConfig.topLevelTable.stages)];
		
		assert(VehicleFramework.Audio.PlaySoundActionTypes[audioConfigToStopSoundsFor.mainActionType], "Tried to trigger a STOP_INCREMENTED_STAGE_SOUND action but the audioConfig who's sound should be stopped was not set up to play sounds as its mainActionType was "..tostring(audioConfigToStopSoundsFor.mainActionType)..". Please check the Vehicle Configuration Documentation.");
	else
		audioConfigToStopSoundsFor = audioConfig.soundObjects ~= nil and audioConfig or ((audioConfig.parentTable ~= nil and not audioConfig.parentTable.isStageTable) and audioConfig.parentTable or audioConfig);
	end
	
	for optionIndex, optionTable in ipairs(audioConfig.mainActionOptions) do
		if (VehicleFramework.Audio.checkIfConditionsAreSatisfied(audioConfig, vehicle, optionTable.conditions, ...)) then
			for _, soundObjectSubtable in pairs(audioConfigToStopSoundsFor.soundObjects) do
				for playerNum, soundObject in pairs(soundObjectSubtable) do
					if (type(soundObject) == "userdata") then
						soundObject:Stop(playerNum);
					end
				end
			end
			break;
		end
	end
	
	if (audioConfigToStopSoundsFor.soundAlreadyPlayed) then
		audioConfigToStopSoundsFor.soundAlreadyPlayed = false;
	elseif (audioConfigToStopSoundsFor.parentTable.soundAlreadyPlayed) then
		audioConfigToStopSoundsFor.parentTable.soundAlreadyPlayed = false;
	end
end

function VehicleFramework.Audio.doAdvanceStageActionFromEvent(audioConfig, vehicle, ...)
	assert(audioConfig.topLevelTable.isStageTable, "Tried to trigger an audio advance stage action from an audio configuration with trigger type "..tostring(audioConfig.triggerType).." that is not set up to support stages, which suggests an error in your audio configuration. Please see the Vehicle Configuration Documentation.");
	
	for optionIndex, optionTable in ipairs(audioConfig.mainActionOptions) do
		if (VehicleFramework.Audio.checkIfConditionsAreSatisfied(audioConfig, vehicle, optionTable.conditions, ...)) then
			audioConfig.topLevelTable.currentStage = VehicleFramework.Util.loopedIncrementalClamp(audioConfig.topLevelTable.currentStage + audioConfig.mainActionOptions.numberOfStagesToIncrementBy, 1, #audioConfig.topLevelTable.stages);
			
			if (vehicle.general.showDebug) then
				print("Advance stage to "..tostring(audioConfig.topLevelTable.currentStage).." using an increment of "..tostring(audioConfig.mainActionOptions.numberOfStagesToIncrementBy));
			end
		end
		break;
	end
	
	if (audioConfig.soundAlreadyPlayed) then
		audioConfig.soundAlreadyPlayed = false;
	elseif (audioConfig.parentTable.soundAlreadyPlayed) then
		audioConfig.parentTable.soundAlreadyPlayed = false;
	end
end

function VehicleFramework.Audio.checkIfConditionsAreSatisfied(audioConfig, vehicle, conditions, ...)
	if (type(conditions) == "boolean") then
		return conditions;
	end
	
	local conditionsSatisfied, conditionValueTableSatisfied = true, false;
	
	for _, conditionTableOrFunction in ipairs(conditions) do
		if (type(conditionTableOrFunction) == "function") then
			return conditionTableOrFunction(audioConfig, vehicle, ...);
		end
		
		conditionsSatisfied = conditionTableOrFunction.triggerDelay == nil or audioConfig.actionDelayTimer == nil or audioConfig.actionDelayTimer:IsPastSimMS(conditionTableOrFunction.triggerDelay);
		if (conditionsSatisfied == true and conditionTableOrFunction.operatorType ~= nil and conditionTableOrFunction.value ~= nil) then
			if (type(conditionTableOrFunction.value) == "table") then
				for _, value in ipairs(conditionTableOrFunction.value) do
					if (VehicleFramework.Util.externalValueSatisfiesCondition(select(conditionTableOrFunction.argumentNumber, ...), conditionTableOrFunction.operatorType, value)) then
						conditionValueTableSatisfied = true;
						break;
					end
				end
				conditionsSatisfied = conditionsSatisfied and conditionValueTableSatisfied;
			else
				conditionsSatisfied = conditionsSatisfied and VehicleFramework.Util.externalValueSatisfiesCondition(select(conditionTableOrFunction.argumentNumber, ...), conditionTableOrFunction);
			end
		end
		
		--This cleverly breaks out if we are sufficiently satisfied or can never be satisfied
		if ((not conditionsSatisfied and conditions.allConditionsRequired) or (conditionsSatisfied and not conditions.allConditionsRequired)) then
			break;
		end
	end
	
	return conditionsSatisfied;
end

---------------------
--UTILITY FUNCTIONS--
---------------------
VehicleFramework.Util = {};
function VehicleFramework.Util:______________________() end; --This is just a spacer for the notepad++ function list

function VehicleFramework.Util.findValidFileEndingAndCountForFilePath(filePath, possibleFileEndings, fileEnding, fileCount)
	if (fileEnding ~= nil and fileCount ~= nil) then
		return fileEnding, fileCount;
	end
	
	local findCountForFileEnding = function(filePath, fileEnding, fileCount)
		--Return fileCount if the file at filePath + fileCount + fileEnding exists otherwise return nil
		if (fileCount ~= nil) then
			fileIndex = LuaMan:FileOpen(filePath..tostring(fileCount)..fileEnding, "r");
			LuaMan:FileClose(fileIndex);
			if (fileIndex >= 0) then
				return fileCount;
			end
			return nil;
		end
		
		--File is filePath + fileEnding, count is 0
		fileIndex = LuaMan:FileOpen(filePath..fileEnding, "r");
		if (fileIndex >= 0) then
			LuaMan:FileClose(fileIndex);
			return 0;
		end
		
		--Figure out the file count
		fileCount = 0;
		local fileIndex = 0;
		while (fileIndex >= 0) do
			fileCount = fileCount + 1;
			fileIndex = LuaMan:FileOpen(filePath..tostring(fileCount)..fileEnding, "r");
			LuaMan:FileClose(fileIndex);
		end
		
		if (fileCount > 1) then
			return fileCount - 1; --Need to subtract 1 to get the actual count
		end
		
		return nil;
	end
	
	--Try to get the count for the given file ending if it's not nil
	if (fileEnding ~= nil) then
		return fileEnding, findCountForFileEnding(filePath, fileEnding, fileCount);
	end

	for _, possibleFileEnding in pairs(possibleFileEndings) do
		possibleFileEnding = possibleFileEnding:find("%.") == nil and "."..possibleFileEnding or possibleFileEnding;
		fileCount = findCountForFileEnding(filePath, possibleFileEnding, fileCount);
		
		if (fileCount ~= nil) then
			return possibleFileEnding, fileCount;
		end
	end
	
	return nil, nil;
end

function VehicleFramework.Util.moveEntriesInTableToNumberedSubtableIfNeeded(containingTable, ignoredKeys)
	if (next(containingTable) ~= nil and containingTable[1] == nil) then
		containingTable[1] = {};
		ignoredKeys = ignoredKeys or {};
		
		local keyShouldBeIgnored;
		for key, value in pairs(containingTable) do
			if (type(key) ~= "number") then
				keyShouldBeIgnored = false;
				for _, ignoredKey in ipairs(ignoredKeys) do
					if (key == ignoredKey) then
						keyShouldBeIgnored = true;
						break;
					end
				end
				
				if (not keyShouldBeIgnored) then
					containingTable[1][key] = value;
					containingTable[key] = nil;
				end
			end
		end
	end
end

function VehicleFramework.Util.externalValueSatisfiesCondition(externalValue, conditionOperatorType, conditionCheckValue)
	--Support a trigger table with keys type and value or an array of those
	if (type(conditionOperatorType) == "table") then
		conditionCheckValue = conditionOperatorType.value;
		conditionOperatorType = conditionOperatorType.operatorType;
	end
	
	if (conditionOperatorType == VehicleFramework.OperatorType.EQUAL) then
		return externalValue == conditionCheckValue;
	elseif (conditionOperatorType == VehicleFramework.OperatorType.NOT_EQUAL) then
		return externalValue ~= conditionCheckValue;
	elseif (conditionOperatorType == VehicleFramework.OperatorType.LESS_THAN) then
		return externalValue < conditionCheckValue;
	elseif (conditionOperatorType == VehicleFramework.OperatorType.GREATER_THAN) then
		return externalValue > conditionCheckValue;
	elseif (conditionOperatorType == VehicleFramework.OperatorType.LESS_THAN_OR_EQUAL) then
		return externalValue <= conditionCheckValue;
	elseif (conditionOperatorType == VehicleFramework.OperatorType.GREATER_THAN_OR_EQUAL) then
		return externalValue >= conditionCheckValue;
	end
	error("Invalid trigger type "..tostring(conditionOperatorType)..". Please check the Vehicle Configuration Documentation.");
end

function VehicleFramework.Util.selectAppropriateNumberForTraversalOrder(traversalTable)
	traversalTable.numberOfElements = traversalTable.count or traversalTable.fileCount or traversalTable.numberOfElements; --Force this to match count/fileCount in case some external party updates that instead
	traversalTable.traversalOrder = traversalTable.fileTraversalOrder or traversalTable.traversalOrder; --Force this to match fileTraversalOrder in case some external party updates that instead
	traversalTable.fullyTraversed = false;
	
	if (traversalTable.traversalOrder == VehicleFramework.TraversalOrderType.FORWARDS) then
		traversalTable.previousIndex = traversalTable.previousIndex == nil and 1 or traversalTable.previousIndex%traversalTable.numberOfElements + 1;
		traversalTable.fullyTraversed = traversalTable.previousIndex == traversalTable.numberOfElements;
		return traversalTable.previousIndex;
	elseif (traversalTable.traversalOrder == VehicleFramework.TraversalOrderType.BACKWARDS) then
		traversalTable.previousIndex = traversalTable.previousIndex == nil and traversalTable.numberOfElements or traversalTable.previousIndex - 1;
		traversalTable.previousIndex = traversalTable.previousIndex == 0 and traversalTable.numberOfElements or traversalTable.previousIndex;
		traversalTable.fullyTraversed = traversalTable.previousIndex == 1;
		return traversalTable.previousIndex;
	elseif (traversalTable.traversalOrder == VehicleFramework.TraversalOrderType.RANDOM) then
		traversalTable.previouslyTraversedElements = traversalTable.previouslyTraversedElements or {};
		traversalTable.previouslyTraversedElements = #traversalTable.previouslyTraversedElements == traversalTable.numberOfElements and {} or traversalTable.previouslyTraversedElements;
		local untraversedElements = {};
		for i = 1, traversalTable.numberOfElements do
			if (traversalTable.previouslyTraversedElements[i] == nil) then
				table.insert(untraversedElements, i);
			end
		end
		local selection = untraversedElements[math.random(1, #untraversedElements)];
		table.insert(traversalTable.previouslyTraversedElements, selection);
		traversalTable.fullyTraversed = #traversalTable.previouslyTraversedElements == traversalTable.numberOfElements;
		return selection;
	elseif (traversalTable.traversalOrder == VehicleFramework.TraversalOrderType.STATELESS_RANDOM) then
		return math.random(1, traversalTable.numberOfElements);
	else
		error("Invalid traversal order type "..tostring(traversalTable.traversalOrder)..". Please check the Vehicle Configuration Documentation.");
	end
end

function VehicleFramework.Util.loopedIncrementalClamp(value, minimumValue, maximumValue)
	while (value > maximumValue) do
		value = minimumValue + value - maximumValue - 1;
	end
	while (value < minimumValue) do
		value = maximumValue + value - minimumValue + 1;
	end
	return value;
end

function VehicleFramework.Util.drawArrow(startPos, endPos, rotAngle, width, colourIndex)
	local distance = SceneMan:ShortestDistance(startPos, endPos, SceneMan.SceneWrapsX);
	endPos = startPos + distance;
	local lineAngle = (distance.AbsDegAngle + 360)%360;
	local isHorizontal = (lineAngle >= 315 or lineAngle <= 45) or (lineAngle >= 135 and lineAngle <= 225);
	local isVertical = (lineAngle >= 45 and lineAngle <= 135) or (lineAngle >= 225 and lineAngle <= 315);
	local evenLineCount = width % 2 == 0;
	local midCount = math.ceil(width * 0.5);
	local rotatedStartPos = Vector(startPos.X, startPos.Y):RadRotate(-rotAngle);

	for i = 1, width + (evenLineCount and 1 or 0) do
		if (i == midCount) then
			if (evenLineCount == false) then
				FrameMan:DrawLinePrimitive(startPos, endPos, colourIndex);
			end
		else
			FrameMan:DrawLinePrimitive(Vector(rotatedStartPos.X - (isVertical and (midCount - i) or 0), rotatedStartPos.Y - (isHorizontal and (midCount - i) or 0)):RadRotate(rotAngle), endPos, colourIndex);
		end
	end
end