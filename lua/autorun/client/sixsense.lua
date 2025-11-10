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

local sixsense_rt = GetRenderTarget('sixsense_rt',  ScrW(), ScrH())
local sixsense_mat = CreateMaterial('sixsense_mat', 'UnLitGeneric', {
	['$basetexture'] = sixsense_rt:GetName(),
	['$translucent'] = 1,
	['$vertexcolor'] = 1,
	['$alpha'] = 1
})

// local sixsense_rt = GetRenderTargetEx('sixsense_rt',  ScrW(), ScrH(), 
// 	RT_SIZE_FULL_FRAME_BUFFER, 
// 	MATERIAL_RT_DEPTH_SEPARATE, 
// 	bit.bor(4, 8), 
// 	CREATERENDERTARGETFLAGS_AUTOMIPMAP, 
// 	IMAGE_FORMAT_RGBA8888
// )


sixsense.currentRadius = 0
sixsense.targetRadius = 0
sixsense.speed = 0
sixsense.speedFadeOut = 0
sixsense.limitent = 30
sixsense.scan_sound = ''
sixsense.colors = {}
sixsense.startcolors = {}
sixsense.entqueue = {}
sixsense.duration = 0
sixsense.skeleton = 'models/player/skeleton.mdl'
sixsense.skeletonEntities = {}
sixsense.enable = false
sixsense.flag1 = nil
sixsense.flag2 = nil
sixsense.timer = nil
sixsense.period = 0
sixsense.speedFadeOut2 = 0

concommand.Add('sixsense_debug', function()
	PrintTable(sixsense)
end)

local sixs_start_sound = CreateClientConVar('sixs_start_sound', 'darkvision_start.wav', true, false, '')
local sixs_scan_sound = CreateClientConVar('sixs_scan_sound', 'darkvision_scan.wav', true, false, '')
local sixs_stop_sound = CreateClientConVar('sixs_stop_sound', 'darkvision_end.wav', true, false, '')
local sixs_color1 = CreateClientConVar('sixs_color1', '0 0 0 170', true, false, '')
local sixs_color2 = CreateClientConVar('sixs_color2', '255 255 255 255', true, false, '')
local sixs_color3 = CreateClientConVar('sixs_color3', '255 255 255 255', true, false, '')

function sixsense:Filter(ent)
	if not IsValid(ent) then
		return false
	end

	if not isfunction(ent.DrawModel) then
		return false
	end 

	local class = ent:GetClass()
	if ent:IsRagdoll() or ent:GetOwner() == LocalPlayer() or ent:GetParent() == LocalPlayer() or class == 'lg_ragdoll' then
		return false
	end

	if ent:IsNPC() or scripted_ents.GetStored(class) or ent:IsVehicle() or ent:IsWeapon() or class == 'prop_dynamic' then
		return true
	end

	return false
end

function sixsense:InitSkeletonDelay(ent, startcolor, delay)
	if IsValid(ent.sixs_skeleton) then
		return
	end

	local skeletonmodel = nil
	if ent:LookupBone('ValveBiped.Bip01_Head1') then
		skeletonmodel = self.skeleton
	elseif not isfunction(ent.DrawModel) then
		skeletonmodel = ent:GetModel()
	end	

	if skeletonmodel then
		local function temp()
			if IsValid(ent) then
				local skeleton = ClientsideModel(self.skeleton, RENDERGROUP_BOTH)	
				skeleton:SetNoDraw(true)
				skeleton:SetParent(ent)
				skeleton:AddEffects(EF_BONEMERGE)
				skeleton:SetupBones()
				table.insert(self.skeletonEntities, skeleton)
				ent.sixs_skeleton = skeleton
			end
			// print(temp)
			temp = nil
		end 
		timer.Simple(delay or 0, temp)
	else
		ent.sixs_skeleton = ent
	end
end

function sixsense:Start(ply, targetRadius, speed, limitent, startcolors, scan_sound, period)
	self.flag1 = nil
	self.flag2 = nil
	self.timer = nil
	timer.Remove('bloodlust_clear_skeleton')
	self.currentRadius = 0

	self.targetRadius = math.max(1, math.abs(targetRadius or 1000))
	self.speed = math.max(1, math.abs(speed or 1000))
	self.speedFadeOut = 255 / self.targetRadius * self.speed
	self.limitent = math.max(5, math.abs(limitent or 30))
	self.period = math.max(0.5, math.abs(period or 5))
	self.speedFadeOut2 = 255 / self.period
	self.startcolors = startcolors or {
		Color(0, 0, 0, 255),
		Color(255, 255, 255, 255),
		Color(255, 255, 255, 255)
	}
	self.colors = table.Copy(self.startcolors)
	self.duration = self.targetRadius / self.speed
	self.scan_sound = scan_sound or sixs_scan_sound:GetString()

	self.entqueue = {}
	local entities = ents.FindInSphere(ply:GetPos(), self.targetRadius)
	for i, ent in ipairs(entities) do
		local len = #self.entqueue

		if len >= self.limitent then
			break
		end

		if not self:Filter(ent) then
			continue
		end

		self:InitSkeletonDelay(ent, (len + 1) * self.duration / self.limitent * 0.5)
		table.insert(self.entqueue, ent)
	end

	self.enable = true
