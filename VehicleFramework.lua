package.loaded["SpringFramework/SpringFramework"] = nil; --TODO killme
require("SpringFramework/SpringFramework");

VehicleFramework = {};

--Enums and Constants
VehicleFramework.SUSPENSION_VISUALS_TYPE = {INVISIBLE = 1, SPRITE = 2, DRAWN = 3};

function VehicleFramework.createTank(self, tankConfig)
	local tank = tankConfig;
	
	--------------------
	--GENERAL SETTINGS--
	--------------------
	tank.general.team = self.Team;
	tank.general.pos = self.Pos;
	tank.general.vel = self.Vel;
	tank.general.controller = self:GetController();
	tank.general.throttle = 0;
	tank.general.isInAir = false;
	tank.general.isDriving = false;
	tank.general.isStronglyDecelerating = false;
	
	-----------------------
	--Suspension SETTINGS--
	-----------------------
	tank.suspension.springs = {};
	tank.suspension.objects = {};
	tank.suspension.offsets = {main = {}, midPoint = {}};
	tank.suspension.length = {};
	tank.suspension.longest = {max = 0};
	
	for i = 1, tank.wheel.count do
		if (tank.suspension.defaultLength) then
			tank.suspension.length[i] = {min = tank.suspension.defaultLength.min, normal = tank.suspension.defaultLength.normal, max = tank.suspension.defaultLength.max};
		end
		if (tank.suspension.lengthOverride ~= nil and tank.suspension.lengthOverride[i] ~= nil) then
			tank.suspension.length[i] = {min = tank.suspension.lengthOverride[i].min, normal = tank.suspension.lengthOverride[i].normal, max = tank.suspension.lengthOverride[i].max};
		end
		tank.suspension.length[i].difference = tank.suspension.length[i].max - tank.suspension.length[i].min;
		tank.suspension.length[i].mid = tank.suspension.length[i].min + tank.suspension.length[i].difference * 0.5;
		tank.suspension.length[i].normal = tank.suspension.length[i].normal or tank.suspension.length[i].mid; --Default to mid if we have no normal
		tank.suspension.longest = tank.suspension.length[i].max > tank.suspension.longest.max and tank.suspension.length[i] or tank.suspension.longest;
	end
	tank.suspension.defaultLength = nil; tank.suspension.lengthOverride = nil; --Clean these up so we don't use them accidentally in future
	
	------------------
	--WHEEL SETTINGS--
	------------------
	tank.wheel.objects = {};
	tank.wheel.size = 0; --This gets filled in by the createWheels function cause it uses the wheel objects' diameter
	tank.wheel.evenWheelCount = tank.wheel.count % 2 == 0;
	tank.wheel.midWheel = tank.wheel.evenWheelCount and tank.wheel.count * 0.5 or math.ceil(tank.wheel.count * 0.5);
	
	-----------------------
	--TENSIONER SETTINGS--
	-----------------------
	if (tank.tensioner ~= nil) then
		tank.tensioner.objects = {};
	end
	
	------------------
	--TRACK SETTINGS--
	------------------
	if (tank.track ~= nil) then
		tank.track.corners.objects = {};
		tank.track.bottom.objects = {};
		tank.track.top.objects = {};
	end
	
	------------------------
	--DESTRUCTION SETTINGS--
	------------------------
	tank.destruction.overturnedTimer = Timer();
	tank.destruction.overturnedInterval = 1000;
	tank.destruction.overturnedCounter = 0;
	
	-----------------------------
	--OBJECT CREATION AND SETUP--
	-----------------------------
	if (tank.suspension.visualsType == VehicleFramework.SUSPENSION_VISUALS_TYPE.SPRITE) then
		VehicleFramework.createSuspensionSprites(tank);
	end
	
	VehicleFramework.createWheels(self, tank);
	
	VehicleFramework.createSprings(self, tank);
	
	return tank;
end

function VehicleFramework.createSuspensionSprites(tank)
	for i = 1, tank.suspension.count do
		if not MovableMan:ValidMO(tank.suspension.objects[i]) then
			tank.suspension.objects[i] = CreateMOSRotating(tank.wheel.objectName, tank.wheel.objectRTE);
			tank.suspension.objects[i].Pos = tank.general.pos;
			tank.suspension.objects[i].Team = tank.general.team;
			MovableMan:AddParticle(tank.suspension.objects[i]);
		end
	end
end

function VehicleFramework.createWheels(self, tank)
	local calculateWheelInitialPosition = function(rotAngle, tank, wheelNumber)
		local xOffset;
		if (wheelNumber == tank.wheel.midWheel) then
			xOffset = tank.wheel.evenWheelCount and tank.wheel.spacing * 0.5 or 0;
		else
			xOffset = tank.wheel.spacing * (tank.wheel.midWheel - wheelNumber) + (tank.wheel.evenWheelCount and tank.wheel.spacing * 0.5 or 0);
		end
		
		return tank.general.pos + Vector(xOffset, tank.suspension.length[wheelNumber].normal):RadRotate(rotAngle);
	end

	for i = 1, tank.wheel.count do
		if not MovableMan:ValidMO(tank.wheel.objects[i]) then
			tank.wheel.objects[i] = CreateMOSRotating(tank.wheel.objectName, tank.wheel.objectRTE);
			tank.wheel.objects[i].Team = tank.general.team;
			tank.wheel.objects[i].Pos = calculateWheelInitialPosition(self.RotAngle, tank, i);
			tank.wheel.objects[i].Vel = Vector(0, 0);
			MovableMan:AddParticle(tank.wheel.objects[i]);
		end
	end
	tank.wheel.size = tank.wheel.objects[1].Diameter/math.sqrt(2);
end

function VehicleFramework.createSprings(self, tank)
	for i, wheelObject in ipairs(tank.wheel.objects) do			
		local springConfig = {
			length = {tank.suspension.length[i].min, tank.suspension.length[i].normal, tank.suspension.length[i].max},
			primaryTarget = 1,
			stiffness = tank.suspension.stiffness,
			stiffnessMultiplier = {self.Mass/tank.wheel.count, tank.wheel.objects[i].Mass},
			offsets = Vector(tank.wheel.objects[i].Pos.X - tank.general.pos.X, 0),
			applyForcesAtOffset = false,
			lockToSpringRotation = true,
			inheritsRotAngle = 1,
			rotAngleOffset = -math.pi*0.5,
			outsideOfConfinesAction = {SpringFramework.OutsideOfConfinesOptions.DO_NOTHING, SpringFramework.OutsideOfConfinesOptions.MOVE_TO_REST_POSITION},
			confinesToCheck = {min = false, absolute = true, max = true},
			showDebug = false
		}
		tank.suspension.springs[i] = SpringFramework.create(self, tank.wheel.objects[i], springConfig);
	end
end

function VehicleFramework.updateTank(self, tank)
	local destroyed = VehicleFramework.updateDestruction(self, tank);
	if (not destroyed) then
		VehicleFramework.updateThrottle(tank);
		
		VehicleFramework.updateCalculatedPositions(self, tank);
		
		ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint("High: "..tostring(tank.general.isInAirHigh)..", Low: "..tostring(tank.general.isInAirLow), self.Pos, Activity.TEAM_1, GameActivity.ARROWDOWN);
		if (not tank.general.isInAirHigh) then
			--VehicleFramework.updatePrimaryWheel(self, tank);
			
			--VehicleFramework.updateWheels(self.HFlipped, self.RotAngle, self.tank);
			VehicleFramework.updatePositionsVelocitiesAndRotations(self, self.tank);
			
			--VehicleFramework.updateChassis(self, tank);
			--VehicleFramework.updateForces(self, tank);
		else
			--If in air, just keep the wheels in position
			for i, wheelObject in ipairs(tank.wheel.objects) do
				wheelObject.Pos = tank.wheel.rotatedOffsets[i].max;
			end
		end
		
		if (tank.suspension.visualsType ~= VehicleFramework.SUSPENSION_VISUALS_TYPE.INVISIBLE) then
			VehicleFramework.updateSuspension(self, tank);
		end
	end
