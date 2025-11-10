sixsense = sixsense or {}
local sixsense = sixsense

local function getcolor(str)
	local colorStr = string.Split(str, ' ')
	for i = #colorStr, 1, -1 do
		if string.Trim(colorStr[i]) == '' then
			table.remove(colorStr, i)
			continue
		end
	end
	local color = Color(
		tonumber(colorStr[1]) or 0,
		tonumber(colorStr[2]) or 0,
		tonumber(colorStr[3]) or 0,
		tonumber(colorStr[4]) or 0
	)
	return color
end

sixsense.currentRadius = 0
sixsense.targetRadius = 0
sixsense.speed = 0
sixsense.speedFadeOut = 0
sixsense.enable = false
sixsense.limitent = 30
sixsense.colors = nil
sixsense.entqueue = {}
sixsense.skeleton = 'models/player/skeleton.mdl'

local sixs_start_sound = CreateClientConVar('sixs_start_sound', 'darkvision_start.wav', true, false, '')
local sixs_scan_sound = CreateClientConVar('sixs_scan_sound', 'darkvision_scan.wav', true, false, '')
local sixs_stop_sound = CreateClientConVar('sixs_stop_sound', 'darkvision_end.wav', true, false, '')
local sixs_color1 = CreateClientConVar('sixs_color1', '0 0 0 255', true, false, '')
local sixs_color2 = CreateClientConVar('sixs_color2', '255 255 255 255', true, false, '')
local sixs_color3 = CreateClientConVar('sixs_color3', '255 255 255 255', true, false, '')

concommand.Add('entclass', function(ply, cmd, args)
	local ent = ply:GetEyeTrace().Entity
	print(ent, ent:GetClass(), ent:GetModel())
end)

function sixsense:Filter(ent)
	if not isfunction(ent.DrawModel) and not isfunction(ent.GetModel) then
		return false
	end

	local class = ent:GetClass()
	if not ent:IsNPC() and not scripted_ents.Get(class) and not ent:IsVehicle() and not ent:IsWeapon() and class ~= 'prop_dynamic' then
		return false
	end

	if class == 'gmod_hands' then
		return false
	end

	return true
end

function sixsense:Init(ent, time)
	if not IsValid(ent.skeleton) then
		
		if ent:LookupBone('ValveBiped.Bip01_Head1') then
			local temp = function()
				if IsValid(ent) then
					local Skeleton = ClientsideModel(self.skeleton)	
					Skeleton:SetNoDraw(true)
					Skeleton:SetParent(ent)
					Skeleton:AddEffects(EF_BONEMERGE)
					ent.skeleton = Skeleton
				end
				temp = nil
			end 
			timer.Simple(time or 0, temp)
		elseif not isfunction(ent.DrawModel) then
			local temp = function()
				if IsValid(ent) then
					local Skeleton = ClientsideModel(ent:GetModel())	
					Skeleton:SetNoDraw(true)
					Skeleton:SetParent(ent)
					Skeleton:AddEffects(EF_BONEMERGE)
					ent.skeleton = Skeleton
				end
				temp = nil
			end 
			timer.Simple(time or 0, temp)
		end	
	end
end

function sixsense:Start(ply, targetRadius, speed, speedFadeOut, limitent, startcolors)
	self.entqueue = {}
	self.currentRadius = 0

	self.targetRadius = math.max(100, math.abs(targetRadius or 1000))
	self.speed = math.max(10, math.abs(speed or 1000))
	self.speedFadeOut = math.max(10, math.abs(speedFadeOut or 255))
	self.limitent = math.max(5, math.abs(limitent or 30))
	self.colors = startcolors or {
		Color(0, 0, 0, 255),
		Color(255, 255, 255, 255),
		Color(255, 255, 255, 255)
	}
	self.duration = self.targetRadius / self.speed

	local entities = ents.FindInSphere(ply:GetPos(), self.targetRadius)
	local count = 0
	for i, ent in ipairs(entities) do
		if not self:Filter(ent) then
			continue
		end

		count = count + 1
		if count > self.limitent then
			break
		end

		self:Init(ent, count * self.duration / self.limitent * 0.5)

		table.insert(self.entqueue, ent)
	end

	self.enable = true
end

function sixsense:Stop()
	self.enable = false

	self.currentRadius = 0
	self.targetRadius = 0
	self.speed = 0
	self.speedFadeOut = 0
	self.limitent = 0
	self.colors = {}
	self.duration = 0

	if istable(self.entqueue) then
		for _, ent in ipairs(self.entqueue) do
			if not IsValid(ent) then
				continue
			end
			if not IsValid(ent.skeleton) then
				continue
			end
			ent.skeleton:Remove()
		end
	end
	self.entqueue = {}


	if istable(self.entstopqueue) then
		for _, ent in ipairs(self.entstopqueue) do
			if not IsValid(ent) then
				continue
			end
			if not IsValid(ent.skeleton) then
				continue
			end
			ent.skeleton:Remove()
		end
	end

	self.entstopqueue = {}