end

function sixsense:Clear()
	self.enable = false

	self.currentRadius = 0
	self.targetRadius = 0
	self.speed = 0
	self.speedFadeOut = 0
	self.limitent = 0
	self.scan_sound = ''
	self.colors = {}
	self.startcolors = {}
	self.duration = 0
	self.entqueue = {}
	self.flag1 = nil
	self.flag2 = nil
	self.timer = nil
	self.period = 0
	self.speedFadeOut2 = 0

	timer.Create('bloodlust_clear_skeleton', 5, 0, function()
		if self.enable or #self.skeletonEntities < 1 then
			timer.Remove('bloodlust_clear_skeleton')
		end

		for i = #self.skeletonEntities, math.max(#self.skeletonEntities - 30, 1), -1 do
			local skeleton = self.skeletonEntities[i]
			if IsValid(skeleton) then
				skeleton:Remove()
			end
			table.remove(self.skeletonEntities, i)
		end
	end)
end

function sixsense:Trigger(...)
	if not self.enable then
		self:Start(...)
		return true
	else
		self:Clear()
		return false
	end
end

concommand.Add('sixsense', function(ply, cmd, args)
	-- 老版本
	if sixsense:Trigger(ply, args[1], args[2], args[4], {
		getcolor(sixs_color1:GetString()),
		getcolor(sixs_color2:GetString()),
		getcolor(sixs_color3:GetString()),
	}, sixs_scan_sound:GetString(), args[5]) then
		surface.PlaySound(sixs_start_sound:GetString())
	else
		surface.PlaySound(sixs_stop_sound:GetString())
	end
end)

concommand.Add('sixsense_new', function(ply, cmd, args)
	if sixsense:Trigger(ply, args[1], args[2], args[3], {
		getcolor(sixs_color1:GetString()),
		getcolor(sixs_color2:GetString()),
		getcolor(sixs_color3:GetString()),
	}, sixs_scan_sound:GetString(), args[4]) then
		surface.PlaySound(sixs_start_sound:GetString())
	else
		surface.PlaySound(sixs_stop_sound:GetString())
	end
end)

concommand.Add('sixsense_oneshot', function(ply, cmd, args)
	sixsense:Start(ply, args[1], args[2], args[3], {
		getcolor(sixs_color1:GetString()),
		getcolor(sixs_color2:GetString()),
		getcolor(sixs_color3:GetString()),
	}, sixs_scan_sound:GetString(), args[4]) 
	
	surface.PlaySound(sixs_start_sound:GetString())
end)



function sixsense:Think()
	if not self.enable then
		return
	end
	local dt = RealFrameTime()
	local speedFadeOut = self.speedFadeOut

	self.colors[1].a = math.Clamp(self.colors[1].a - dt * speedFadeOut, 0, 255)
	self.colors[2].a = math.Clamp(self.colors[2].a - dt * speedFadeOut, 0, 255)
	

	self.currentRadius = self.currentRadius + dt * self.speed
	self.timer = (self.timer or 0) + dt

	local flag1 = self.timer >= self.duration
	local flag2 = self.timer >= self.duration + self.period

	if flag1 then
		self.colors[3].a = math.Clamp(self.colors[3].a - dt * self.speedFadeOut2, 0, 255)
	end

	if not self.flag2 and flag2 then
		self:Start(LocalPlayer(), self.targetRadius, self.speed, self.limitent, self.startcolors)
		surface.PlaySound(self.scan_sound or sixs_scan_sound:GetString())
	end

	self.flag1 = flag1
	self.flag2 = flag2
end

hook.Add('Think', 'sixsense', function() sixsense:Think() end)

local white = Color(255, 255, 255, 255)
local wireframe_mat = Material('models/wireframe')
local vol_light001_mat = Material('Models/effects/vol_light001')
function sixsense:Draw()
	if not self.enable then
		return 
	end
	local plypos = LocalPlayer():GetPos()
	local currentRadiusSqr = self.currentRadius * self.currentRadius
	local color1, color2, color3 = unpack(self.colors)
	
	local len = #self.entqueue

	if len > 0 then
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

					if IsValid(ent.sixs_skeleton) then
						ent.sixs_skeleton:DrawModel()
					end	
				end
			render.MaterialOverride()

		render.PopRenderTarget()
	end

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
			if len > 0 then
				surface.SetDrawColor(color3.r, color3.g, color3.b, 255)
				sixsense_mat:SetFloat('$alpha', color3.a / 255)
				surface.SetMaterial(sixsense_mat)
				surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
			end
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
		cam.Start2D()
			surface.SetDrawColor(color2.r, color2.g, color2.b, color2.a)
			surface.DrawRect(0, 0, ScrW(), ScrH())
		cam.End2D()

	render.SetStencilEnable(false)
	render.SuppressEngineLighting(false)
end

local function DrawSafe()
	local succ, err = pcall(sixsense.Draw, sixsense)
	if not succ then
		print(err)
		render.SuppressEngineLighting(true)
		render.SetStencilEnable(false)
	end
end

hook.Add('PostDrawOpaqueRenderables', 'sixsense', DrawSafe)
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

		RunConsoleCommand(sixs_color1:GetName(), '0 0 0 170')
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

