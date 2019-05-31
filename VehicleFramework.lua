require("SpringFramework/SpringFramework");

VehicleFramework = {};

--Enums and Constants
VehicleFramework.AUTO_GENERATE = "autoGenerate";
VehicleFramework.SuspensionVisualsType = {INVISIBLE = 1, SPRITE = 2, DRAWN = 3};
VehicleFramework.TrackAnchorType = {ALL = 1, FIRST_AND_LAST = 2}

function VehicleFramework.createVehicle(self, vehicleConfig)
	local vehicle = vehicleConfig;
	
	--Initialize necessary configs if they don't exist
	vehicle.general = vehicle.general or {};
	vehicle.chassis = vehicle.chassis or {};
	vehicle.suspension = vehicle.suspension or {};
	vehicle.wheel = vehicle.wheel or {};
	vehicle.tensioner = vehicle.tensioner or nil;
	vehicle.track = vehicle.track == true and {} or vehicle.track;
	vehicle.destruction = vehicle.destruction or {};
	vehicle.layer = vehicle.layer or {};
	
	--------------------
	--GENERAL SETTINGS--
	--------------------
	vehicle.general.RTE = string.sub(self:GetModuleAndPresetName(), 1, string.find(self:GetModuleAndPresetName(), "/") - 1);
	
	vehicle = VehicleFramework.setCustomisationDefaultsAndLimits(self, vehicle);
	
	VehicleFramework.ensureVehicleConfigIsValid(vehicle);
	
	vehicle.general.team = self.Team;
	vehicle.general.pos = self.Pos;
	vehicle.general.vel = self.Vel;
	vehicle.general.previousPos = Vector(vehicle.general.pos.X, vehicle.general.pos.Y);
	vehicle.general.previousVel = Vector(vehicle.general.vel.X, vehicle.general.vel.Y);
	vehicle.general.controller = self:GetController();
	vehicle.general.throttle = 0;
	vehicle.general.isInAir = false;
	vehicle.general.halfOrMoreInAir = false;
	vehicle.general.distanceFallen = 0
	vehicle.general.resetDistanceFallenForGround = true;
	vehicle.general.isDriving = false;
	vehicle.general.isStronglyDecelerating = false;
	
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
	--LAYER SETTINGS--
	------------------
	vehicle.layer.current = 1;
	vehicle.layer.allLayersAdded = false;
	vehicle.layer.addLayerTimer = Timer();
	
	-----------------------------
	--OBJECT CREATION AND SETUP--
	-----------------------------
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
	
	return vehicle;
end

function VehicleFramework.setCustomisationDefaultsAndLimits(self, vehicle)
	--General
	vehicle.general.maxSpeed = vehicle.general.maxSpeed or vehicle.general.maxThrottle;
	assert(vehicle.general.maxSpeed, "Only one of vehicle.general.maxSpeed vehicle.general.maxThrottle can be nil. Please check the Vehicle Configuration Documentation.");
	vehicle.general.maxSpeed = Clamp(vehicle.general.maxSpeed, 0, 1000000000);
	
	vehicle.general.maxThrottle = vehicle.general.maxThrottle or vehicle.general.maxSpeed;
	vehicle.general.maxThrottle = Clamp(vehicle.general.maxThrottle, 0, 1000000000);
	
	vehicle.general.acceleration = vehicle.general.acceleration or vehicle.general.maxThrottle/40;
	vehicle.general.acceleration = Clamp(vehicle.general.acceleration, 0, vehicle.general.maxThrottle);
	
	vehicle.general.deceleration = vehicle.general.deceleration or vehicle.general.acceleration/20;
	vehicle.general.deceleration = Clamp(vehicle.general.deceleration, 0, vehicle.general.maxThrottle);
	
	vehicle.general.rotAngleCorrectionRate = vehicle.general.rotAngleCorrectionRate or 0.05;
	vehicle.general.rotAngleCorrectionRate = Clamp(vehicle.general.rotAngleCorrectionRate, 0, 2*math.pi);
	
	vehicle.general.maxErasableTerrainStrength = vehicle.general.maxErasableTerrainStrength or 100;
	vehicle.general.maxErasableTerrainStrength = Clamp(vehicle.general.maxErasableTerrainStrength, 0, 1000000000);
	
	if (vehicle.general.forceWheelHorizontalLocking == nil) then
		vehicle.general.forceWheelHorizontalLocking = (vehicle.track ~= nil or vehicle.tensioner ~= nil) and true or false;
	end
	
	if (vehicle.general.allowSlidingWhileStopped == nil) then
		vehicle.general.allowSlidingWhileStopped = false;
	end
	
	vehicle.general.showDebug = vehicle.general.showDebug == true and true or false;
	
	--Chassis
	--Nothing here
	
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
	
	vehicle.suspension.visualsType = vehicle.suspension.visualsType or (vehicle.track ~= nil or vehicle.tensioner ~= nil) and VehicleFramework.SuspensionVisualsType.INVISIBLE or VehicleFramework.SuspensionVisualsType.DRAWN;
	
	vehicle.suspension.visualsConfig = vehicle.suspension.visualsConfig or {};
	if (vehicle.suspension.visualsType == VehicleFramework.SuspensionVisualsType.INVISIBLE) then
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
	vehicle.layer.addLayerInterval = vehicle.layer.addLayerInterval or 10;
	vehicle.layer.addLayerInterval = Clamp(vehicle.layer.addLayerInterval, 1, 1000000000);
	
	if (vehicle.layer[1] ~= nil) then
		--If there's a custom layer config, ensure it has required layers
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
		table.insert(vehicle.layer, "suspension");
		table.insert(vehicle.layer, "wheel");
		table.insert(vehicle.layer, "tensioner");
		table.insert(vehicle.layer, "track");
		if (vehicle.suspension.visualsType ~= VehicleFramework.SuspensionVisualsType.SPRITE) then
			table.remove(vehicle.layer, 1);
		end
	end
	
	return vehicle;