end

function sixsense:Trigger(...)
	if not self.enable then
		self:Start(...)
		return true
	else
		self:Stop()
		return false
	end
end

concommand.Add('sixsense', function(ply, cmd, args)
	if sixsense:Trigger(ply, args[1], args[2], args[3], args[4], {
		getcolor(sixs_color1:GetString()),
		getcolor(sixs_color2:GetString()),
		getcolor(sixs_color3:GetString()),
	}) then
		surface.PlaySound(sixs_start_sound:GetString())
	else
		surface.PlaySound(sixs_stop_sound:GetString())
	end
end)



function sixsense:Think()
	if not self.enable then
		return
	end
	local dt = RealFrameTime()
	self.colors[1].a = math.Clamp(self.colors[1].a - dt * self.speedFadeOut, 0, 255)
	self.colors[2].a = math.Clamp(self.colors[2].a - dt * self.speedFadeOut, 0, 255)
	self.colors[3].a = math.Clamp(self.colors[3].a - dt * self.speedFadeOut, 0, 255)

	self.currentRadius = self.currentRadius + dt * self.speed
	if self.speed > 0 and self.currentRadius >= self.targetRadius then
		self.speed = 2
	elseif self.speed < 0 and self.currentRadius <= 0 then

	end
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

local vol_light001_mat = Material('Models/effects/vol_light001')
local wireframe_mat = Material('models/wireframe')

hook.Add('Think', 'sixsense', function()
	sixsense:Think()
end)

local white = Color(255, 255, 255, 255)
function sixsense:Draw()
	if not self.enable then
		return 
	end
	local plypos = LocalPlayer():GetPos()
	local currentRadiusSqr = self.currentRadius * self.currentRadius
	local color1 = self.colors[1]
	local color2 = self.colors[2]
	local color3 = self.colors[3]
		
	if self.speed > 1 then
		render.PushRenderTarget(sixsense_rt)
			render.Clear(0, 0, 0, 0, true, true)
		
			render.OverrideAlphaWriteEnable(true, false)
			render.OverrideColorWriteEnable(true, false)
			render.OverrideDepthEnable(true, true)
				render.SetMaterial(vol_light001_mat)
				render.DrawSphere(plypos, self.currentRadius, 8, 8, white)
			render.OverrideAlphaWriteEnable(false)
			render.OverrideColorWriteEnable(false)
			render.OverrideDepthEnable(false)

			render.MaterialOverride(wireframe_mat)
				for _, ent in ipairs(self.entqueue) do
					if not IsValid(ent) then
						continue
					end

					if plypos:DistToSqr(ent:GetPos()) > currentRadiusSqr + 40000 then
						continue
					end

					if IsValid(ent.skeleton) then
						ent.skeleton:DrawModel()
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
			render.SetMaterial(vol_light001_mat)
			render.DrawSphere(plypos, self.currentRadius, 8, 8, white)
		
			render.SetStencilReferenceValue(1)
			render.SetStencilCompareFunction(STENCIL_EQUAL)
			render.SetStencilPassOperation(STENCIL_KEEP)
			render.SetStencilFailOperation(STENCIL_KEEP)
			render.SetStencilZFailOperation(STENCIL_KEEP)

			cam.Start2D()
				surface.SetDrawColor(color1.r, color1.g, color1.b, color1.a)
				surface.DrawRect(0, 0, ScrW(), ScrH())

				surface.SetDrawColor(color2.r, color2.g, color2.b, color2.a)
				surface.SetMaterial(sixsense_mat)
				surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
			cam.End2D()

			// 遮罩
			render.SetStencilCompareFunction(STENCIL_ALWAYS)
			render.SetStencilPassOperation(STENCIL_KEEP)
			render.SetStencilFailOperation(STENCIL_KEEP)
			render.SetStencilZFailOperation(STENCIL_INCR)
			render.SetMaterial(vol_light001_mat)
			render.DrawSphere(plypos, self.currentRadius + 20, 8, 8, white)


			render.SetStencilReferenceValue(1)
			render.SetStencilCompareFunction(STENCIL_EQUAL)
			render.SetStencilPassOperation(STENCIL_KEEP)
			render.SetStencilFailOperation(STENCIL_KEEP)
			render.SetStencilZFailOperation(STENCIL_KEEP)
			render.ClearBuffersObeyStencil(color3.r, color3.g, color3.b, color3.a, false)

		render.SetStencilEnable(false)
		render.SuppressEngineLighting(false)
	else
		render.PushRenderTarget(sixsense_rt)
			render.Clear(0, 0, 0, 0, true, true)
			
			render.MaterialOverride(wireframe_mat)
				for _, ent in ipairs(self.entqueue) do
					if not IsValid(ent) then
						continue
					end

					if plypos:DistToSqr(ent:GetPos()) > currentRadiusSqr + 40000 then
						continue
					end

					if IsValid(ent.skeleton) then
						ent.skeleton:DrawModel()
					end	
				end
			render.MaterialOverride()
		render.PopRenderTarget()

		cam.Start2D()
			surface.SetDrawColor(color2.r, color2.g, color2.b, color2.a)
			surface.SetMaterial(sixsense_mat)
			surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
		cam.End2D()
	end

