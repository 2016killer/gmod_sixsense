
local targetRadius = 0
local speed = 0
local speedback = 0
local currentRadius = 0
local enable = false
local limitent = 30
local startpos = Vector()
local sixs_sound = CreateClientConVar('sixs_sound', 'darkvision_scan.wav', true, false)

concommand.Add('sixsense', function(ply, cmd, args)
	if enable then 
		return
	end

	entqueue = {}
	currentRadius = 0

	targetRadius = math.max(100, math.abs(tonumber(args[1]) or 1000))
	speed = math.max(10, math.abs(tonumber(args[2]) or 1000))
	speedback = -math.max(10, math.abs(tonumber(args[3]) or 1000))
	limitent = math.max(5, math.abs(tonumber(args[4]) or 30))

	local entities = ents.FindInSphere(ply:GetPos(), targetRadius)
	local count = 0
	for i, ent in ipairs(entities) do
		if not ent:IsNPC() then
			continue
		end
		count = count + 1
		if count > limitent then
			break
		end
		table.insert(entqueue, ent)
	end

	startpos = ply:GetPos()
	enable = true
end)


local white = Color(255, 255, 255)
local green = Color(0, 255, 0)
local red = Color(255, 0, 0)
local yellow = Color(255, 255, 0)

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
		sphere1:SetNoDraw(true)
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

	surface.PlaySound(sixs_sound:GetString())

	currentRadius = currentRadius + FrameTime() * speed
	if speed > 0 and currentRadius >= targetRadius then
		speed = -speed * 2
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
	sphere1:SetPos(startpos)
	sphere2:SetPos(startpos)

	sphere1:SetModelScale(currentRadius * 0.166 + 2)
	sphere2:SetModelScale(currentRadius * 0.166)
end)

local renderfunc = function()
	if not enable then
		return 
	end
	local sphere1, sphere2 = GetSpheres()
	local currentRadiusSqr = currentRadius * currentRadius

	render.PushRenderTarget(sixsense_rt)
		render.Clear(0, 0, 0, 0, true, true)
		
		render.OverrideAlphaWriteEnable(true, false)
		render.OverrideColorWriteEnable(true, false)

		render.MaterialOverride(wireframe_mat)
		render.OverrideDepthEnable(true, true)
			for _, ent in ipairs(entqueue) do
				if not IsValid(ent) then
					continue
				end

				if startpos:DistToSqr(ent:GetPos()) > currentRadiusSqr + 500 then
					continue
				end

				if not IsValid(ent.skeleton) then
					if ent:LookupBone('ValveBiped.Bip01_Head1') then
						local Skeleton = ClientsideModel('models/player/skeleton.mdl')
						Skeleton:SetNoDraw(true)
						Skeleton:SetParent(ent)
						Skeleton:AddEffects(EF_BONEMERGE)
						ent.skeleton = Skeleton	
					end
				end

				if IsValid(ent.skeleton) then
					ent.skeleton:DrawModel()
				else
					ent:DrawModel()
				end
			end
		render.OverrideDepthEnable(false)
		render.MaterialOverride()

		render.SetStencilEnable(true)
		// 遮罩
		render.SetStencilWriteMask(1)
		render.SetStencilTestMask(1)
		render.SetStencilCompareFunction(STENCIL_ALWAYS)
		render.SetStencilPassOperation(STENCIL_KEEP)
		render.SetStencilFailOperation(STENCIL_KEEP)
		render.SetStencilZFailOperation(STENCIL_INCR)
		// 使用特殊材质便捷双面渲染
		sphere1:DrawModel()
	
		render.OverrideAlphaWriteEnable(false)
		render.OverrideColorWriteEnable(false)

		render.SetStencilReferenceValue(1)
		render.SetStencilCompareFunction(STENCIL_EQUAL)
		render.SetStencilPassOperation(STENCIL_KEEP)
		render.SetStencilFailOperation(STENCIL_KEEP)
		render.SetStencilZFailOperation(STENCIL_KEEP)

		cam.Start2D()
			surface.SetDrawColor(255, 0, 0, 255)
			surface.DrawRect(0, 0, ScrW(), ScrH())
		cam.End2D()
		
		render.SetStencilEnable(false)
	render.PopRenderTarget()


	render.ClearStencil()
	render.SetStencilEnable(true)
	render.SuppressEngineLighting(true)
		// 全屏
		render.SetStencilWriteMask(1)
		render.SetStencilTestMask(1)
		
		// 遮罩
		render.SetStencilCompareFunction(STENCIL_ALWAYS)
		render.SetStencilPassOperation(STENCIL_KEEP)
		render.SetStencilFailOperation(STENCIL_KEEP)
		render.SetStencilZFailOperation(STENCIL_INCR)
		// 使用特殊材质便捷双面渲染
		sphere1:DrawModel()
	
	

		render.SetStencilReferenceValue(1)
		render.SetStencilCompareFunction(STENCIL_EQUAL)
		render.SetStencilPassOperation(STENCIL_KEEP)
		render.SetStencilFailOperation(STENCIL_KEEP)
		render.SetStencilZFailOperation(STENCIL_KEEP)

		cam.Start2D()
			surface.SetDrawColor(0, 0, 0, 75)
			surface.DrawRect(0, 0, ScrW(), ScrH())
		cam.End2D()

		cam.Start2D()
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


local function menu(panel)
	panel:Clear()
	panel:TextEntry('#sixs.sound', 'darkvision_scan.wav')

	local button = panel:Button('#default', '')
	button.DoClick = function()
		RunConsoleCommand('sixs_sound', 'darkvision_scan.wav')
	end
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

menu = nil





