require("SpringFramework/SpringFramework");

VehicleFramework = {};

--Enums and Constants
VehicleFramework.SuspensionVisualsType = {INVISIBLE = 1, SPRITE = 2, DRAWN = 3};
VehicleFramework.TrackAnchorType = {ALL = 1, FIRST_AND_LAST = 2}

function VehicleFramework.createVehicle(self, vehicleConfig)
	local vehicle = vehicleConfig;
	
	--------------------
	--GENERAL SETTINGS--
	--------------------
	vehicle.general.fullyCreated = vehicle.general.fullyCreated or 0;
	if (vehicle.general.fullyCreated == 0) then
		vehicle.general.team = self.Team;
		vehicle.general.pos = self.Pos;
		vehicle.general.vel = self.Vel;
		vehicle.general.controller = self:GetController();
		vehicle.general.throttle = 0;
		vehicle.general.isInAir = false;
		vehicle.general.isDriving = false;
		vehicle.general.isStronglyDecelerating = false;
		
		-----------------------
		--Suspension SETTINGS--
		-----------------------
		vehicle.suspension.springs = {};
		vehicle.suspension.objects = {};
		vehicle.suspension.offsets = {main = {}, midPoint = {}};
		vehicle.suspension.length = {};
		vehicle.suspension.longest = {max = 0};
		
		for i = 1, vehicle.wheel.count do
			if (vehicle.suspension.defaultLength) then
				vehicle.suspension.length[i] = {min = vehicle.suspension.defaultLength.min, normal = vehicle.suspension.defaultLength.normal, max = vehicle.suspension.defaultLength.max};
			end
			if (vehicle.suspension.lengthOverride ~= nil and vehicle.suspension.lengthOverride[i] ~= nil) then
				vehicle.suspension.length[i] = {min = vehicle.suspension.lengthOverride[i].min, normal = vehicle.suspension.lengthOverride[i].normal, max = vehicle.suspension.lengthOverride[i].max};
			end
			vehicle.suspension.length[i].difference = vehicle.suspension.length[i].max - vehicle.suspension.length[i].min;
			vehicle.suspension.length[i].mid = vehicle.suspension.length[i].min + vehicle.suspension.length[i].difference * 0.5;
			vehicle.suspension.length[i].normal = vehicle.suspension.length[i].normal or vehicle.suspension.length[i].mid; --Default to mid if we have no normal
			vehicle.suspension.longest = vehicle.suspension.length[i].max > vehicle.suspension.longest.max and vehicle.suspension.length[i] or vehicle.suspension.longest;
		end
		vehicle.suspension.defaultLength = nil; vehicle.suspension.lengthOverride = nil; --Clean these up so we don't use them accidentally in future
		
		------------------
		--WHEEL SETTINGS--
		------------------
		vehicle.wheel.objects = {};
		vehicle.wheel.size = 0; --This gets filled in by the createWheels function cause it uses the wheel object's diameter
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
			vehicle.tensioner.size = 0; --This gets filled in by the createWheels function cause it uses the tensioner object's diameter
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
			vehicle.track.directions = {};
			vehicle.track.objects = {};
			if (vehicle.track.inflection == nil) then
				vehicle.track.tensionerAnchorType = vehicle.track.tensionerAnchorType or VehicleFramework.TrackAnchorType.ALL;
				vehicle.track.wheelAnchorType = vehicle.track.wheelAnchorType or VehicleFramework.TrackAnchorType.ALL;
			end
		end
		
		------------------------
		--DESTRUCTION SETTINGS--
		------------------------
		vehicle.destruction.overturnedTimer = Timer();
		vehicle.destruction.overturnedInterval = 1000;
		vehicle.destruction.overturnedCounter = 0;
		
		vehicle.general.fullyCreated = vehicle.general.fullyCreated + 1;
		return vehicle;
	end
	
	if (vehicle.general.fullyCreated == 1) then
		-----------------------------
		--OBJECT CREATION AND SETUP--
		-----------------------------
		if (vehicle.suspension.visualsType == VehicleFramework.SuspensionVisualsType.SPRITE) then
			VehicleFramework.createSuspensionSprites(vehicle);
		end
		
		VehicleFramework.createWheels(self, vehicle);
		
		VehicleFramework.createSprings(self, vehicle);
		
		VehicleFramework.createTensioners(self, vehicle);
		
		VehicleFramework.createTrack(self, vehicle);
		
		if (not vehicle.general.forceWheelHorizontalLocking) then
			for _, wheelObject in ipairs(vehicle.wheel.objects) do
				for __, tensionerObject in ipairs(vehicle.tensioner.objects) do
					wheelObject:SetWhichMOToNotHit(tensionerObject, -1);
				end
				for __, trackObject in ipairs(vehicle.track.objects) do
					wheelObject:SetWhichMOToNotHit(trackObject, -1);
				end
			end
		end
		
		vehicle.general.fullyCreated = true;
		return vehicle;
	end
