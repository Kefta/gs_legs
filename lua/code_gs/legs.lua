gs.LoadDependency("code_gs/lib", "gs_legs", "gs_lib")

-- Optional
local bEntities = gs.AddonLoaded("code_gs/entities") or gs.LoadAddon("code_gs/entities")

if (SERVER) then
	return
end

local pairs = pairs
local Angle = Angle
local EyePos = EyePos
local EyeAngles = EyeAngles
local CreateConVar = CreateConVar
local ClientsideModel = ClientsideModel
local LocalOrSpectatorEntity = LocalOrSpectatorEntity

local math_sin = math.sin
local math_cos = math.cos
local math_rad = math.rad
local math_Clamp = math.Clamp
local string_lower = string.lower
local gs_CheckType = gs.CheckType
local gs_CheckEntityValid = gs.CheckEntityValid
local render_EnableClipping = render.EnableClipping
local render_PopCustomClipPlane = render.PopCustomClipPlane
local render_PushCustomClipPlane = render.PushCustomClipPlane

gs.legs = {
	m_pLegs = NULL,
	m_nCallback = -1
}

gs.legs.OffsetLimits = {
	Min = -50,
	Max = 0
}

-- https://github.com/garrynewman/garrysmod/pull/1347
gs.legs.OverrideModels = {
	["models/weapons/c_medkit.mdl"] = 0,
	["models/weapons/c_toolgun.mdl"] = 0,
	["models/weapons/v_toolgun.mdl"] = 0
}

do
	local function BaseBones()
		return {
			["ValveBiped.Bip01_Pelvis"] = true,
			["ValveBiped.Bip01_Spine"] = true,
			["ValveBiped.Bip01_Spine1"] = true,
			["ValveBiped.Bip01_Spine2"] = true,
			["ValveBiped.Bip01_Spine4"] = true,
			["ValveBiped.Bip01_R_Thigh"] = true,
			["ValveBiped.Bip01_R_Calf"] = true,
			["ValveBiped.Bip01_R_Foot"] = true,
			["ValveBiped.Bip01_R_Toe0"] = true,
			["ValveBiped.Bip01_L_Thigh"] = true,
			["ValveBiped.Bip01_L_Calf"] = true,
			["ValveBiped.Bip01_L_Foot"] = true,
			["ValveBiped.Bip01_L_Toe0"] = true,
			["ValveBiped.Jacket1_bone"] = true,
			["ValveBiped.Jacket0_bone"] = true
		}
	end
	
	local function OneHand()
		local tbl = BaseBones()
		tbl["ValveBiped.Bip01_L_Clavicle"] = true
		tbl["ValveBiped.Bip01_L_UpperArm"] = true
		tbl["ValveBiped.Bip01_L_Forearm"] = true
		tbl["ValveBiped.Bip01_L_Hand"] = true
		tbl["ValveBiped.Anim_Attachment_LH"] = true
		tbl["ValveBiped.Bip01_L_Finger4"] = true
		tbl["ValveBiped.Bip01_L_Finger41"] = true
		tbl["ValveBiped.Bip01_L_Finger42"] = true
		tbl["ValveBiped.Bip01_L_Finger3"] = true
		tbl["ValveBiped.Bip01_L_Finger31"] = true
		tbl["ValveBiped.Bip01_L_Finger32"] = true
		tbl["ValveBiped.Bip01_L_Finger2"] = true
		tbl["ValveBiped.Bip01_L_Finger21"] = true
		tbl["ValveBiped.Bip01_L_Finger22"] = true
		tbl["ValveBiped.Bip01_L_Finger1"] = true
		tbl["ValveBiped.Bip01_L_Finger11"] = true
		tbl["ValveBiped.Bip01_L_Finger12"] = true
		tbl["ValveBiped.Bip01_L_Finger0"] = true
		tbl["ValveBiped.Bip01_L_Finger01"] = true
		tbl["ValveBiped.Bip01_L_Finger02"] = true
		
		return tbl
	end
	
	local tTwoHands = OneHand()
	
	tTwoHands["ValveBiped.Bip01_R_Clavicle"] = true
	tTwoHands["ValveBiped.Bip01_R_UpperArm"] = true
	tTwoHands["ValveBiped.Bip01_R_Forearm"] = true
	tTwoHands["ValveBiped.Bip01_R_Hand"] = true
	tTwoHands["ValveBiped.Anim_Attachment_RH"] = true
	tTwoHands["ValveBiped.Bip01_R_Finger4"] = true
	tTwoHands["ValveBiped.Bip01_R_Finger41"] = true
	tTwoHands["ValveBiped.Bip01_R_Finger42"] = true
	tTwoHands["ValveBiped.Bip01_R_Finger3"] = true
	tTwoHands["ValveBiped.Bip01_R_Finger31"] = true
	tTwoHands["ValveBiped.Bip01_R_Finger32"] = true
	tTwoHands["ValveBiped.Bip01_R_Finger2"] = true
	tTwoHands["ValveBiped.Bip01_R_Finger21"] = true
	tTwoHands["ValveBiped.Bip01_R_Finger22"] = true
	tTwoHands["ValveBiped.Bip01_R_Finger1"] = true
	tTwoHands["ValveBiped.Bip01_R_Finger11"] = true
	tTwoHands["ValveBiped.Bip01_R_Finger12"] = true
	tTwoHands["ValveBiped.Bip01_R_Finger0"] = true
	tTwoHands["ValveBiped.Bip01_R_Finger01"] = true
	tTwoHands["ValveBiped.Bip01_R_Finger02"] = true
	
	gs.legs.VisibleBones = {
		NoHands = BaseBones(),
		OneHand = OneHand(),
		TwoHands = tTwoHands
	}
