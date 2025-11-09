
local targetRadius = 0
local speed = 0
local speedback = 0
local currentRadius = 0
local enable = false
local limitent = 30
local sixs_sound = CreateClientConVar('sixs_sound', 'darkvision_scan.wav', true, false)

concommand.Add('entclass', function(ply, cmd, args)
	local ent = ply:GetEyeTrace().Entity
	print(ent, ent:GetClass(), ent:GetModel())
end)

concommand.Add('sixsense', function(ply, cmd, args)
	if enable then 
		return
	end

	entqueue = {}
	currentRadius = 0

	targetRadius = math.max(100, math.abs(tonumber(args[1]) or 1000))
	speed = math.max(10, math.abs(tonumber(args[2]) or 1000))
	speedback = -math.max(10, math.abs(tonumber(args[3]) or 2000))
	limitent = math.max(5, math.abs(tonumber(args[4]) or 30))

	local entities = ents.FindInSphere(ply:GetPos(), targetRadius)
	local count = 0
	for i, ent in ipairs(entities) do
		local class = ent:GetClass()
		if not ent:IsNPC() and not scripted_ents.Get(class) and not ent:IsVehicle() and not ent:IsWeapon() and class ~= 'prop_door_rotating' and class ~= 'prop_dynamic' then
			continue
		elseif class == 'gmod_hands' then
			continue
		end

		if not isfunction(ent.DrawModel) and not isfunction(ent.GetModel) then
			continue
		end

		count = count + 1
		if count > limitent then
			break
		end

		if not IsValid(ent.skeleton) then
			if ent:LookupBone('ValveBiped.Bip01_Head1') then
				local Skeleton = ClientsideModel('models/player/skeleton.mdl')	
				Skeleton:SetNoDraw(true)
				Skeleton:SetParent(ent)
				Skeleton:AddEffects(EF_BONEMERGE)
				ent.skeleton = Skeleton
			elseif not isfunction(ent.DrawModel) then
				print(565656)
				local Skeleton = ClientsideModel(ent:GetModel())	
				Skeleton:SetNoDraw(true)
				Skeleton:SetParent(ent)
				Skeleton:AddEffects(EF_BONEMERGE)
				ent.skeleton = Skeleton
			end
		end

		table.insert(entqueue, ent)
	end

	enable = true
	surface.PlaySound(sixs_sound:GetString())
end)

local sphere1, sphere2
local function GetSpheres()

	if not IsValid(sphere1) then 
		sphere1 = ClientsideModel('models/dav0r/hoverball.mdl')
		sphere1:SetMaterial('Models/effects/vol_light001') 
		sphere1:SetNoDraw(true)
	end
		
	if not IsValid(sphere2) then 
		sphere2 = ClientsideModel('models/dav0r/hoverball.mdl')
		sphere2:SetMaterial('Models/effects/vol_light001') 
		sphere2:SetNoDraw(true)
	end

	return sphere1, sphere2
end

// local sixsense_rt = GetRenderTargetEx('sixsense_rt',  ScrW(), ScrH(), 
// 	RT_SIZE_FULL_FRAME_BUFFER, 
// 	MATERIAL_RT_DEPTH_SEPARATE, 
// 	bit.bor(4, 8), 
// 	CREATERENDERTARGETFLAGS_AUTOMIPMAP, 
// 	IMAGE_FORMAT_RGBA8888
// )
local sixsense_rt = GetRenderTarget('sixsense_rt',  ScrW(), ScrH())

local sixsense_mat = CreateMaterial('sixsense_mat', 'UnLitGeneric', {
	['$basetexture'] = sixsense_rt:GetName(),
	['$translucent'] = 1,
	['$vertexcolor'] = 1
})

local wireframe_mat = Material('models/wireframe')

hook.Add('Think', 'sixsense', function()
	if not enable then
		return
	end

	currentRadius = currentRadius + FrameTime() * speed
	if speed > 0 and currentRadius >= targetRadius then
		speed = speedback
	elseif speed < 0 and currentRadius <= 0 then
		enable = false
		currentRadius = 0

		for _, ent in ipairs(entqueue) do
			if not IsValid(ent) then
				continue
			end
			if not IsValid(ent.skeleton) then
				continue
			end
			ent.skeleton:Remove()
		end

	end

	local sphere1, sphere2 = GetSpheres()
	sphere1:SetPos(LocalPlayer():GetPos())
	sphere2:SetPos(LocalPlayer():GetPos())

	sphere1:SetModelScale(currentRadius * 0.166 + 2)
	sphere2:SetModelScale(currentRadius * 0.166)
end)