end

function VehicleFramework.updateDestruction(self, tank)
	if (self.Health < 0) then
		self:GibThis();
		return true;
	end
	
	if (tank.destruction.overturnedTimer:IsPastSimMS(tank.destruction.overturnedInterval)) then
		for _, wheelObject in ipairs(tank.wheel.objects) do
			if (wheelObject.Pos.Y < tank.general.pos.Y) then
				tank.destruction.overturnedCounter = tank.destruction.overturnedCounter + 1;
			end
		end
		
		if (tank.destruction.overturnedCounter > tank.destruction.overturnedLimit) then
			self:GibThis();
			return true;
		else
			tank.destruction.overturnedCounter = math.max(tank.destruction.overturnedCounter - 1, 0);
		end
		tank.destruction.overturnedTimer:Reset();
	end
	
	return false;
end

function VehicleFramework.onDestroy(tank)
	if (tank ~= nil) then
		for _, wheelObject in ipairs(tank.wheel.objects) do
			if MovableMan:ValidMO(wheelObject) then
				wheelObject.ToDelete = true;
			end
		end
		if (tank.suspension.visualsType == VehicleFramework.SUSPENSION_VISUALS_TYPE.SPRITE) then
			for _, suspensionObject in ipairs(tank.suspension.objects) do
				if MovableMan:ValidMO(suspensionObject) then
					suspensionObject.ToDelete = true;
				end
			end
		end
	end
end

function VehicleFramework.updateThrottle(tank)
	tank.general.isDriving = true;
	if tank.general.controller:IsState(Controller.MOVE_LEFT) and tank.general.throttle < tank.general.maxThrottle then
		tank.general.throttle = tank.general.throttle + tank.general.acceleration;
	elseif tank.general.controller:IsState(Controller.MOVE_RIGHT) and tank.general.throttle > -tank.general.maxThrottle then
		tank.general.throttle = tank.general.throttle - tank.general.acceleration;
	else
		tank.general.isDriving = false;
		if (math.abs(tank.general.throttle) < tank.general.acceleration * 20) then
			tank.general.isStronglyDecelerating = true;
			tank.general.throttle = tank.general.throttle * (1 - tank.general.deceleration * 2);
		else
			tank.general.isStronglyDecelerating = false;
			tank.general.throttle = tank.general.throttle * (1 - tank.general.deceleration);
		end
		if (math.abs(tank.general.throttle) < tank.general.acceleration * 2) then
			tank.general.throttle = 0;
		end
	end
end

function VehicleFramework.updateCalculatedPositions(self, tank)
	--Need to be fairly precise about this or it might cause a false positive
	local altitude = self:GetAltitude(0, 10);
	tank.general.isInAirHigh = altitude > 4 * (tank.wheel.size + tank.suspension.longest.max);
	tank.general.isInAirLow = altitude > (tank.wheel.size + tank.suspension.longest.max);

	--Wheel related offsets, offset[1] is always rightmost and offset[wheelCount] is always leftmost
	local xOffset;
	for i = 1, tank.wheel.count do
		if (i == tank.wheel.midWheel) then
			xOffset = tank.wheel.evenWheelCount and tank.wheel.spacing * 0.5 or 0;
		else
			xOffset = tank.wheel.spacing * (tank.wheel.midWheel - i) + (tank.wheel.evenWheelCount and tank.wheel.spacing * 0.5 or 0);
		end
		tank.wheel.rotatedOffsets[i].min = tank.general.pos + Vector(xOffset, tank.suspension.length[i].min):RadRotate(self.RotAngle);
		tank.wheel.unrotatedOffsets[i].min = Vector(tank.wheel.rotatedOffsets[i].min.X, tank.wheel.rotatedOffsets[i].min.Y):RadRotate(-self.RotAngle);
		tank.wheel.rotatedOffsets[i].max = tank.general.pos + Vector(xOffset, tank.suspension.length[i].max):RadRotate(self.RotAngle);
		tank.wheel.unrotatedOffsets[i].max = Vector(tank.wheel.rotatedOffsets[i].max.X, tank.wheel.rotatedOffsets[i].max.Y):RadRotate(-self.RotAngle);
		tank.wheel.rotatedOffsets[i].mid = tank.general.pos + Vector(xOffset, tank.suspension.length[i].mid):RadRotate(self.RotAngle);
		tank.wheel.unrotatedOffsets[i].mid = Vector(tank.wheel.rotatedOffsets[i].mid.X, tank.wheel.rotatedOffsets[i].mid.Y):RadRotate(-self.RotAngle);
	end
	
	--Suspension related positions
	if (tank.suspension.visualsType ~= VehicleFramework.SUSPENSION_VISUALS_TYPE.INVISIBLE) then
		local midDistanceToNextOffset;
		for i, unrotatedOffset in ipairs(tank.wheel.unrotatedOffsets) do
			tank.suspension.offsets.main[i] = Vector(unrotatedOffset.min.X, unrotatedOffset.min.Y - tank.suspension.length[i].min + tank.chassis.size.Y * 0.5):RadRotate(self.RotAngle);
			if (i ~= tank.wheel.count) then
				midDistanceToNextOffset = SceneMan:ShortestDistance(unrotatedOffset.min, tank.wheel.unrotatedOffsets[i + 1].min, SceneMan.SceneWrapsX) * 0.5;
				tank.suspension.offsets.midPoint[i] = Vector(unrotatedOffset.min.X + midDistanceToNextOffset.X, unrotatedOffset.min.Y + midDistanceToNextOffset.Y - tank.suspension.length[i].min + tank.chassis.size.Y * 0.5):RadRotate(self.RotAngle);
			end
		end
	end
end

--DEPRECATED
function VehicleFramework.updatePrimaryWheel(self, tank)
	local updatePrimaryWheelForAltitude; --NOTE: This is written as 2 lines to prevent a recursion bug. You MUST leave the first local definition separate from the function definition
	updatePrimaryWheelForAltitude = function(hFlipped, tank)
		if ((hFlipped and tank.wheel.primary == 1) or (not hFlipped and tank.wheel.primary == tank.wheel.count)) then
			return; --All wheels other than farthest back in air, let's just leave
		end
		
		if (tank.wheel.objects[tank.wheel.primary]:GetAltitude(0, tank.wheel.size * 0.5) - tank.wheel.size * 0.5 > tank.wheel.size) then
			tank.wheel.primary = hFlipped and tank.wheel.primary - 1 or tank.wheel.primary + 1;
			updatePrimaryWheelForAltitude(hFlipped, tank);
		end
	end

	tank.wheel.primary = self.HFlipped and tank.wheel.count or 1; --TODO try moving these lines to top of function
	updatePrimaryWheelForAltitude(self.HFlipped, tank); --Call recursive function to check if the primary wheel is in air and move it to the next if it is
end

--DEPRECATED
function VehicleFramework.roundVector(vector, numDecimalPlaces)
	local mult = 10 ^ (numDecimalPlaces or 0);
	return Vector(math.floor(vector.X * mult + 0.5) / mult, math.floor(vector.Y * mult + 0.5) / mult);
end