end

local gs_legs = CreateConVar("gs_legs", "1", FCVAR_ARCHIVE, "Enables showing player legs in first-person")
local gs_legs_offset = CreateConVar("gs_legs_offset", "-20", FCVAR_ARCHIVE, "Position offset multiplier between " .. gs.legs.OffsetLimits.Min .. " and " .. gs.legs.OffsetLimits.Max)
local gs_legs_clipfix = CreateConVar("gs_legs_clipfix", "1", FCVAR_ARCHIVE, "Fixes legs being too high while jumping or crouching, but makes landing look jerky")
local tVisibleBoneMappings = {}
local tPrevTable, pPrevPlayer, sPrevModel

local function UpdateBones(pLegs)
	local pPlayer = LocalOrSpectatorEntity()
	
	if (not pPlayer:IsPlayer()) then
		return
	end
	
	pLegs:SetParent(pPlayer)
	local tNewTable
	
	if (pPlayer:InVehicle() and not pPlayer:GetAllowWeaponsInVehicle()) then
		tNewTable = gs.legs.VisibleBones.TwoHands
	else
		local pWeapon = pPlayer:GetActiveWeapon()
		
		if (pWeapon:IsValid()) then
			if (bEntities) then
				local iHands = gs.IsType(pWeapon, gs.TYPE_GSENTITY) and (pWeapon.FreeHands or gs.entities.GetHoldTypeFreeHands(pWeapon:GetHoldType(true)))
					or tOverrideModels[string_lower(pWeapon:GetViewModel())] or gs.entities.GetHoldTypeFreeHands(pWeapon:GetHoldType())
				
				tNewTable = gs.legs.VisibleBones[iHands == 1 and "OneHand" or iHands == 2 and "TwoHands" or "NoHands"]
			else
				tNewTable = gs.legs.VisibleBones.NoHands
			end
		else
			tNewTable = gs.legs.VisibleBones.TwoHands
		end
	end
	
	local sModel = pPlayer:GetModel()
	local bModelUpdate = sModel ~= sPrevModel
	
	if (bModelUpdate) then
		pPlayer:SetModel(sModel)
		sPrevModel = sModel
	end
	
	pLegs:CopyVisualData(pPlayer, true)
	
	if (bModelUpdate or not (tNewTable == tPrevTable and pPlayer == pPrevPlayer)) then
		tPrevTable = tNewTable
		pPrevPlayer = pPlayer
		
		local tHideBones = {}
		local iBoneLen = pLegs:GetBoneCount() - 1
		
		-- Reset the bone map table
		-- Bone count can differentiate between models so this can't be done in the for loop
		for k, v in pairs(tVisibleBoneMappings) do
			tVisibleBoneMappings[k] = nil
		end
		
		-- Update the scale and cache the hidden bones so the second loop doesn't have to test again
		for iBone = 0, iBoneLen do
			if (tNewTable[pLegs:GetBoneName(iBone)]) then
				pLegs:ManipulateBoneScale(iBone, vector_normal)
				tHideBones[iBone] = false
			else
				pLegs:ManipulateBoneScale(iBone, vector_origin)
				tHideBones[iBone] = true
			end
		end
		
		-- Find the root visible ancestors for bones to hide meshes in hidden bones
		for iBone = 0, iBoneLen do
			-- Bone is not visible
			if (tHideBones[iBone]) then
				local iParent = pLegs:GetBoneParent(iBone)
				
				-- Bone has a parent
				if (iParent ~= -1) then
					local iParentRoot = tVisibleBoneMappings[iParent]
					
					-- Check if the parent has already found its root visible ancestor
					if (iParentRoot) then
						tVisibleBoneMappings[iBone] = iParentRoot
					-- Parent is also hidden
					elseif (tHideBones[iParent]) then
						::FindParent::
						
						do
							local iNewParent = pLegs:GetBoneParent(iParent)
							
							-- No visible ancestor
							if (iNewParent == -1) then
								continue
							end
							
							-- Bone is visible, this is the root visible ancestor
							if (not tHideBones[iNewParent]) then
								tVisibleBoneMappings[iBone] = iNewParent
								
								continue
							end
							
							local iParentRoot = tVisibleBoneMappings[iNewParent]
							
							-- One of the bone's ancestors already found its root; use it
							if (iParentRoot) then
								tVisibleBoneMappings[iBone] = iParentRoot
								
								continue
							end
							
							iParent = iNewParent
						end
						
						goto FindParent
					-- Parent is the root visible ancestor
					else
						tVisibleBoneMappings[iBone] = iParent
					end
				end
			end
		end
	end
	
	-- Discontinuous table
	for iBone, iRoot in pairs(tVisibleBoneMappings) do
		pLegs:SetBoneMatrix(iBone, pLegs:GetBoneMatrix(iRoot))
	end