local renderfunc = function()
	if not enable then
		return 
	end
	local plypos = LocalPlayer():GetPos()
	local sphere1, sphere2 = GetSpheres()
	local currentRadiusSqr = currentRadius * currentRadius

	render.PushRenderTarget(sixsense_rt)
		render.Clear(0, 0, 0, 0, true, true)
	
		render.OverrideAlphaWriteEnable(true, false)
		render.OverrideColorWriteEnable(true, false)
		render.OverrideDepthEnable(true, true)
		sphere1:DrawModel()
		render.OverrideAlphaWriteEnable(false)
		render.OverrideColorWriteEnable(false)
		render.OverrideDepthEnable(false)

		render.MaterialOverride(wireframe_mat)
			for _, ent in ipairs(entqueue) do
				if not IsValid(ent) then
					continue
				end

				if plypos:DistToSqr(ent:GetPos()) > currentRadiusSqr + 10000 then
					continue
				end

				if IsValid(ent.skeleton) then
					ent.skeleton:DrawModel()
				else
					ent:DrawModel()
				end	
			end
		render.MaterialOverride()
	render.PopRenderTarget()


	render.ClearStencil()
	render.SetStencilEnable(true)
	render.SuppressEngineLighting(true)
		// 全屏
		render.SetStencilWriteMask(1)
		render.SetStencilTestMask(1)
		render.SetStencilCompareFunction(STENCIL_ALWAYS)
		render.SetStencilPassOperation(STENCIL_KEEP)
		render.SetStencilFailOperation(STENCIL_KEEP)
		render.SetStencilZFailOperation(STENCIL_INCR)
		sphere1:DrawModel()
	
		render.SetStencilReferenceValue(1)
		render.SetStencilCompareFunction(STENCIL_EQUAL)
		render.SetStencilPassOperation(STENCIL_KEEP)
		render.SetStencilFailOperation(STENCIL_KEEP)
		render.SetStencilZFailOperation(STENCIL_KEEP)

		cam.Start2D()
			surface.SetDrawColor(0, 0, 0, 200)
			surface.DrawRect(0, 0, ScrW(), ScrH())

			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetMaterial(sixsense_mat)
			surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
		cam.End2D()

		// 遮罩
		render.SetStencilCompareFunction(STENCIL_ALWAYS)
		render.SetStencilPassOperation(STENCIL_KEEP)
		render.SetStencilFailOperation(STENCIL_KEEP)
		render.SetStencilZFailOperation(STENCIL_INCR)
		sphere2:DrawModel()


		render.SetStencilReferenceValue(1)
		render.SetStencilCompareFunction(STENCIL_EQUAL)
		render.SetStencilPassOperation(STENCIL_KEEP)
		render.SetStencilFailOperation(STENCIL_KEEP)
		render.SetStencilZFailOperation(STENCIL_KEEP)
		render.ClearBuffersObeyStencil(255, 255, 255, 255, false)

	render.SetStencilEnable(false)
	render.SuppressEngineLighting(false)
end

local renderfuncsave = function()
	local succ, err = pcall(renderfunc)
	if not succ then
		print(err)
		render.OverrideAlphaWriteEnable(false)
		render.OverrideDepthEnable(false)
		render.OverrideColorWriteEnable(false)
		render.SetStencilEnable(false)
	end
end

hook.Add('PostDrawOpaqueRenderables', 'sixsense', renderfuncsave)

---------------------------------------------------

local function menu(panel)
	panel:Clear()


	local button = panel:Button('#default', '')
	button.DoClick = function()
		RunConsoleCommand('sixs_sound', 'darkvision_scan.wav')
	end

	panel:TextEntry('#sixs.sound', 'sixs_sound')
end

local phrase = language.GetPhrase
-------------------------菜单
hook.Add('PopulateToolMenu', 'sixs.menu', function()
	spawnmenu.AddToolMenuOption(
		'Options', 
		phrase('#sixs.menu.category'), 
		'sixs.menu',
		phrase('#sixs.menu.name'), '', '', 
		menu
	)
end)





