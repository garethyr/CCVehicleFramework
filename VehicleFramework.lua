package.loaded["SpringFramework/SpringFramework"] = nil; --TODO killme
require("SpringFramework/SpringFramework");

VehicleFramework = {};

--Enums and Constants
VehicleFramework.SuspensionVisualsType = {INVISIBLE = 1, SPRITE = 2, DRAWN = 3};

function VehicleFramework.createVehicle(self, vehicleConfig)
	local vehicle = vehicleConfig;
	
	--------------------
	--GENERAL SETTINGS--
	--------------------
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
		vehicle.track.corners.objects = {};
		vehicle.track.bottom.objects = {};
		vehicle.track.top.objects = {};
	end
	
	------------------------
	--DESTRUCTION SETTINGS--
	------------------------
	vehicle.destruction.overturnedTimer = Timer();
	vehicle.destruction.overturnedInterval = 1000;
	vehicle.destruction.overturnedCounter = 0;
	
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
	
	return vehicle;
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
			applyForcesAtOffset = false,
			lockToSpringRotation = true,
			inheritsRotAngle = 1,
			rotAngleOffset = -math.pi*0.5,
			outsideOfConfinesAction = {SpringFramework.OutsideOfConfinesOptions.DO_NOTHING, SpringFramework.OutsideOfConfinesOptions.MOVE_TO_REST_POSITION},
			confinesToCheck = {min = false, absolute = true, max = true},
			showDebug = false
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
				vehicle.tensioner.objects[i].HitsMOS = false;
				vehicle.tensioner.objects[i].GetsHitByMOs = false;
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
	if (vehicle.track ~= nil) then
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
	end
end

function VehicleFramework.updateVehicle(self, vehicle)
	local destroyed = VehicleFramework.updateDestruction(self, vehicle);
	
	if (not destroyed) then
		VehicleFramework.updateAltitudeChecks(vehicle);
	
		VehicleFramework.updateThrottle(vehicle);
		
		VehicleFramework.updateWheels(vehicle);
		
		VehicleFramework.updateSprings(vehicle);
		
		VehicleFramework.updateTensioners(self, vehicle);
		
		VehicleFramework.updateTrack(self, vehicle);
		
		VehicleFramework.updateChassis(self, vehicle);
		
		if (vehicle.suspension.visualsType ~= VehicleFramework.SuspensionVisualsType.INVISIBLE) then
			VehicleFramework.updateSuspension(self, vehicle);
		end
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
	local inAirWheelCount = vehicle.wheel.count;
	vehicle.wheel.isInAir = {};
	for i, wheelObject in ipairs(vehicle.wheel.objects) do
		checkAltitudeForWheel = i == 1 or i == vehicle.wheel.count;
		
		if (not checkAltitudeForWheel and vehicle.wheel.count > 4) then
			if (vehicle.wheel.evenWheelCount) then
				checkAltitudeForWheel = i <= vehicle.wheel.midWheel and i%2 == 1 or i%2 == 0;
			else
				checkAltitudeForWheel = i%2 == 1;
			end
		end
		
		if (checkAltitudeForWheel) then
			local alt = wheelObject:GetAltitude(0, vehicle.wheel.size * 0.5);
			vehicle.wheel.isInAir[i] = alt > vehicle.wheel.size;
			if (not vehicle.wheel.isInAir[i]) then
				inAirWheelCount = inAirWheelCount - 1;
			end
		end
	end
	vehicle.general.isInAir = inAirWheelCount == vehicle.wheel.count;
	
	for i = 1, vehicle.wheel.count do
		if (vehicle.wheel.isInAir[i] == nil) then
			vehicle.wheel.isInAir[i] = vehicle.general.isInAir;
		end
	end
end

function VehicleFramework.updateThrottle(vehicle)
	vehicle.general.isDriving = true;
	if vehicle.general.controller:IsState(Controller.MOVE_LEFT) and vehicle.general.throttle < vehicle.general.maxThrottle then
		vehicle.general.throttle = vehicle.general.throttle + vehicle.general.acceleration;
	elseif vehicle.general.controller:IsState(Controller.MOVE_RIGHT) and vehicle.general.throttle > -vehicle.general.maxThrottle then
		vehicle.general.throttle = vehicle.general.throttle - vehicle.general.acceleration;
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
		
		if (vehicle.wheel.isInAir[i]) then
			wheelObject.Pos = vehicle.suspension.springs[i].pos[2].max;
			wheelObject.Vel.Y = vehicle.general.vel.Y;
			--wheelObject.Vel.Y = wheelObject.Vel.Y - SceneMan.GlobalAcc.Magnitude*TimerMan.DeltaTimeSecs;
		end
	end
end

function VehicleFramework.updateSprings(vehicle)
	local wheelObject;
	for i, spring in ipairs(vehicle.suspension.springs) do
		wheelObject = vehicle.wheel.objects[i];
		if (spring ~= nil) then
			--Don't update objects if in air, calculations need to be update because they're used elsewhere
			vehicle.suspension.springs[i] = SpringFramework.update(spring, vehicle.wheel.isInAir[i]);
			spring = vehicle.suspension.springs[i];
		end
		if (spring ~= nil and spring.actionsPerformed ~= nil) then
			if (not spring.actionsPerformed[SpringFramework.SpringActions.APPLY_FORCES]) then
				wheelObject:MoveOutOfTerrain(6); --TODO Consider doing this all the time
				
				if vehicle.general.vel.Magnitude < 5 and math.abs(vehicle.general.throttle) > vehicle.general.maxThrottle * 0.75 and math.abs(wheelObject.AngularVel) > vehicle.general.maxThrottle * 0.5 then
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
		end
	end
end

function VehicleFramework.updateTrack(self, vehicle)
	if (vehicle.track ~= nil) then
	end
end

function VehicleFramework.updateChassis(self, vehicle)
	local desiredRotAngle = SceneMan:ShortestDistance(vehicle.wheel.objects[1].Pos, vehicle.wheel.objects[vehicle.wheel.count].Pos, SceneMan.SceneWrapsX).AbsRadAngle;
	if (self.RotAngle < desiredRotAngle - vehicle.general.deceleration * 2) then
		self.RotAngle = self.RotAngle + vehicle.general.deceleration;
	elseif (self.RotAngle > desiredRotAngle + vehicle.general.deceleration * 2) then
		self.RotAngle = self.RotAngle - vehicle.general.deceleration;
	end
		
	if (not vehicle.general.isInAir) then
		self:MoveOutOfTerrain(6);
		self.AngularVel = self.AngularVel * 0.5;
		
		if (vehicle.general.vel.Magnitude > vehicle.general.maxSpeed) then
			self.Vel = Vector(vehicle.general.vel.X, vehicle.general.vel.Y):SetMagnitude(vehicle.general.maxSpeed);
		elseif (not vehicle.general.isDriving) then
			if (vehicle.general.isStronglyDecelerating) then
				self.Vel = self.Vel * (1 - vehicle.general.deceleration * 10);
			else
				self.Vel = self.Vel * (1 - vehicle.general.deceleration);
			end
		
			if (self.Vel.Magnitude < vehicle.general.acceleration) then
				self.Vel = Vector(0, 0);
			end
		end
	end
end

function VehicleFramework.updateSuspension(self, vehicle)
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