function VehicleFramework.updatePositionsVelocitiesAndRotations(self, tank)
	local wheelObject;
	for i, spring in ipairs(tank.suspension.springs) do
		wheelObject = tank.wheel.objects[i];
		
		wheelObject.AngularVel = tank.general.throttle;
		--At some point rot angle can go too high, reset it if it's past 360 for safety
		if (wheelObject.RotAngle > math.pi*2) then
			wheelObject.RotAngle = wheelObject.RotAngle - math.pi*2;
		elseif (wheelObject.RotAngle < -math.pi*2) then
			wheelObject.RotAngle = wheelObject.RotAngle + math.pi*2;
		end
		
		if (spring ~= nil) then
			tank.suspension.springs[i] = SpringFramework.update(spring);
			spring = tank.suspension.springs[i];
		end
		if (spring ~= nil) then
			if (spring.actionsPerformed[SpringFramework.SpringActions.OUTSIDE_OF_CONFINES]) then
			else
			end
			
			if (spring.actionsPerformed[SpringFramework.SpringActions.MOVE_INTO_ALIGNMENT]) then
			else
			end
			
			if (spring.actionsPerformed[SpringFramework.SpringActions.APPLY_FORCES]) then
			else
				wheelObject:MoveOutOfTerrain(6) --Sand
				if tank.general.vel.Magnitude < 5 and math.abs(tank.general.throttle) > tank.general.maxThrottle * 0.75 and math.abs(wheelObject.AngularVel) > tank.general.maxThrottle * 0.5 then
					--Check terrain strength at the wheel's position and its 4 center edges
					local erasableTerrain = {
						SceneMan:GetMaterialFromID(SceneMan:GetTerrMatter(wheelObject.Pos.X, wheelObject.Pos.Y)).Strength <= tank.general.maxErasableTerrainStrength and true or nil,
						SceneMan:GetMaterialFromID(SceneMan:GetTerrMatter(wheelObject.Pos.X - tank.wheel.size * 0.5, wheelObject.Pos.Y)).Strength <= tank.general.maxErasableTerrainStrength and true or nil,
						SceneMan:GetMaterialFromID(SceneMan:GetTerrMatter(wheelObject.Pos.X + tank.wheel.size * 0.5, wheelObject.Pos.Y)).Strength <= tank.general.maxErasableTerrainStrength and true or nil,
						SceneMan:GetMaterialFromID(SceneMan:GetTerrMatter(wheelObject.Pos.X, wheelObject.Pos.Y - tank.wheel.size * 0.5)).Strength <= tank.general.maxErasableTerrainStrength and true or nil,
						SceneMan:GetMaterialFromID(SceneMan:GetTerrMatter(wheelObject.Pos.X, wheelObject.Pos.Y + tank.wheel.size * 0.5)).Strength <= tank.general.maxErasableTerrainStrength and true or nil
					};
					if (#erasableTerrain > 3) then
						wheelObject:EraseFromTerrain() --Dislodge wheel if necessary
					end
				end
			end
		end
	end
	
	--Update chassis
	self:MoveOutOfTerrain(6) --Sand
	self.AngularVel = self.AngularVel * 0.5;
	
	local desired = SceneMan:ShortestDistance(tank.wheel.objects[tank.wheel.count].Pos, tank.wheel.objects[1].Pos, SceneMan.SceneWrapsX).AbsRadAngle;
	if (self.RotAngle < desired - tank.general.deceleration * 2) then
		self.RotAngle = self.RotAngle + tank.general.deceleration;
	elseif (self.RotAngle > desired + tank.general.deceleration * 2) then
		self.RotAngle = self.RotAngle - tank.general.deceleration;
	end
	
	if (not tank.general.isInAirLow) then
		if (tank.general.vel.Magnitude > tank.general.maxSpeed) then
			self.Vel = Vector(tank.general.vel.X, tank.general.vel.Y):SetMagnitude(tank.general.maxSpeed);
		elseif (not tank.general.isDriving) then
			if (tank.general.isStronglyDecelerating) then
				self.Vel = self.Vel * (1 - tank.general.deceleration * 10);
			else
				self.Vel = self.Vel * (1 - tank.general.deceleration);
			end
		
			if (self.Vel.Magnitude < tank.general.acceleration) then
				self.Vel = Vector(0, 0);
			end
		end
	end
end








--DEAD CODE BEYOND HERE EXCEPT SUSPENSION STUFF
function VehicleFramework.updatePositionsVelocitiesAndRotationsOld(self, tank)
	--Update wheels
	local rotatedWheelDeviation, unrotatedWheelDeviation, restrainedUnrotatedWheelDeviation, restrainedRotatedWheelDeviation;
	for i, wheelObject in ipairs(tank.wheel.objects) do
		--ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint("W"..tostring(i), tank.wheel.objects[i].Pos, Activity.TEAM_1, GameActivity.ARROWDOWN);
		--ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint("O"..tostring(i), tank.wheel.rotatedOffsets[i].min, Activity.TEAM_1, GameActivity.ARROWDOWN);
		--FrameMan:DrawLinePrimitive(Vector(tank.wheel.unrotatedOffsets[i].min.X - 2, tank.wheel.unrotatedOffsets[i].min.Y):RadRotate(-self.RotAngle), Vector(tank.wheel.unrotatedOffsets[i].min.X + 2, tank.wheel.unrotatedOffsets[i].min.Y):RadRotate(self.RotAngle), 0);
		--FrameMan:DrawLinePrimitive(Vector(tank.wheel.unrotatedOffsets[i].max.X - 2, tank.wheel.unrotatedOffsets[i].max.Y):RadRotate(-self.RotAngle), Vector(tank.wheel.unrotatedOffsets[i].max.X + 2, tank.wheel.unrotatedOffsets[i].max.Y):RadRotate(self.RotAngle), 0);
		FrameMan:DrawLinePrimitive(Vector(tank.wheel.rotatedOffsets[i].min.X - 3, tank.wheel.rotatedOffsets[i].min.Y - 1), Vector(tank.wheel.rotatedOffsets[i].min.X + 3, tank.wheel.rotatedOffsets[i].min.Y - 1), 5);
		FrameMan:DrawLinePrimitive(Vector(tank.wheel.rotatedOffsets[i].min.X - 3, tank.wheel.rotatedOffsets[i].min.Y), Vector(tank.wheel.rotatedOffsets[i].min.X + 3, tank.wheel.rotatedOffsets[i].min.Y), 5);
		FrameMan:DrawLinePrimitive(Vector(tank.wheel.rotatedOffsets[i].min.X - 3, tank.wheel.rotatedOffsets[i].min.Y + 1), Vector(tank.wheel.rotatedOffsets[i].min.X + 3, tank.wheel.rotatedOffsets[i].min.Y + 1), 5);
		
		FrameMan:DrawLinePrimitive(Vector(tank.wheel.rotatedOffsets[i].max.X - 3, tank.wheel.rotatedOffsets[i].max.Y - 1), Vector(tank.wheel.rotatedOffsets[i].max.X + 3, tank.wheel.rotatedOffsets[i].max.Y - 1), 5);
		FrameMan:DrawLinePrimitive(Vector(tank.wheel.rotatedOffsets[i].max.X - 3, tank.wheel.rotatedOffsets[i].max.Y), Vector(tank.wheel.rotatedOffsets[i].max.X + 3, tank.wheel.rotatedOffsets[i].max.Y), 5);
		FrameMan:DrawLinePrimitive(Vector(tank.wheel.rotatedOffsets[i].max.X - 3, tank.wheel.rotatedOffsets[i].max.Y + 1), Vector(tank.wheel.rotatedOffsets[i].max.X + 3, tank.wheel.rotatedOffsets[i].max.Y + 1), 5);
		
		FrameMan:DrawLinePrimitive(Vector(tank.wheel.rotatedOffsets[i].mid.X - 3, tank.wheel.rotatedOffsets[i].mid.Y - 1), Vector(tank.wheel.rotatedOffsets[i].mid.X + 3, tank.wheel.rotatedOffsets[i].mid.Y - 1), 5);
		FrameMan:DrawLinePrimitive(Vector(tank.wheel.rotatedOffsets[i].mid.X - 3, tank.wheel.rotatedOffsets[i].mid.Y), Vector(tank.wheel.rotatedOffsets[i].mid.X + 3, tank.wheel.rotatedOffsets[i].mid.Y), 5);
		FrameMan:DrawLinePrimitive(Vector(tank.wheel.rotatedOffsets[i].mid.X - 3, tank.wheel.rotatedOffsets[i].mid.Y + 1), Vector(tank.wheel.rotatedOffsets[i].mid.X + 3, tank.wheel.rotatedOffsets[i].mid.Y + 1), 5);
		
		FrameMan:DrawLinePrimitive(Vector(tank.wheel.objects[i].Pos.X - 25, tank.wheel.objects[i].Pos.Y), Vector(tank.wheel.objects[i].Pos.X + 25, tank.wheel.objects[i].Pos.Y), 151); 
	
		wheelObject.AngularVel = tank.general.throttle;
		if (wheelObject.RotAngle > math.pi*2 or wheelObject.RotAngle < -math.pi*2) then
			wheelObject.RotAngle = wheelObject.RotAngle - math.pi*2; --At some point rot angle can go too high, reset it if it's past 360 for safety
		end
		
		local deviationFromMin = SceneMan:ShortestDistance(tank.wheel.rotatedOffsets[i].min, wheelObject.Pos, SceneMan.SceneWrapsX);
		local deviationFromMax = SceneMan:ShortestDistance(tank.wheel.rotatedOffsets[i].max, wheelObject.Pos, SceneMan.SceneWrapsX);
		rotatedWheelDeviation = deviationFromMin.Magnitude < deviationFromMax.Magnitude and deviationFromMin or deviationFromMax;
		
			--print ("Rotangle: "..tostring(self.RotAngle)..", Wheel "..tostring(i).." pos: "..tostring(wheelObject.Pos)..", offsetMid: "..tostring(tank.wheel.rotatedOffsets[i].max)..", deviation: "..tostring(rotatedWheelDeviation)..".Mag: "..tostring(rotatedWheelDeviation.Magnitude));
		if (rotatedWheelDeviation.Magnitude > tank.wheel.size) then
			--print("RESETTING "..tostring(i));
			--print("Resetting Wheel "..tostring(i).." with deviation "..tostring(rotatedWheelDeviation));
			--self:FlashWhite(10);
			--wheelObject.Pos = tank.wheel.rotatedOffsets[i].min;
			--wheelObject:ClearForces();
			--ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint("R", tank.wheel.objects[i].Pos, Activity.TEAM_1, GameActivity.ARROWDOWN);
		--[[elseif (rotatedWheelDeviation.Magnitude > tank.wheel.minDeviationCorrection) then
			if (i ~= tank.wheel.primary) then
				unrotatedWheelDeviation = Vector(rotatedWheelDeviation.X, rotatedWheelDeviation.Y):RadRotate(-self.RotAngle);
				restrainedUnrotatedWheelDeviation = Vector(unrotatedWheelDeviation.X, math.max(tank.wheel.unrotatedOffsets.min[i], math.min(tank.wheel.unrotatedOffsets.max[i], unrotatedWheelDeviation.Y)));
				if (i ~= tank.wheel.primary) then
					restrainedRotatedWheelDeviation.X = 0;
				end
				wheelObject.Pos = tank.wheel.rotatedOffsets[i].min + restrainedRotatedWheelDeviation:RadRotate(self.RotAngle);
			end
			if tank.general.vel.Magnitude < 5 and math.abs(tank.general.throttle) > 9.9 and math.abs(wheelObject.AngularVel) > 7 then
				wheelObject:EraseFromTerrain()	--Dislodge wheel if necessary
				--TODO Add check for terrain hardness at wheel position, only erase if softer than passed in hardness
			end--]]
		elseif (rotatedWheelDeviation.Magnitude > (tank.wheel.size * 0.15)) then
			--wheelObject:MoveOutOfTerrain(6) --Sand
			
			
			if tank.general.vel.Magnitude < 5 and math.abs(tank.general.throttle) > tank.general.maxThrottle * 0.75 and math.abs(wheelObject.AngularVel) > tank.general.maxThrottle * 0.5 then
				--wheelObject:EraseFromTerrain() --Dislodge wheel if necessary
				--ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint("Erasing Terrain", tank.wheel.objects[i].Pos, Activity.TEAM_1, GameActivity.ARROWDOWN);
				--TODO Add check for terrain hardness at wheel position, only erase if softer than passed in hardness
			end
		else
				--ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint("Moving From Terrain", tank.wheel.objects[i].Pos, Activity.TEAM_1, GameActivity.ARROWDOWN);
				--wheelObject:MoveOutOfTerrain(6) --Sand
		end
			unrotatedWheelDeviation = Vector(rotatedWheelDeviation.X, rotatedWheelDeviation.Y):RadRotate(-self.RotAngle);
			if (i ~= tank.wheel.primary or (not tank.general.isDriving and math.abs(tank.general.throttle) < tank.general.maxThrottle * 0.2)) then
				local a = tank.wheel.rotatedOffsets[i].min + Vector(0, unrotatedWheelDeviation.Y):RadRotate(self.RotAngle);
				if (i == tank.wheel.primary and a.X ~= wheelObject.Pos.X and a.Y ~= wheelObject.Pos.Y) then
					--ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint(tostring(VehicleFramework.roundVector(wheelObject.Pos)).."->"..tostring(VehicleFramework.roundVector(a)), wheelObject.Pos - Vector(0, 10), Activity.TEAM_1, GameActivity.ARROWDOWN);
				end
				--wheelObject.Pos = a;
			end
		--wheelObject:MoveOutOfTerrain(6) --Sand
	end
	
	--Update chassis
	self:MoveOutOfTerrain(6) --Sand
	self.AngularVel = self.AngularVel * 0.5;
	local desired = SceneMan:ShortestDistance(tank.wheel.objects[tank.wheel.count].Pos, tank.wheel.objects[1].Pos, SceneMan.SceneWrapsX).AbsRadAngle;
	if (self.RotAngle < desired - tank.general.deceleration * 2) then
		self.RotAngle = self.RotAngle + tank.general.deceleration;
	elseif (self.RotAngle > desired + tank.general.deceleration * 2) then
		self.RotAngle = self.RotAngle - tank.general.deceleration;
	end
	self.RotAngle = 0;
	--self.RotAngle = SceneMan:ShortestDistance(tank.wheel.objects[tank.wheel.count].Pos, tank.wheel.objects[1].Pos, SceneMan.SceneWrapsX).AbsRadAngle;
	
	if (not tank.general.isInAirLow) then
		if (tank.general.vel.Magnitude > tank.general.maxSpeed) then
			self.Vel = Vector(tank.general.vel.X, tank.general.vel.Y):SetMagnitude(tank.general.maxSpeed);
		elseif (not tank.general.isDriving) then
			if (tank.general.isStronglyDecelerating) then
				self.Vel = self.Vel * (1 - tank.general.deceleration * 10);
			else
				self.Vel = self.Vel * (1 - tank.general.deceleration);
			end
		
			if (self.Vel.Magnitude < tank.general.acceleration) then
				self.Vel = Vector(0, 0);
			end
		end
	end
end

function VehicleFramework.updateForces(self, tank)
	local unrotatedWheelPosition, deviation, horizontalDeviation, verticalDeviation, verticalDeviationPastSuspensionMaxLength, maxForceStrength, forceStrength, adjustedForceStrength, forceVector;
	
	local chassisForces = {};
	for i, wheelObject in ipairs(tank.wheel.objects) do
		unrotatedWheelPosition = Vector(wheelObject.Pos.X, wheelObject.Pos.Y):RadRotate(-self.RotAngle);
		deviation = SceneMan:ShortestDistance(tank.wheel.unrotatedOffsets[i].min, unrotatedWheelPosition, SceneMan.SceneWrapsX);
		
		local wheelForces = {};
		--Add horizontal force to chassis based on primary wheel's X deviation
		if (i == tank.wheel.primary) then
			horizontalDeviation = Vector(deviation.X, 0);
			local unrotatedVelocity = Vector(self.Vel.X, self.Vel.Y):RadRotate(-self.RotAngle);
			local forceOpposesThrottleDirection = true;--(horizontalDeviation.X > 0 and tank.general.throttle < 0) or (horizontalDeviation.X < 0 and tank.general.throttle > 0);
			
			--local forceOpposesThrottleDirection = (horizontalDeviation.X > 0 and unrotatedVelocity.X < 0) or (horizontalDeviation.X < 0 and unrotatedVelocity.X > 0);
			if ((forceOpposesThrottleDirection) and horizontalDeviation.Magnitude > tank.chassis.horizontalDeviationCorrectionThreshold) then
				forceStrength = (horizontalDeviation.Magnitude * tank.chassis.horizontalDeviationCorrectionMult)^2;
				maxForceStrength = tank.suspension.maxForceBeforeMass * self.Mass;
				adjustedForceStrength = math.min(maxForceStrength, forceStrength * self.Mass);
				forceVector = Vector(adjustedForceStrength, 0):RadRotate(Vector(horizontalDeviation.X, horizontalDeviation.Y):RadRotate(self.RotAngle).AbsRadAngle);
				--self:AddForce(forceVector, Vector(0, 0));
				--table.insert(chassisForces, {adjustedForceStrength = adjustedForceStrength, forceVector = forceVector, maxForceStrength = maxForceStrength});
				
				--LINES
					local forceLine = Vector(forceVector.X, forceVector.Y):SetMagnitude(100 * adjustedForceStrength/maxForceStrength);
					local drawStartPos = self.Pos + Vector(tank.chassis.size.X * 0.5, 0):RadRotate(self.RotAngle) * (horizontalDeviation.X < 0 and -1 or 1);
					--VehicleFramework.drawLines(drawStartPos, drawStartPos + forceLine, self.RotAngle, tank, adjustedForceStrength == maxForceStrength and 254 or 0);
					--FrameMan:DrawTextPrimitive(drawStartPos + forceLine, tostring(VehicleFramework.roundVector(forceVector)), true, 1);
				--LINES
				
				forceStrength = (horizontalDeviation.Magnitude * tank.suspension.stiffness)^2;
				maxForceStrength = tank.suspension.maxForceBeforeMass * wheelObject.Mass;
				adjustedForceStrength = math.min(maxForceStrength, forceStrength * wheelObject.Mass);
				forceVector = Vector(adjustedForceStrength, 0):RadRotate(Vector(horizontalDeviation.X, horizontalDeviation.Y):RadRotate(self.RotAngle + math.pi).AbsRadAngle);
				--wheelObject:AddForce(forceVector, Vector(0, 0));
				table.insert(wheelForces, {adjustedForceStrength = adjustedForceStrength, forceVector = forceVector, maxForceStrength = maxForceStrength});
				
				--print("RotAngle: "..tostring(self.RotAngle)..", horizontalDeviation: "..tostring(horizontalDeviation)..", rotated is "..tostring(horizontalDeviation):RadRotate(self.RotAngle + math.pi).." gives angle "..tostring(horizontalDeviation:RadRotate(self.RotAngle + math.pi).)
				
				--LINES
					forceLine = Vector(forceVector.X, forceVector.Y):SetMagnitude(50 * adjustedForceStrength/maxForceStrength);
					drawStartPos = Vector(wheelObject.Pos.X, wheelObject.Pos.Y);
					--VehicleFramework.drawLines(drawStartPos, drawStartPos + forceLine, self.RotAngle, tank, adjustedForceStrength == maxForceStrength and 254 or 0);
					--FrameMan:DrawTextPrimitive(drawStartPos + forceLine, tostring(VehicleFramework.roundVector(forceVector)), true, 1);
				--LINES
			end
		end
			
		verticalDeviationPastSuspensionMaxLength = math.min(tank.suspension.length[i].difference, math.max(0, deviation.Y - tank.suspension.length[i].difference));
		verticalDeviation = Vector(0, math.min(tank.suspension.length[i].difference, math.max(0, deviation.Y)));
		
		forceStrength = verticalDeviationPastSuspensionMaxLength > 0 and
			math.floor(10000 * (verticalDeviationPastSuspensionMaxLength/tank.suspension.length[i].difference * tank.suspension.stiffness)^2)/10000 or
			math.floor(10000 * ((tank.suspension.length[i].difference - verticalDeviation.Y)/tank.suspension.length[i].difference * tank.suspension.stiffness)^2)/10000;
			
		
			if (forceStrength > 0 and deviation.Magnitude > tank.wheel.size * 0.15) then
				maxForceStrength = 10*tank.suspension.maxForceBeforeMass * wheelObject.Mass;
				adjustedForceStrength = math.min(maxForceStrength, forceStrength * wheelObject.Mass);
				if i == 2 then
				--print("adjusted force strength is "..tostring(verticalDeviationPastSuspensionMaxLength > 0 and -adjustedForceStrength or adjustedForceStrength).." of "..tostring(maxForceStrength));
				end
				forceVector = Vector(0, verticalDeviationPastSuspensionMaxLength > 0 and -adjustedForceStrength or adjustedForceStrength):RadRotate(self.RotAngle);
				wheelObject:AddForce(forceVector, Vector(0, 0));
				--table.insert(wheelForces, {adjustedForceStrength = adjustedForceStrength, forceVector = forceVector, maxForceStrength = maxForceStrength})
				
				--LINES
					local forceLine = Vector(forceVector.X, forceVector.Y):SetMagnitude(50 * adjustedForceStrength/maxForceStrength);
					local drawStartPos = wheelObject.Pos + Vector(0, 13.5 * (verticalDeviationPastSuspensionMaxLength > 0 and -1 or 1)):RadRotate(self.RotAngle);
					VehicleFramework.drawLines(drawStartPos, drawStartPos + forceLine, self.RotAngle, tank, adjustedForceStrength == maxForceStrength and 254 or 0);
					--FrameMan:DrawTextPrimitive(drawStartPos + forceLine, tostring(VehicleFramework.roundVector(forceVector)), true, 1);
				--LINES
				
			local rotatedWheelDeviation = SceneMan:ShortestDistance(tank.wheel.rotatedOffsets[i].min, wheelObject.Pos, SceneMan.SceneWrapsX);
			local unrotatedWheelDeviation = Vector(rotatedWheelDeviation.X, rotatedWheelDeviation.Y):RadRotate(-self.RotAngle);
			if (i ~= tank.wheel.primary or (not tank.general.isDriving and math.abs(tank.general.throttle) < tank.general.maxThrottle * 0.2)) then
				local a = tank.wheel.rotatedOffsets[i].min + Vector(0, unrotatedWheelDeviation.Y):RadRotate(self.RotAngle);
				--if (i == tank.wheel.primary and a.X ~= wheelObject.Pos.X and a.Y ~= wheelObject.Pos.Y) then
					--ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint(tostring(VehicleFramework.roundVector(wheelObject.Pos)).."->"..tostring(VehicleFramework.roundVector(a)), wheelObject.Pos - Vector(0, 10), Activity.TEAM_1, GameActivity.ARROWDOWN);
				--end
				wheelObject.Pos = a;
			end
			
			elseif (forceStrength <= 0 or deviation.Magnitude <= tank.wheel.size * 0.15) then
				--wheelObject:MoveOutOfTerrain(6);
				--ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint("M", tank.wheel.objects[i].Pos, Activity.TEAM_1, GameActivity.ARROWDOWN);
			end
			
			
	maxForceStrength = 0;
	adjustedForceStrength = 0;
	forceVector = Vector(0, 0);
	for _, wheelForce in ipairs(wheelForces) do
		maxForceStrength = maxForceStrength + wheelForce.maxForceStrength;
		adjustedForceStrength = adjustedForceStrength + wheelForce.adjustedForceStrength;
		forceVector = forceVector + wheelForce.forceVector;
	end
	if (forceVector.Magnitude > 0) then
		--self:AddForce(forceVector, Vector(0, 0));
		
		local forceLine = Vector(forceVector.X, forceVector.Y):SetMagnitude(100 * adjustedForceStrength/maxForceStrength);
		local drawStartPos = Vector(wheelObject.Pos.X, wheelObject.Pos.Y);
		--VehicleFramework.drawLines(drawStartPos, drawStartPos + forceLine, self.RotAngle, tank, adjustedForceStrength == maxForceStrength and 254 or 0);
		
		
	end
			
			
			
		if (forceStrength > 0) then
			if (verticalDeviationPastSuspensionMaxLength == 0) then
				maxForceStrength = tank.suspension.maxForceBeforeMass * self.Mass;
				adjustedForceStrength = math.min(maxForceStrength, forceStrength * self.Mass);
				forceVector = Vector(0, -adjustedForceStrength):RadRotate(self.RotAngle);
				table.insert(chassisForces, {adjustedForceStrength = adjustedForceStrength, forceVector = forceVector, maxForceStrength = maxForceStrength});
				--self:AddForce(forceVector, Vector(0, 0));
				
				--LINES
					local forceLine = Vector(forceVector.X, forceVector.Y):SetMagnitude(100 * adjustedForceStrength/maxForceStrength);
					local drawStartPos = Vector(unrotatedWheelPosition.X, Vector(self.Pos.X, self.Pos.Y):RadRotate(-self.RotAngle).Y):RadRotate(self.RotAngle);
					--VehicleFramework.drawLines(drawStartPos, drawStartPos + forceLine, self.RotAngle, tank, adjustedForceStrength == maxForceStrength and 254 or 0);
					--FrameMan:DrawTextPrimitive(drawStartPos + forceLine, tostring(VehicleFramework.roundVector(forceVector)), true, 1);
				--LINES
			end
		end
	end
	
	maxForceStrength = 0;
	adjustedForceStrength = 0;
	forceVector = Vector(0, 0);
	for _, chassisForce in ipairs(chassisForces) do
		maxForceStrength = maxForceStrength + chassisForce.maxForceStrength;
		adjustedForceStrength = adjustedForceStrength + chassisForce.adjustedForceStrength;
		forceVector = forceVector + chassisForce.forceVector;
	end
	if (forceVector.Magnitude > 0) then
	print("Total Chassis Force: "..tostring(adjustedForceStrength));
		self:AddForce(forceVector, Vector(0, 0));
		
		local forceLine = Vector(forceVector.X, forceVector.Y):SetMagnitude(100 * adjustedForceStrength/maxForceStrength);
		local drawStartPos = Vector(self.Pos.X, self.Pos.Y);
		VehicleFramework.drawLines(drawStartPos, drawStartPos + forceLine, self.RotAngle, tank, adjustedForceStrength == maxForceStrength and 254 or 0);
	end
--[[

	local deviation, forceStrength, forceVector;
	--Add wheel forces
	for i, wheelObject in ipairs(tank.wheel.objects) do
		deviation = SceneMan:ShortestDistance(tank.wheel.rotatedOffsets[i].min, wheelObject.Pos, SceneMan.SceneWrapsX);
		
		local forceStrength = math.min(deviation.Magnitude * 1000, 4000); --Fix this 4000
		local forceVector = Vector(forceStrength, 0):RadRotate(deviation.AbsRadAngle + math.pi);
		wheelObject:AddForce(forceVector, Vector(0,0));
	end

	--Add chassis forces
	for i, wheelObject in ipairs(tank.wheel.objects) do
		--Add "horizontal" force to the chassis to make sure the primary wheel matches up with its offset
		if (i == tank.wheel.primary) then
			deviation = SceneMan:ShortestDistance(tank.wheel.unrotatedOffsets[i], Vector(wheelObject.Pos.X, wheelObject.Pos.Y):RadRotate(-self.RotAngle), SceneMan.SceneWrapsX);
			deviation.Y = 0;
			
			--Instead of caring about mid extension, calculate min and max positions rotated and unrotated
			--Wheels shouldn't be able to go "above" min position or "below" max position. Force applied to wheels are strongest when at min position and 0 when at max position. Only has y component, no X
			--Chassis gets a horizontal force applied to it based on how deviated the primary wheel is (to keep shape). Additionally it gets the reverse of the force on the wheels applied to it from each suspension's min position
			
			--Use same formula (different signs) to simulate suspension forces on body and wheels
			--		wheels get pushed down more if less extended and less if more extended, body gets pushed up in same way.
			--Also make sure body forces are position, probably put them at body height with wheel position x (or wheel offset x) rotated back into place
			
			--deviation = SceneMan:ShortestDistance(tank.wheel.rotatedOffsets[i], wheelObject.Pos, SceneMan.SceneWrapsX);
			--print("Rotated deviation: "..tostring(deviation)..", unrotatedDeviation: "..tostring(a)..", derotatedDeviation: "..tostring(deviation:RadRotate(-self.RotAngle)));
			if (deviation.Magnitude > tank.chassis.horizontalDeviationCorrectionThreshold) then
				forceStrength = math.min(deviation.Magnitude ^ 2 * self.Mass * tank.chassis.horizontalDeviationCorrectionMult, tank.suspension.maxForce);
				forceVector = Vector(forceStrength, 0):RadRotate(deviation:RadRotate(self.RotAngle).AbsRadAngle);
				
				local forceLine = Vector(forceVector.X, forceVector.Y):SetMagnitude(30 + 30 * (forceStrength / tank.suspension.maxForce));
				VehicleFramework.drawLines(wheelObject.Pos, wheelObject.Pos + forceLine, self.RotAngle, tank, 0);
				--self:AddForce(forceVector, SceneMan:ShortestDistance(self.Pos, wheelObject.Pos, SceneMan.SceneWrapsX));
				self:AddForce(forceVector, Vector(0, 0));
			end
		end
		
		--Add "vertical" force to the chassis based on wheel extension
		
	end--]]
	--[[
	local averageWheelPosition = Vector(0,0);
	for _, wheelObject in ipairs(tank.wheel.objects) do
		averageWheelPosition = averageWheelPosition + wheelObject.Pos;
	end
	averageWheelPosition = averageWheelPosition/tank.wheel.count;
	--averageWheelPosition = averageWheelPosition + SceneMan:ShortestDistance(tank.wheel.rotatedOffsets[tank.wheel.primary], tank.wheel.objects[tank.wheel.primary].Pos, SceneMan.SceneWrapsX);
	print ("Average wheel position is "..tostring(averageWheelPosition));
	ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint("AWP", averageWheelPosition, Activity.TEAM_1, GameActivity.ARROWDOWN);
	
	
	local suspensionMidOffset = Vector(0, tank.suspension.midLength):RadRotate(self.RotAngle + math.pi);
	local suspensionMidPosition = suspensionMidOffset - tank.general.pos;
	local expectedPositionFromWheels = averageWheelPosition + suspensionMidPosition;
	ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint("P: "..tostring(expectedPositionFromWheels), expectedPositionFromWheels, Activity.TEAM_1, GameActivity.ARROWDOWN);
	
	local abcGood = Vector(tank.general.pos.X, tank.suspension.midLength):RadRotate(self.RotAngle + math.pi) - tank.general.pos;
	local abcBad = SceneMan:ShortestDistance(tank.general.pos, Vector(tank.general.pos.X, tank.suspension.midLength):RadRotate(self.RotAngle + math.pi), SceneMan.SceneWrapsX);
	--print ("abcGood: "..tostring(abcGood)..", abcBad: "..tostring(abcBad));
	
	
	
	
	local chassisDeviation = averageWheelPosition + Vector(0, tank.suspension.midLength):RadRotate(self.RotAngle + math.pi) - tank.general.pos;
	--local chassisDeviation = averageWheelPosition +  SceneMan:ShortestDistance(tank.general.pos, Vector(0, tank.suspension.midLength):RadRotate(self.RotAngle + math.pi), SceneMan.SceneWrapsX);
	if (chassisDeviation.Magnitude > 1) then
		local forceStrength = math.min(chassisDeviation.Magnitude^2 * self.Mass * tank.suspension.stiffness, 140000);
		local forceVector = Vector(0,0) + Vector(forceStrength, 0):RadRotate(chassisDeviation.AbsRadAngle);
		--ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint("chassisDeviation: "..tostring(chassisDeviation)..", forceStrength: "..tostring(forceStrength)..", forceVector: "..tostring(forceVector)..", Angle: "..tostring(forceVector.AbsDegAngle), self.AboveHUDPos, Activity.TEAM_1, GameActivity.ARROWDOWN);
		self:AddForce(forceVector, Vector(0,0));
	end
	--]]
end









function VehicleFramework.updateWheels(hFlipped, rotAngle, tank)
	local wheelOffset, rotatedWheelDeviation, unrotatedWheelDeviation, restrainedRotatedWheelDeviation;
	
	for i, wheelObject in ipairs(tank.wheel.objects) do
		wheelObject.AngularVel = tank.general.throttle;
	
		wheelOffset = tank.wheel.rotatedOffsets[i];
		rotatedWheelDeviation = SceneMan:ShortestDistance(wheelOffset, wheelObject.Pos, SceneMan.SceneWrapsX);
		
		------------------------
		--[[CC COORDINATE SYSTEM--
		------------------------
		Positions - Top left is (0, 0)
			X increases towards right
			Y increases downwards
		Directions - Start due right and go counterclockwise
			(1, 0) = 0° or 0 rads
			(1, -1) = 45° or pi/4 rads
			(0, -1) = 90° or pi/2 rads
			(-1, -1) = 135° or 3pi/4 rads
			(-1, 0) = 180° or pi rads
			(-1, 1) = 225° or 5pi/4 rads
			(0, 1) = -90° = 270° or 3pi/2 rads
			(1, 1) = -45° = 315° or 7pi/4 rads
		--]]
		
		--Each wheel should naturally sag to its max extension
		--When a wheel hits something, it gets pushed up to its min suspension
		--When it reaches that min, it affects the chassis' rot angle and forces applied
		
		--every frame, need to take wheel pos - wheel offset pos to get difference
		--Then rotate it back to vertical (use -self.RotAngle)
		--Now figure out the force to apply to move it so its X would be 0
		--Then rotate the direction with rot angle and apply it
		
		--For chassis, need to measure displacement of each wheel from offset (they'll be clamped into vertical so don't worry about frame of reference)
		--Now we apply force to the chassis whose strength is based on the various wheels' extension levels, so ones that are at minimum apply most force and ones at max apply none
		
		if (rotatedWheelDeviation.Magnitude > tank.wheel.maxDeviationCorrection) then
			wheelObject.Pos = wheelOffset;
			wheelObject:ClearForces();
		elseif (rotatedWheelDeviation.Magnitude > tank.wheel.minDeviationCorrection) then
			unrotatedWheelDeviation = Vector(rotatedWheelDeviation.X, rotatedWheelDeviation.Y):RadRotate(-rotAngle);
			restrainedRotatedWheelDeviation = Vector(0, unrotatedWheelDeviation.Y):RadRotate(rotAngle);
			--local myForce = restrainedRotatedWheelDeviation * wheelObject.Mass;
			--wheelObject:AddForce(myForce, Vector(0, 0));
			
			--Abdul's code is trying to move the wheel back to the offset
			--If the wheel is being squished in it's above the offset (so rotatedWheelDeviation.Y < 0) so the force is being added downwards
		
			
			local forceStrength = math.min(rotatedWheelDeviation.Magnitude * 1000, 4000);
			local forceAngle = rotatedWheelDeviation.AbsRadAngle + math.pi; --Add 180 degrees to this to compensate for cc's coordinate system I guess
			--local forceAngle = rotatedWheelDeviation.Y > 0 and rotAngle + math.pi * 0.5 or rotAngle - math.pi * 0.5;
			local forceVector = Vector(0, 0) + Vector(forceStrength, 0):RadRotate(forceAngle);
			wheelObject:AddForce(forceVector, Vector(0,0));
			
			if (i ~= tank.wheel.primary) then
				wheelObject.Pos = wheelOffset + restrainedRotatedWheelDeviation;
			end
			
			
			if (i == tank.wheel.primary) then
				--print ("Y deviation "..tostring(rotatedWheelDeviation.Y)..", rotAngle "..tostring(rotAngle  * 180 / math.pi)..", forceAngle "..tostring(forceAngle * 180 / math.pi));
				--print ("WD: "..tostring(rotatedWheelDeviation)..", WDRot: "..tostring(unrotatedWheelDeviation)..", WDRes: "..tostring(restrainedRotatedWheelDeviation)..", Wheel Pos diff  "..tostring(wheelObject.Pos)..", Force: "..tostring(myForce))
				--print ("Abdul's force angle: "..tostring(forceAngle * 180 / math.pi).." and vector "..tostring(forceVector));
				--ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint("Wheel expected here", wheelOffset, Activity.TEAM_1, GameActivity.ARROWDOWN);
				--ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint("Wheel found here, deviation magnitude is "..tostring(rotatedWheelDeviation.Magnitude), wheelObject.Pos, Activity.TEAM_1, GameActivity.ARROWUP);
				--ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint("Wheel deviation: "..tostring(rotatedWheelDeviation)..", Rotated: "..tostring(unrotatedWheelDeviation), wheelObject.Pos - Vector(0, 30), Activity.TEAM_1, GameActivity.ARROWDOWN);
			end
			
			--self.Wheels[i]:AddForce(VehicleFramework.AddDistanceAsRotatedVector(Vector(0,0), Tmp.AbsRadAngle + 3.141592, Tmp.Magnitude * multi), Vector(0,0))
			--local Tmp2 = Vector(0, Tmp.Y); --This hacky shit sets your x vector to 0
			--self.Wheels[i].Pos = self.WhOfst[i] + self:RotateOffset(Tmp2); --This hacky shit forces your wheel to the right spot cause I didn't wanna deal with forces
			
			if tank.general.vel.Magnitude < 5 and math.abs(tank.general.throttle) > 9.9 and math.abs(wheelObject.AngularVel) > 7 then
				
				--if (i == tank.wheel.primary) then
				--	ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint("Erasing terrain", wheelObject.Pos, Activity.TEAM_1, GameActivity.ARROWDOWN);
				--end
				wheelObject:EraseFromTerrain()	--Dislodge wheel if necessary
			end
		else
			--if (i == i == tank.wheel.primary) then
			--	ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint("Leaving terrain", wheelObject.Pos, Activity.TEAM_1, GameActivity.ARROWDOWN);
			--end
			wheelObject:MoveOutOfTerrain(6) --Sand
		end
	end
end

function VehicleFramework.updateChassis(self, tank)
	self:MoveOutOfTerrain(6) --Sand
	self.AngularVel = self.AngularVel * 0.5;
	self.RotAngle = SceneMan:ShortestDistance(tank.wheel.objects[tank.wheel.count].Pos, tank.wheel.objects[1].Pos, SceneMan.SceneWrapsX).AbsRadAngle;
	
	if tank.general.vel.Magnitude > tank.general.maxSpeed then
		self.Vel = Vector(tank.general.vel.X, tank.general.vel.Y):SetMagnitude(tank.general.maxSpeed);
	else
		self.Vel = self.Vel * (1 - tank.general.deceleration);
	end
	
	--Apply forces to chassis based on wheel extension
	local deviation, forceStrength, forceVector;
	for i, wheelObject in ipairs(tank.wheel.objects) do
		--Add "horizontal" force to the chassis to make sure the primary wheel matches up with its offset
		if (i == tank.wheel.primary) then
			deviation = SceneMan:ShortestDistance(tank.wheel.unrotatedOffsets[i], Vector(wheelObject.Pos.X, wheelObject.Pos.Y):RadRotate(-self.RotAngle), SceneMan.SceneWrapsX);
			deviation.Y = 0;
			
			--Move all force stuff into one function and all rotation/vel stuff into one function
			--Use same formula (different signs) to simulate suspension forces on body and wheels
			--		wheels get pushed down more if less extended and less if more extended, body gets pushed up in same way.
			--Also make sure body forces are position, probably put them at body height with wheel position x (or wheel offset x) rotated back into place
			
			--deviation = SceneMan:ShortestDistance(tank.wheel.rotatedOffsets[i], wheelObject.Pos, SceneMan.SceneWrapsX);
			--print("Rotated deviation: "..tostring(deviation)..", unrotatedDeviation: "..tostring(a)..", derotatedDeviation: "..tostring(deviation:RadRotate(-self.RotAngle)));
			if (deviation.Magnitude > tank.chassis.horizontalDeviationCorrectionThreshold) then
				forceStrength = math.min(deviation.Magnitude ^ 2 * self.Mass * tank.chassis.horizontalDeviationCorrectionMult, tank.suspension.maxForce);
				forceVector = Vector(forceStrength, 0):RadRotate(deviation:RadRotate(self.RotAngle).AbsRadAngle);
				
				local forceLine = Vector(forceVector.X, forceVector.Y):SetMagnitude(30 + 30 * (forceStrength / tank.suspension.maxForce));
				VehicleFramework.drawLines(wheelObject.Pos, wheelObject.Pos + forceLine, self.RotAngle, tank, 0);
				--self:AddForce(forceVector, SceneMan:ShortestDistance(self.Pos, wheelObject.Pos, SceneMan.SceneWrapsX));
				self:AddForce(forceVector, Vector(0, 0));
			end
		end
		
		--Add "vertical" force to the chassis based on wheel extension
		
	end
	--[[
	local averageWheelPosition = Vector(0,0);
	for _, wheelObject in ipairs(tank.wheel.objects) do
		averageWheelPosition = averageWheelPosition + wheelObject.Pos;
	end
	averageWheelPosition = averageWheelPosition/tank.wheel.count;
	--averageWheelPosition = averageWheelPosition + SceneMan:ShortestDistance(tank.wheel.rotatedOffsets[tank.wheel.primary], tank.wheel.objects[tank.wheel.primary].Pos, SceneMan.SceneWrapsX);
	print ("Average wheel position is "..tostring(averageWheelPosition));
	ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint("AWP", averageWheelPosition, Activity.TEAM_1, GameActivity.ARROWDOWN);
	
	
	local suspensionMidOffset = Vector(0, tank.suspension.midLength):RadRotate(self.RotAngle + math.pi);
	local suspensionMidPosition = suspensionMidOffset - tank.general.pos;
	local expectedPositionFromWheels = averageWheelPosition + suspensionMidPosition;
	ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint("P: "..tostring(expectedPositionFromWheels), expectedPositionFromWheels, Activity.TEAM_1, GameActivity.ARROWDOWN);
	
	local abcGood = Vector(tank.general.pos.X, tank.suspension.midLength):RadRotate(self.RotAngle + math.pi) - tank.general.pos;
	local abcBad = SceneMan:ShortestDistance(tank.general.pos, Vector(tank.general.pos.X, tank.suspension.midLength):RadRotate(self.RotAngle + math.pi), SceneMan.SceneWrapsX);
	--print ("abcGood: "..tostring(abcGood)..", abcBad: "..tostring(abcBad));
	
	
	
	
	local chassisDeviation = averageWheelPosition + Vector(0, tank.suspension.midLength):RadRotate(self.RotAngle + math.pi) - tank.general.pos;
	--local chassisDeviation = averageWheelPosition +  SceneMan:ShortestDistance(tank.general.pos, Vector(0, tank.suspension.midLength):RadRotate(self.RotAngle + math.pi), SceneMan.SceneWrapsX);
	if (chassisDeviation.Magnitude > 1) then
		local forceStrength = math.min(chassisDeviation.Magnitude^2 * self.Mass * tank.suspension.stiffness, 140000);
		local forceVector = Vector(0,0) + Vector(forceStrength, 0):RadRotate(chassisDeviation.AbsRadAngle);
		--ToGameActivity(ActivityMan:GetActivity()):AddObjectivePoint("chassisDeviation: "..tostring(chassisDeviation)..", forceStrength: "..tostring(forceStrength)..", forceVector: "..tostring(forceVector)..", Angle: "..tostring(forceVector.AbsDegAngle), self.AboveHUDPos, Activity.TEAM_1, GameActivity.ARROWDOWN);
		self:AddForce(forceVector, Vector(0,0));
	end
	--]]
end

function VehicleFramework.updateSuspension(self, tank)
	if (tank.suspension.visualsType == VehicleFramework.SUSPENSION_VISUALS_TYPE.DRAWN) then
		VehicleFramework.updateDrawnSuspension(self, tank);
	elseif (tank.suspension.visualsType == VehicleFramework.SUSPENSION_VISUALS_TYPE.SPRITE) then
		VehicleFramework.updateSpriteSuspension(self, tank);
	end
end

function VehicleFramework.updateDrawnSuspension(self, tank)
	for i, wheelObject in ipairs(tank.wheel.objects) do
		VehicleFramework.drawLines(tank.suspension.offsets.main[i], Vector(wheelObject.Pos.X, wheelObject.Pos.Y), self.RotAngle, tank);
		if (i ~= 1) then
			VehicleFramework.drawLines(tank.suspension.offsets.midPoint[i - 1], Vector(wheelObject.Pos.X, wheelObject.Pos.Y), self.RotAngle, tank);
		end
		if (i ~= tank.wheel.count) then
			VehicleFramework.drawLines(tank.suspension.offsets.midPoint[i], wheelObject.Pos, self.RotAngle, tank);
		end
	end
end

function VehicleFramework.drawLines(startPos, endPos, rotAngle, tank, colourIndex)
	local lineAngle = (SceneMan:ShortestDistance(startPos, endPos, SceneMan.SceneWrapsX).AbsDegAngle + (360))%(360);
	local isHorizontal = (lineAngle >= 315 or lineAngle <= 45) or (lineAngle >= 135 and lineAngle <= 225);
	local isVertical = (lineAngle >= 45 and lineAngle <= 135) or (lineAngle >= 225 and lineAngle <= 315);
	local evenLineCount = tank.suspension.visualsConfig.width % 2 == 0;
	local midCount = math.ceil(tank.suspension.visualsConfig.width * 0.5);
	local rotatedStartPos = Vector(startPos.X, startPos.Y):RadRotate(-rotAngle);
	colourIndex = colourIndex or tank.suspension.visualsConfig.colourIndex;

	for i = 1, tank.suspension.visualsConfig.width + (evenLineCount and 1 or 0) do
		if (i == midCount) then
			if (evenLineCount == false) then
				FrameMan:DrawLinePrimitive(startPos, endPos, colourIndex);
			end
		else
			FrameMan:DrawLinePrimitive(Vector(rotatedStartPos.X - (isVertical and (midCount - i) or 0), rotatedStartPos.Y - (isHorizontal and (midCount - i) or 0)):RadRotate(rotAngle), endPos, colourIndex);
		end
	end
end

function VehicleFramework.updateSpriteSuspension(self, tank)
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
	--]
	

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