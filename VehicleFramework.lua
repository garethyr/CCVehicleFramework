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
		--Need to be fairly precise about this or it might cause a false positive
		tank.general.isInAir = self:GetAltitude(0, 10) > 2 * (tank.wheel.size + tank.suspension.longest.max);
		
		VehicleFramework.updateThrottle(tank);
		
		VehicleFramework.updateSprings(self.tank);
		
		VehicleFramework.updateWheels(self.tank);
		
		if (not tank.general.isInAir) then
			VehicleFramework.updateChassis(self, self.tank);
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

	for i, wheelObject in ipairs(tank.wheel.objects) do
		wheelObject.AngularVel = tank.general.throttle;
		
		end
		
		end
	end
end

	
	end
	
		end
	
		end
	end
end

		end
	end

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