end

function VehicleFramework.ensureVehicleConfigIsValid(vehicle)
	local ignoredKeys = {
		general = {RTE = true},
		layer = {_any = {"number"}}
	};
	local supportedTypes = {
		general = {
			maxSpeed = "number",
			maxThrottle = "number",
			acceleration = "number",
			deceleration = "number",
			rotAngleCorrectionRate = "number",
			maxErasableTerrainStrength = "number",
			forceWheelHorizontalLocking = "boolean",
			allowSlidingWhileStopped = "boolean",
			showDebug = "boolean"
		},
		chassis = {
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
			addLayerInterval = "number"
		}
	}
	--Ensure everything is a real configuration option and has the correct type
	for categoryKey, categoryTable in pairs(vehicle) do
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
					assert(supportedTypes[categoryKey][optionKey], "vehicle."..tostring(categoryKey).."."..tostring(optionKey).." is an invalid configuration option. Please check the Vehicle Configuration Documentation.");
					if (type(supportedTypes[categoryKey][optionKey]) == "string") then
						assert(type(optionValue) == supportedTypes[categoryKey][optionKey], "vehicle."..tostring(categoryKey).."."..tostring(optionKey).." must be a "..tostring(supportedTypes[categoryKey][optionKey])..". Please check the Vehicle Configuration Documentation.");
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

function VehicleFramework.createSuspensionSprites(vehicle)
	for i = 1, vehicle.suspension.count do
		if not MovableMan:ValidMO(vehicle.suspension.objects[i]) then
			vehicle.suspension.objects[i] = CreateMOSRotating(vehicle.suspension.objectName, vehicle.suspension.objectRTE);
			vehicle.suspension.objects[i].Pos = vehicle.general.pos;
			vehicle.suspension.objects[i].Team = vehicle.general.team;
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
			vehicle.wheel.objects[i] = CreateMOSRotating(vehicle.wheel.objectName, vehicle.wheel.objectRTE);
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
	end
end

function VehicleFramework.createTensioners(self, vehicle)
	if (vehicle.tensioner ~= nil) then
		local xOffset;
		for i = 1, vehicle.tensioner.count do
			if not MovableMan:ValidMO(vehicle.tensioner.objects[i]) then
				vehicle.tensioner.objects[i] = CreateMOSRotating(vehicle.tensioner.objectName, vehicle.tensioner.objectRTE);
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
			end
		end
		VehicleFramework.updateTensioners(self, vehicle);
	end
end

function VehicleFramework.createTrack(self, vehicle)
	if (vehicle.track ~= nil and vehicle.tensioner ~= nil) then
		local trackSizer = CreateMOSRotating(vehicle.track.objectName);
		vehicle.track.size = trackSizer.SpriteOffset * -2;
		trackSizer.ToDelete = true;
		trackSizer = nil;
	
		VehicleFramework.setupTrackInflection(vehicle);
		VehicleFramework.calculateTrackOffsets(vehicle);
		
		for i = 1, vehicle.track.count do
			if not MovableMan:ValidMO(vehicle.track.objects[i]) then
				vehicle.track.objects[i] = CreateMOSRotating(vehicle.track.objectName, vehicle.track.objectRTE);
				vehicle.track.objects[i].Team = vehicle.general.team;
				vehicle.track.objects[i].Vel = Vector();
				vehicle.track.objects[i].Pos = vehicle.general.pos + Vector(vehicle.track.unrotatedOffsets[i].X, vehicle.track.unrotatedOffsets[i].Y):RadRotate(self.RotAngle);
				vehicle.track.objects[i].RotAngle = self.RotAngle + vehicle.track.directions[i];
				vehicle.track.objects[i].IgnoresTeamHits = true;
			end
		end
	end