end

-- FIXME: Draw local player shadow in first-person

hook.Add("InitPostEntity", "gs_legs", function()
	local pPlayer = LocalOrSpectatorEntity()
	
	if (pPlayer:IsValid()) then
		local pLegs = ClientsideModel(pPlayer:GetModel())
		local nCallback = -1
		
		if (pLegs:IsValid()) then
			pLegs:SetParent(pPlayer)
			pLegs:SetIK(true) -- Move legs/arms physically on surfaces
			pLegs:SetNoDraw(true) -- Manual drawing
			pLegs:DrawShadow(false) -- Shadow from the legs doesn't match the actual player's
			nCallback = pLegs:AddCallback("BuildBonePositions", UpdateBones)
			
			pPlayer:DeleteOnRemove(pLegs)
		end
		
		local tLegs = gs.legs
		tLegs.m_pLegs = pLegs
		tLegs.m_nCallback = nCallback
	end
end)

-- FIXME: Make it play weapon animations - hijack CalcMainActivity?
-- FIXME: Wrong pose params
-- FIXME: Vehicle has wrong seat position
hook.Add("PreDrawOpaqueRenderables", "gs_legs", function()
	local pPlayer = LocalOrSpectatorEntity()
	
	if (pPlayer:IsPlayer() and pPlayer:Alive() and not (pPlayer:InVehicle() or pPlayer:ShouldDrawLocalPlayer())) then
		local pLegs = gs.legs.m_pLegs
		
		if (pLegs:IsValid()) then
			local bEnabled = render_EnableClipping(true)
			render_PushCustomClipPlane(vector_down, vector_down:Dot(EyePos()))
			
			-- https://github.com/Facepunch/garrysmod-issues/issues/3107
			-- https://github.com/Facepunch/garrysmod-issues/issues/3106
			
			local vPos = pPlayer:GetPos()
			local aRot
			
			--[[if (pPlayer:InVehicle()) then
				aRot = Angle(0, pPlayer:GetAngles()[2])
			else]]
				local flDegreeYaw = EyeAngles()[2]
				aRot = Angle(0, flDegreeYaw)
				local flRadianYaw = math_rad(flDegreeYaw)
				local tLimits = gs.legs.OffsetLimits
				local flOffset = math_Clamp(gs_legs_offset:GetFloat(), tLimits.Min, tLimits.Max)
				vPos[1] = vPos[1] + math_cos(flRadianYaw) * flOffset
				vPos[2] = vPos[2] + math_sin(flRadianYaw) * flOffset
				
				-- FIXME: This is shitty but it seems to be the
				-- best way to move the knees from the viewport
				if (gs_legs_clipfix:GetBool()) then
					if (pPlayer:Crouching()) then
						vPos[3] = vPos[3] - (pPlayer:OnGround() and 8 or 20)
					--[[elseif (not pPlayer:OnGround()) then
						vPos[3] = vPos[3] - 8]]
					end
				end
			--end
			
			-- Set the absolute position for IK to take effect
			pLegs:SetPos(vPos)
			pLegs:SetAngles(aRot)
			--pLegs:SetRenderOrigin(vPos)
			--pLegs:GetRenderAngles(aRot)
			
			pLegs:SetupBones()
			pLegs:DrawModel()
			
			render_PopCustomClipPlane()
			render_EnableClipping(bEnabled)
		end
	end
end)