end

local renderfuncsafe = function()
	local succ, err = pcall(sixsense.Draw, sixsense)
	if not succ then
		print(err)
		render.OverrideAlphaWriteEnable(false)
		render.OverrideDepthEnable(false)
		render.OverrideColorWriteEnable(false)
		render.SetStencilEnable(false)
	end
end

hook.Add('PostDrawOpaqueRenderables', 'sixsense', renderfuncsafe)

---------------------------------------------------


local function CreateColorEditor(cvar)
	local BGPanel = vgui.Create('DPanel')
	BGPanel:SetSize(200, 200)
	BGPanel.Color = getcolor(cvar:GetString())

	local color_label = Label(
		string.format('Color(%s, %s, %s, %s)', BGPanel.Color.r, BGPanel.Color.g, BGPanel.Color.b, BGPanel.Color.a)
		, BGPanel)
	color_label:SetPos(70, 180)
	color_label:SetSize(150, 20)
	color_label:SetHighlight(true)

	local function UpdateColors(r, g, b, a, noUpdateCvar)
		r = r or BGPanel.Color.r
		g = g or BGPanel.Color.g
		b = b or BGPanel.Color.b
		a = a or BGPanel.Color.a

		color_label:SetText('Color( '..r..', '..g..', '..b..', '..a..' )')

		BGPanel.Color.r = r
		BGPanel.Color.g = g
		BGPanel.Color.b = b
		BGPanel.Color.a = a

		if noUpdateCvar then
			return
		end

		cvar:SetString(
			string.format('%s %s %s %s', r, g, b, a)
		)
	end

	local DAlphaBar = vgui.Create('DAlphaBar', BGPanel)
	DAlphaBar:SetPos(25, 5)
	DAlphaBar:SetSize(15, 190)
	DAlphaBar:SetValue(BGPanel.Color.a)
	DAlphaBar.OnChange = function(self, newvalue)
		UpdateColors(nil, nil, nil, newvalue * 255)
	end

	local color_picker = vgui.Create('DRGBPicker', BGPanel)
	color_picker:SetPos(5, 5)
	color_picker:SetSize(15, 190)

	local color_cube = vgui.Create('DColorCube', BGPanel)
	color_cube:SetPos(50, 20)
	color_cube:SetSize(155, 155)


	function color_picker:OnChange(col)
		local h = ColorToHSV(col)
		local _, s, v = ColorToHSV(color_cube:GetRGB())
		
		col = HSVToColor(h, s, v)
		color_cube:SetColor(col)
		
		UpdateColors(col.r, col.g, col.b, nil)
	end

	function color_cube:OnUserChanged(col)
		UpdateColors(col.r, col.g, col.b, nil)
	end

	cvars.AddChangeCallback(cvar:GetName(), function(cvar, old, new) 
		if IsValid(BGPanel) then
			BGPanel.Color = getcolor(new) 
			UpdateColors(nil, nil, nil, nil, true)
		end
	end)

	return BGPanel
end

local function menu(panel)
	panel:Clear()


	local button = panel:Button('#default', '')
	button.DoClick = function()
		RunConsoleCommand('sixs_start_sound', 'darkvision_start.wav')
		RunConsoleCommand('sixs_scan_sound', 'darkvision_scan.wav')
		RunConsoleCommand('sixs_stop_sound', 'darkvision_end.wav')

		RunConsoleCommand(sixs_color1:GetName(), '0 0 0 150')
		RunConsoleCommand(sixs_color2:GetName(), '255 255 255 255')
		RunConsoleCommand(sixs_color3:GetName(), '255 255 255 255')
	end

	panel:TextEntry('#sixs.start_sound', 'sixs_start_sound')
	panel:TextEntry('#sixs.scan_sound', 'sixs_scan_sound')
	panel:TextEntry('#sixs.stop_sound', 'sixs_stop_sound')
	
	panel:AddItem(CreateColorEditor(sixs_color1))
	panel:AddItem(CreateColorEditor(sixs_color2))
	panel:AddItem(CreateColorEditor(sixs_color3))
end

-------------------------菜单
hook.Add('PopulateToolMenu', 'sixs.menu', function()
	spawnmenu.AddToolMenuOption(
		'Options', 
		language.GetPhrase('#sixs.menu.category'), 
		'sixs.menu',
		language.GetPhrase('#sixs.menu.name'), '', '', 
		menu
	)
end)