end

function VehicleFramework.setupTrackInflection(vehicle)
	if (vehicle.track.inflection == nil) then
		vehicle.track.inflection = {};
		local inflectionConfig, iteratorIncrement;
		
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
			if (vehicle.showDebug) then
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
				if (showDebug) then
					print("direction difference: "..tostring(math.abs(inflection.next.trackDirection - inflection.trackDirection))..", distance magnitude: "..tostring(SceneMan:ShortestDistance(inflection.trackEnd, inflection.next.trackStart, SceneMan.SceneWrapsX).Magnitude));
				end
				if (math.abs(inflection.next.trackDirection - inflection.trackDirection)  > (30 * math.pi/180) and SceneMan:ShortestDistance(inflection.trackEnd, inflection.next.trackStart, SceneMan.SceneWrapsX).Magnitude > vehicle.track.size.Magnitude * 0.1) then
					table.insert(vehicle.track.unrotatedOffsets, inflection.trackEnd);
					table.insert(vehicle.track.trackEnds, #vehicle.track.unrotatedOffsets);
					vehicle.track.skippedEnds[i] = false;
					if (showDebug) then
						print("Adding end track for inflection "..tostring(i));
					end
				else
					numberOfTracks = numberOfTracks - 1;
					vehicle.track.skippedEnds[i] = true;
					if (showDebug) then
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

function VehicleFramework.addNextLayer(vehicle)
	local layer = vehicle.layer[vehicle.layer.current];
	
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
		end
	elseif(type(layer) == "string") then
		for _, layerObject in ipairs(vehicle[layer].objects) do
			MovableMan:AddParticle(layerObject);
		end
	else
		error("Layer "..tostring(vehicle.layer.current).." is a "..tostring(type(layer)).." which is not valid. Please check the Vehicle Configuration Documentation.");
	end
	
	vehicle.layer.allLayersAdded = vehicle.layer.current == #vehicle.layer;
	vehicle.layer.current = vehicle.layer.current + 1;
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
		if (vehicle.layer.allLayersAdded) then
			local destroyed = VehicleFramework.updateDestruction(self, vehicle);
			
			if (not destroyed) then
				VehicleFramework.updateAltitudeChecks(vehicle);
				
				VehicleFramework.updateThrottle(vehicle);
				
				VehicleFramework.updateWheels(vehicle);
				
				VehicleFramework.updateSprings(vehicle);
				
				VehicleFramework.updateTensioners(self, vehicle);
				
				VehicleFramework.updateTrack(self, vehicle);
				
				VehicleFramework.updateChassis(self, vehicle);
				
				VehicleFramework.updateSuspension(self, vehicle);
			end
		else
			if (vehicle.layer.addLayerTimer:IsPastSimMS(vehicle.layer.addLayerInterval)) then
				VehicleFramework.addNextLayer(vehicle);
				vehicle.layer.addLayerTimer:Reset();
				
				if (vehicle.layer.allLayersAdded) then
					vehicle.layer.addLayerTimer = nil;
					vehicle.layer.addLayerInterval = nil;
				end
			end
		end
		
		vehicle.general.previousPos:SetXY(vehicle.general.pos.X, vehicle.general.pos.Y);
		vehicle.general.previousVel:SetXY(vehicle.general.vel.X, vehicle.general.vel.Y);
	end
	
	return vehicle;
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
			if (vehicle.showDebug) then
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
			vehicle.general.distanceFallen = vehicle.general.distanceFallen + SceneMan:ShortestDistance(vehicle.general.previousPos, vehicle.general.pos, SceneMan.SceneWrapsX).Y;
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
	vehicle.general.isDriving = true;
	vehicle.general.movingOppositeToThrottle = false;
	
	if vehicle.general.controller:IsState(Controller.MOVE_LEFT) and vehicle.general.throttle < vehicle.general.maxThrottle then
		vehicle.general.throttle = vehicle.general.throttle + vehicle.general.acceleration;
		vehicle.general.movingOppositeToThrottle = vehicle.general.throttle < 0;
	elseif vehicle.general.controller:IsState(Controller.MOVE_RIGHT) and vehicle.general.throttle > -vehicle.general.maxThrottle then
		vehicle.general.throttle = vehicle.general.throttle - vehicle.general.acceleration;
		vehicle.general.movingOppositeToThrottle = vehicle.general.throttle > 0;
	else
		vehicle.general.isDriving = false;
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
	local wheelObject;
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
				
				if (vehicle.general.maxErasableTerrainStrength > 0 and vehicle.general.vel.Magnitude < 5 and math.abs(vehicle.general.throttle) > vehicle.general.maxThrottle * 0.75 and math.abs(wheelObject.AngularVel) > vehicle.general.maxThrottle * 0.5) then
					--Check terrain strength at the wheel's position and its 4 center edges
					local erasableTerrain = {
						SceneMan:GetMaterialFromID(SceneMan:GetTerrMatter(wheelObject.Pos.X, wheelObject.Pos.Y)).Strength <= vehicle.general.maxErasableTerrainStrength and true or nil,
						SceneMan:GetMaterialFromID(SceneMan:GetTerrMatter(wheelObject.Pos.X - vehicle.wheel.size[i] * 0.5, wheelObject.Pos.Y)).Strength <= vehicle.general.maxErasableTerrainStrength and true or nil,
						SceneMan:GetMaterialFromID(SceneMan:GetTerrMatter(wheelObject.Pos.X + vehicle.wheel.size[i] * 0.5, wheelObject.Pos.Y)).Strength <= vehicle.general.maxErasableTerrainStrength and true or nil,
						SceneMan:GetMaterialFromID(SceneMan:GetTerrMatter(wheelObject.Pos.X, wheelObject.Pos.Y - vehicle.wheel.size[i] * 0.5)).Strength <= vehicle.general.maxErasableTerrainStrength and true or nil,
						SceneMan:GetMaterialFromID(SceneMan:GetTerrMatter(wheelObject.Pos.X, wheelObject.Pos.Y + vehicle.wheel.size[i] * 0.5)).Strength <= vehicle.general.maxErasableTerrainStrength and true or nil
					};
					if (#erasableTerrain > 3) then
						wheelObject:EraseFromTerrain();
					end
				end
			end
		end
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
		desiredRotAngle = SceneMan:ShortestDistance(vehicle.wheel.objects[1].Pos, vehicle.wheel.objects[vehicle.wheel.count].Pos, SceneMan.SceneWrapsX).AbsRadAngle;
	end
	if (self.RotAngle < desiredRotAngle - vehicle.general.rotAngleCorrectionRate * 1.1) then
		self.RotAngle = self.RotAngle + vehicle.general.rotAngleCorrectionRate;
	elseif (self.RotAngle > desiredRotAngle + vehicle.general.rotAngleCorrectionRate * 1.1) then
		self.RotAngle = self.RotAngle - vehicle.general.rotAngleCorrectionRate;
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
						self.Pos = vehicle.general.previousPos;
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

function VehicleFramework.updateSuspension(self, vehicle)
	if (vehicle.suspension.visualsType ~= VehicleFramework.SuspensionVisualsType.INVISIBLE) then
		for i, spring in ipairs(vehicle.suspension.springs) do
			vehicle.suspension.offsets.main[i] = spring.targetPos[1];
			if (i ~= vehicle.wheel.count) then
				vehicle.suspension.offsets.midPoint[i] = vehicle.suspension.offsets.main[i] + Vector(vehicle.wheel.spacing * 0.5, 0):RadRotate(self.RotAngle);
			end
		end

		if (vehicle.suspension.visualsType == VehicleFramework.SuspensionVisualsType.DRAWN) then
			VehicleFramework.updateDrawnSuspension(self, vehicle);
		elseif (vehicle.suspension.visualsType == VehicleFramework.SuspensionVisualsType.SPRITE) then
			VehicleFramework.updateSpriteSuspension(self, vehicle);
		end
	end
end

function VehicleFramework.updateDrawnSuspension(self, vehicle)
	for i, wheelObject in ipairs(vehicle.wheel.objects) do
		VehicleFramework.drawArrow(vehicle.suspension.offsets.main[i], Vector(wheelObject.Pos.X, wheelObject.Pos.Y), self.RotAngle, vehicle.suspension.visualsConfig.widths[i], vehicle.suspension.visualsConfig.colourIndex);
		if (i ~= 1) then
			VehicleFramework.drawArrow(vehicle.suspension.offsets.midPoint[i - 1], Vector(wheelObject.Pos.X, wheelObject.Pos.Y), self.RotAngle, vehicle.suspension.visualsConfig.widths[i], vehicle.suspension.visualsConfig.colourIndex);
		end
		if (i ~= vehicle.wheel.count) then
			VehicleFramework.drawArrow(vehicle.suspension.offsets.midPoint[i], wheelObject.Pos, self.RotAngle, vehicle.suspension.visualsConfig.widths[i], vehicle.suspension.visualsConfig.colourIndex);
		end
	end
end

function VehicleFramework.updateSpriteSuspension(self, vehicle)
end

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

---------------------
--UTILITY FUNCTIONS--
---------------------
function VehicleFramework.drawArrow(startPos, endPos, rotAngle, width, colourIndex)
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