end

function VehicleFramework.createSuspensionSprites(vehicle)
	for i = 1, vehicle.suspension.count do
		if not MovableMan:ValidMO(vehicle.suspension.objects[i]) then
			vehicle.suspension.objects[i] = CreateMOSRotating(vehicle.wheel.objectName, vehicle.wheel.objectRTE);
			vehicle.suspension.objects[i].Pos = vehicle.general.pos;
			vehicle.suspension.objects[i].Team = vehicle.general.team;
			MovableMan:AddParticle(vehicle.suspension.objects[i]);
		end
	end
end

function VehicleFramework.createWheels(self, vehicle)
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
			vehicle.wheel.objects[i].Team = vehicle.general.team;
			vehicle.wheel.objects[i].Pos = calculateWheelOffsetAndPosition(self.RotAngle, vehicle, i);
			vehicle.wheel.objects[i].Vel = Vector(0, 0);
			vehicle.wheel.objects[i].IgnoresTeamHits = vehicle.general.forceWheelHorizontalLocking;
			MovableMan:AddParticle(vehicle.wheel.objects[i]);
		end
	end
	vehicle.wheel.size = vehicle.wheel.objects[1].Diameter/math.sqrt(2);
end

function VehicleFramework.createSprings(self, vehicle)
	for i, wheelObject in ipairs(vehicle.wheel.objects) do			
		local springConfig = {
			length = {vehicle.suspension.length[i].min, vehicle.suspension.length[i].normal, vehicle.suspension.length[i].max},
			primaryTarget = 1,
			stiffness = vehicle.suspension.stiffness,
			stiffnessMultiplier = {self.Mass/vehicle.wheel.count, vehicle.wheel.objects[i].Mass},
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
				if (i == vehicle.tensioner.midTensioner) then
					xOffset = vehicle.tensioner.evenTensionerCount and -vehicle.tensioner.spacing * 0.5 or 0;
				else
					xOffset = vehicle.tensioner.spacing * (i - vehicle.tensioner.midTensioner) + (vehicle.tensioner.evenTensionerCount and -vehicle.tensioner.spacing * 0.5 or 0);
				end
				vehicle.tensioner.unrotatedOffsets[i] = Vector(xOffset, vehicle.tensioner.displacement[((i == 1 or i == vehicle.tensioner.count) and "outside" or "inside")]);
				
				vehicle.tensioner.objects[i] = CreateMOSRotating(vehicle.tensioner.objectName, vehicle.tensioner.objectRTE);
				vehicle.tensioner.objects[i].Team = vehicle.general.team;
				vehicle.tensioner.objects[i].Vel = Vector(0, 0);
				vehicle.tensioner.objects[i].IgnoresTeamHits = true;
				--Everything below here doesn't seem to work, need to figure out a way to make these not hit the wheels
				--[[
				vehicle.tensioner.objects[i].IgnoresTeamHits = true;
				for _, wheelObject in ipairs(vehicle.wheel.objects) do
					vehicle.tensioner.objects[i]:SetWhichMOToNotHit(wheelObject, -1);
				end
				--]]
				MovableMan:AddParticle(vehicle.tensioner.objects[i]);
			end
		end
		vehicle.tensioner.size = vehicle.tensioner.objects[1].Diameter/math.sqrt(2);
		VehicleFramework.updateTensioners(self, vehicle);
	end
end

function VehicleFramework.createTrack(self, vehicle)
	if (vehicle.track ~= nil and vehicle.tensioner ~= nil) then
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
				MovableMan:AddParticle(vehicle.track.objects[i]);
			end
		end
	end
end

function VehicleFramework.setupTrackInflection(vehicle)
	if (vehicle.track.inflection == nil) then
		vehicle.track.inflectionStartOffsetDirection = Vector(0, -1);
		
		vehicle.track.inflection = {};
		local inflectionConfig, iteratorIncrement;
		
		iteratorIncrement = vehicle.track.tensionerAnchorType == VehicleFramework.TrackAnchorType.FIRST_AND_LAST and (vehicle.tensioner.count - 1) or 1;
		for i = 1, vehicle.tensioner.count, iteratorIncrement do
			inflectionConfig = {
				point = vehicle.tensioner.unrotatedOffsets[i],
				objectTable = vehicle.tensioner,
				objectIndex = i,
				objectSize = vehicle.tensioner.size
			}
			table.insert(vehicle.track.inflection, inflectionConfig);
		end
		
		iteratorIncrement = vehicle.track.wheelAnchorType == VehicleFramework.TrackAnchorType.FIRST_AND_LAST and (vehicle.wheel.count - 1) or 1;
		for i = vehicle.wheel.count, 1, -iteratorIncrement do
			inflectionConfig = {
				point = vehicle.wheel.unrotatedOffsets[i],
				objectTable = vehicle.wheel,
				objectIndex = i,
				objectSize = vehicle.wheel.size
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
	for i, inflection in ipairs(vehicle.track.inflection) do
		local numberOfTracks = math.ceil(inflection.trackDistance.Magnitude/vehicle.track.size.X);
		
		--Add an extra track to fill in space if necessary, i.e. the remainder distance is more than 1/10th of number of tracks (so 5 tracks would become 6 if the remainder distance is > 0.5 track width)
		local extraFillerTrack = false;
		do
			if (numberOfTracks == 1) then
				numberOfTracks = 2;
			else
				local remainderDistance = inflection.trackDistance.Magnitude%vehicle.track.size.X;
				extraFillerTrack = numberOfTracks * 0.1 <= remainderDistance;
				if (extraFillerTrack == true) then
					print("Adding extra filler track for inflection "..tostring(i));
				else
					print("NOT Adding extra filler track for inflection "..tostring(i));
				end
			end
		end
		numberOfTracks = extraFillerTrack and numberOfTracks + 1 or numberOfTracks;
		
		--Add an extra track if the angle difference between this inflection and the next is significant, to support corners
		local extraCornerTrack = false;
		do
		end
		numberOfTracks = extraCornerTrack and numberOfTracks + 1 or numberOfTracks;
		
		--How it works:
		--If remainder dist is >= x% of track size, add another track, otherwise shift everything that's not edges by remainderDistance/numberOfTracks - 3 (2 for ends, 1 for corner)
		
		
		for j = 1, numberOfTracks do
			if (j == 1) then
				table.insert(vehicle.track.unrotatedOffsets, inflection.trackStart);-- + (i ~= 1 and Vector(vehicle.track.size.X * 0.5, 0):RadRotate(inflection.trackDirection) or Vector()));
				table.insert(vehicle.track.trackStarts, #vehicle.track.unrotatedOffsets);
			elseif (j == numberOfTracks) then
				table.insert(vehicle.track.unrotatedOffsets, inflection.trackEnd);
				table.insert(vehicle.track.trackEnds, #vehicle.track.unrotatedOffsets);
			--elseif (j == numberOfTracks) then
			--	table.insert(vehicle.track.unrotatedOffsets, (inflection.trackEnd + inflection.next.trackStart) * 0.5);
			else
				table.insert(vehicle.track.unrotatedOffsets, vehicle.track.unrotatedOffsets[#vehicle.track.unrotatedOffsets] + inflection.trackDirectionVector * vehicle.track.size.X);
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
			vehicle.track.unrotatedOffsets[fillerNumber] = (vehicle.track.unrotatedOffsets[fillerNumber - 1] + vehicle.track.unrotatedOffsets[fillerNumber + 1]) * 0.5;
		end
		vehicle.track.count = vehicle.track.count + numberOfTracks;
	end
end

function VehicleFramework.destroyVehicle(vehicle)
	if (vehicle ~= nil) then
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
	if (vehicle.general.fullyCreated ~= true) then
		return VehicleFramework.createVehicle(self, vehicle);
	end

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
	
	return vehicle;
end

function VehicleFramework.updateDestruction(self, vehicle)
	if (self.Health < 0) then
		self:GibThis();
		return true;
	end
	
	if (vehicle.destruction.overturnedTimer:IsPastSimMS(vehicle.destruction.overturnedInterval)) then
		for _, wheelObject in ipairs(vehicle.wheel.objects) do
			if (wheelObject.Pos.Y < vehicle.general.pos.Y) then
				vehicle.destruction.overturnedCounter = vehicle.destruction.overturnedCounter + 1;
			end
		end
		
		if (vehicle.destruction.overturnedCounter > vehicle.destruction.overturnedLimit) then
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
		local wheelAltitude = wheelObject:GetAltitude(0, vehicle.wheel.size);
		vehicle.wheel.isInAir[i] = false;
		
		if (wheelAltitude > vehicle.wheel.size * 2) then
			vehicle.wheel.isInAir[i] = true;
			inAirWheelCount = inAirWheelCount + 1;
		end
	end
	vehicle.general.isInAir = inAirWheelCount == vehicle.wheel.count;
	vehicle.general.halfOrMoreInAir = inAirWheelCount > vehicle.wheel.count * 0.5;
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
						SceneMan:GetMaterialFromID(SceneMan:GetTerrMatter(wheelObject.Pos.X - vehicle.wheel.size * 0.5, wheelObject.Pos.Y)).Strength <= vehicle.general.maxErasableTerrainStrength and true or nil,
						SceneMan:GetMaterialFromID(SceneMan:GetTerrMatter(wheelObject.Pos.X + vehicle.wheel.size * 0.5, wheelObject.Pos.Y)).Strength <= vehicle.general.maxErasableTerrainStrength and true or nil,
						SceneMan:GetMaterialFromID(SceneMan:GetTerrMatter(wheelObject.Pos.X, wheelObject.Pos.Y - vehicle.wheel.size * 0.5)).Strength <= vehicle.general.maxErasableTerrainStrength and true or nil,
						SceneMan:GetMaterialFromID(SceneMan:GetTerrMatter(wheelObject.Pos.X, wheelObject.Pos.Y + vehicle.wheel.size * 0.5)).Strength <= vehicle.general.maxErasableTerrainStrength and true or nil
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
		local prevTrackObject, nextTrackObject, prevTrackDistance, nextTrackDistance, anchorDistance;
		local currentInflectionNumber = 1;
		local currentInflection = vehicle.track.inflection[currentInflectionNumber];
		for i, trackObject in ipairs(vehicle.track.objects) do
			prevTrackObject = vehicle.track.objects[(i == 1 and #vehicle.track.objects or i - 1)];
			nextTrackObject = vehicle.track.objects[(i == #vehicle.track.objects and 1 or i + 1)];
			
			if (i == vehicle.track.trackStarts[currentInflectionNumber]) then
				trackObject.Pos = currentInflection.objectTable.objects[currentInflection.objectIndex].Pos + (vehicle.track.unrotatedOffsets[i] - currentInflection.point):RadRotate(self.RotAngle);
			elseif (i == vehicle.track.trackEnds[currentInflectionNumber]) then
				trackObject.Pos = currentInflection.objectTable.objects[currentInflection.objectIndex].Pos + (vehicle.track.unrotatedOffsets[i] - currentInflection.point):RadRotate(self.RotAngle);

				currentInflectionNumber = currentInflectionNumber + 1;
				currentInflection = vehicle.track.inflection[currentInflectionNumber];
			else
				trackObject.Pos = prevTrackObject.Pos + SceneMan:ShortestDistance(prevTrackObject.Pos, nextTrackObject.Pos, SceneMan.SceneWrapsX) * 0.5;
			end
			
			local angleOffset = SceneMan:ShortestDistance(prevTrackObject.Pos, nextTrackObject.Pos, SceneMan.SceneWrapsX).AbsRadAngle - self.RotAngle - vehicle.track.directions[i];
			local clampedAngle = Clamp(angleOffset, -vehicle.track.maxRotationDeviation, vehicle.track.maxRotationDeviation);
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
		
				if (self.Vel.Magnitude < vehicle.general.acceleration and vehicle.general.throttle == 0) then
					self.Vel = Vector(0, 0);
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
			vehicle.suspension.offsets.main[i] = spring.targetPos[1] + Vector(0, vehicle.chassis.size.Y * 0.5):RadRotate(self.RotAngle);
			if (i ~= vehicle.wheel.count) then
				vehicle.suspension.offsets.midPoint[i] = vehicle.suspension.offsets.main[i] - Vector(vehicle.wheel.spacing * 0.5, 0):RadRotate(self.RotAngle);
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
		VehicleFramework.drawArrow(vehicle.suspension.offsets.main[i], Vector(wheelObject.Pos.X, wheelObject.Pos.Y), self.RotAngle, vehicle.suspension.visualsConfig.width, vehicle.suspension.visualsConfig.colourIndex);
		if (i ~= 1) then
			VehicleFramework.drawArrow(vehicle.suspension.offsets.midPoint[i - 1], Vector(wheelObject.Pos.X, wheelObject.Pos.Y), self.RotAngle, vehicle.suspension.visualsConfig.width, vehicle.suspension.visualsConfig.colourIndex);
		end
		if (i ~= vehicle.wheel.count) then
			VehicleFramework.drawArrow(vehicle.suspension.offsets.midPoint[i], wheelObject.Pos, self.RotAngle, vehicle.suspension.visualsConfig.width, vehicle.suspension.visualsConfig.colourIndex);
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