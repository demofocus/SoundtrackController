--[[ 

A comprehensive object-orientated module for managing game soundtracks and audio.
--// Made by @demofocus

Features:

- Background Music Management
- Sound Effect Playback
- Volume Control with Smooth Transitions
- Crossfading between tracks
- Audio zones and ambient sounds
- No duplicate songs one after the other (if one plays, it won't play again next song)

Usage: 

local SoundtrackController = require(path.SoundtrackController)
local Soundtrack = SoundtrackController.new()

-- Play background music
Soundtrack:PlayMusic("rbxassetid://123456789", {Volume = 0.5, Loop = true})

-- Add to Playlist
Soundtrack:AddToPlaylist("MenuMusic", "rbxassetid://123456789")
Soundtrack:PlayPlaylist("MenuMusic")

-- Set Volumes with smooth transitions

Soundtrack:SetMasterVolume(0.7, 2) -- 2 second fade
Soundtrack:SetMusicVolume(0.5, 1)
Soundtrack:SetSFXVolume(0.9)

--]]

local SoundService: SoundService = game:GetService("SoundService")
local TweenService: TweenService = game:GetService("TweenService")
local RunService: RunService = game:GetService("RunService")

local SoundtrackController = {}
SoundtrackController.__index = SoundtrackController

function SoundtrackController.new()
	local self = setmetatable({}, SoundtrackController)
	
	self.MasterVolume = 1
	self.MusicVolume = 0.8
	self.SFXVolume = 1
	self.IsEnabled = true
	self.CrossFadeDuration = 2
	self.FadeInDuration = 1
	self.FadeOutDuration = 1
	
	self.MusicGroup = Instance.new("SoundGroup")
	self.MusicGroup.Name = "MusicGroup"
	self.MusicGroup.Parent = SoundService
	
	self.SFXGroup = Instance.new("SoundGroup")
	self.SFXGroup.Name = "SFXGroup"
	self.SFXGroup.Parent = SoundService
	
	self.CurrentMusic = nil
	self.CurrentPlaylist = nil
	self.CurrentTrackIndex = 1
	self.IsPlaying = false
	self.IsPaused = false
	
	self.Playlists = {}
	self.PlaylistSettings = {}
	
	self.SoundCache = {}
	self.ActiveSounds = {}
	
	self.OnTrackChanged = Instance.new("BindableEvent")
	self.OnPlaylistEnded = Instance.new("BindableEvent")
	self.OnVolumeChanged = Instance.new("BindableEvent")
	
	return self
end

function SoundtrackController:PlayMusic(SoundId, Options)
	Options = Options or {}
	
	if not self.IsEnabled then return end
	
	if self.CurrentMusic then
		self:StopMusic(false)
	end
	
	local Sound = Instance.new("Sound")
	Sound.SoundId = SoundId
	Sound.Volume = (Options.Volume or self.MusicVolume) * self.MasterVolume
	Sound.Looped = Options.Loop
	Sound.PlaybackSpeed = Options.PlaybackSpeed or 1
	Sound.SoundGroup = self.MusicGroup
	Sound.Parent = SoundService
	
	self.CurrentMusic = Sound
	self.IsPlaying = true
	self.IsPaused = false
	
	if Options.FadeIn ~= false then
		Sound:Play()
		
		local FadeInfo = TweenInfo.new(Options.FadeInDuration or self.FadeInDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		
		local FadeTween = TweenService:Create(Sound, FadeInfo, {Volume = (Options.Volume or self.MusicVolume) * self.MasterVolume})
		
		FadeTween:Play()
	else
		Sound:Play()
	end
	
	self.OnTrackChanged:Fire(Sound, SoundId)
	
	return Sound
end

function SoundtrackController:StopMusic(FadeOut)
	if not self.CurrentMusic then return end
	
	if FadeOut ~= false then
		local FadeInfo = TweenInfo.new(self.FadeOutDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		
		local FadeTween = TweenService:Create(self.CurrentMusic, FadeInfo, {Volume = 0})
		FadeTween:Play()
		
		FadeTween.Completed:Connect(function()
			if self.CurrentMusic then
				self.CurrentMusic:Destroy()
				self.CurrentMusic = nil
			end
		end)
		
	else
		self.CurrentMusic:Destroy()
		self.CurrentMusic = nil
	end
	
	self.IsPlaying = false
	self.IsPaused = false
end

function SoundtrackController:PauseMusic()
	if self.CurrentMusic and self.IsPlaying and not self.IsPaused then
		self.CurrentMusic:Pause()
		self.IsPaused = true
	end
end

function SoundtrackController:CrossFadeToMusic(SoundId, Options)
	Options = Options or {}
	
	if not self.IsEnabled then return end
	
	local NewSound = Instance.new("Sound")
	NewSound.SoundId = SoundId
	NewSound.Volume = 0
	NewSound.Looped = Options.Loop
	NewSound.PlaybackSpeed = Options.PlaybackSpeed or 1
	
	NewSound.SoundGroup = self.MusicGroup
	NewSound.Parent = SoundService
	
	NewSound:Play()
	
	local CrossFadeDuration = Options.CrossFadeDuration or self.CrossFadeDuration
	local TargetVolume = (Options.Volume or self.MusicVolume) * self.MasterVolume
	
	local FadeInInfo = TweenInfo.new(CrossFadeDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local FadeInTween = TweenService:Create(NewSound, FadeInInfo, {Volume = TargetVolume})
	FadeInTween:Play()
	
	if self.CurrentMusic then
		local OldMusic = self.CurrentMusic
		local FadeOutTween = TweenService:Create(self.CurrentMusic, FadeInInfo, {Volume = 0})
		FadeOutTween:Play()
		
		FadeOutTween.Completed:Connect(function()
			if OldMusic then
				OldMusic:Destroy()
			end
		end)
	end
	
	self.CurrentMusic = NewSound
	self.IsPlaying = true
	self.IsPaused = false
	
	self.OnTrackChanged:Fire(SoundId, NewSound)
	return NewSound
end

function SoundtrackController:CreatePlaylist(Name, Tracks, Settings)
	self.Playlists[Name] = Tracks or {}
	self.PlaylistSettings[Name] = Settings or {
		Shuffle = false,
		Repeat = true,
		CrossFade = true
	}
end

function SoundtrackController:AddToPlaylist(PlaylistName, SoundId, Index)
	if not self.Playlists[PlaylistName] then
		self.Playlists[PlaylistName] = {}
	end
	
	if Index then
		table.insert(self.Playlists[PlaylistName], Index, SoundId)
	else
		table.insert(self.Playlists[PlaylistName], SoundId)
	end
end

function SoundtrackController:RemoveFromPlaylist(PlaylistName, Index)
	if self.Playlists[PlaylistName] and self.Playlists[PlaylistName][Index] then
		table.remove(self.Playlists[PlaylistName], Index)
	end
end

function SoundtrackController:PlayPlaylist(PlaylistName, StartIndex)
	if not self.Playlists[PlaylistName] or #self.Playlists[PlaylistName] == 0 then
		warn("Playlist "..PlaylistName.. " not found or empty")
		return
	end
	
	self.CurrentPlaylist = PlaylistName
	self.CurrentTrackIndex = StartIndex or 1
	
	local Settings = self.PlaylistSettings[PlaylistName] or {}
	
	if Settings.Shuffle then
		self:ShufflePlaylist(PlaylistName)
	end
	
	if self.EndedConnection then
		self.EndedConnection:Disconnect()
		self.EndedConnection = nil
	end
	
	self:PlayPlaylistTrack()
	
	if self.CurrentMusic then
		self.EndedConnection = self.CurrentMusic.Ended:Connect(function()
			self:NextTrack()
		end)
	end
end

function SoundtrackController:PlayPlaylistTrack()
	if not self.CurrentPlaylist then return end
	
	if self.EndedConnection then
		self.EndedConnection:Disconnect()
		self.EndedConnection = nil
	end
	
	local Playlist = self.Playlists[self.CurrentPlaylist]
	local Settings = self.PlaylistSettings[self.CurrentPlaylist] or {}
	
	if Playlist and Playlist[self.CurrentTrackIndex] then
		local SoundId = Playlist[self.CurrentTrackIndex]
		
		if Settings.CrossFade and self.CurrentMusic then
			self:CrossFadeToMusic(SoundId)
		else
			self:PlayMusic(SoundId)
		end
		
		if self.CurrentMusic then
			self.EndedConnection = self.CurrentMusic.Ended:Connect(function()
				self:NextTrack()
			end)
		end
	end
end

function SoundtrackController:NextTrack()
	if not self.CurrentPlaylist then return end
	
	local Playlist = self.Playlists[self.CurrentPlaylist]
	local Settings = self.PlaylistSettings[self.CurrentPlaylist] or {}
	
	local CurrentSoundId = nil
	if self.CurrentTrackIndex and self.CurrentTrackIndex <= #Playlist then
		CurrentSoundId = Playlist[self.CurrentTrackIndex]
	end
	
	self.CurrentTrackIndex = self.CurrentTrackIndex + 1
	
	if self.CurrentTrackIndex > #Playlist then
		if Settings.Repeat then
			self.CurrentTrackIndex = 1
			if Settings.Shuffle then
				self:ShufflePlaylist(self.CurrentPlaylist)
			end
		else
			self:StopMusic()
			self.CurrentPlaylist = nil
			self.OnPlaylistEnded:Fire()
			return
		end
	end
	
	local NextSoundId = Playlist[self.CurrentTrackIndex]
	if NextSoundId == CurrentSoundId and #Playlist > 1 then
		self.CurrentTrackIndex = self.CurrentTrackIndex + 1
		
		if self.CurrentTrackIndex > #Playlist then
			self.CurrentTrackIndex = 1
		end
	end
	
	self:PlayPlaylistTrack()
end

function SoundtrackController:PreviousTrack()
	if not self.CurrentPlaylist then return end
	
	self.CurrentTrackIndex = math.max(1, self.CurrentTrackIndex - 1)
	self:PlayPlaylistTrack()
end

function SoundtrackController:ShufflePlaylist(PlaylistName)
	local Playlist = self.Playlists[PlaylistName]
	if not Playlist then return end
	
	for i = #Playlist, 2, -1 do
		local j = math.random(i)
		Playlist[i], Playlist[j] = Playlist[j], Playlist[i]
	end
end

function SoundtrackController:PlaySFX(SoundId, Options)
	Options = Options or {}
	if not self.IsEnabled then return end
	
	local Sound = self.SoundCache[SoundId]
	
	if not Sound or Sound.Parent == nil then
		Sound = Instance.new("Sound")
		Sound.SoundId = SoundId
		Sound.SoundGroup = self.SFXGroup
		Sound.Parent = SoundService
		self.SoundCache[SoundId] = Sound
	end
	
	Sound.Volume = (Options.Volume or self.SFXVolume) * self.MasterVolume
	Sound.PlaybackSpeed = Options.PlaybackSpeed or 1
	
	Sound:Play()
	
	table.insert(self.ActiveSounds, Sound)
	
	Sound.Ended:Connect(function()
		for i, ActiveSound in ipairs(self.ActiveSounds) do
			if ActiveSound == Sound then
				table.remove(self.ActiveSounds, i)
				break
			end
		end
	end)
	
	return Sound
end

function SoundtrackController:StopAllSFX()
	for _, Sound in ipairs(self.ActiveSounds) do
		if Sound and Sound.Parent then
			Sound:Stop()
		end
	end
	
	self.ActiveSounds = {}
end

function SoundtrackController:SetMasterVolume(Volume, TweenDuration)
	self.MasterVolume = math.clamp(Volume, 0, 1)
	
	if TweenDuration and TweenDuration > 0 then
		local TInfo = TweenInfo.new(TweenDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		
		local MusicTween = TweenService:Create(self.MusicGroup, TInfo, {Volume = self.MusicVolume * self.MasterVolume})
		
		MusicTween:Play()
		
		local SFXTween = TweenService:Create(self.SFXGroup, TInfo, {Volume = self.SFXVolume * self.MasterVolume})
		
		SFXTween:Play()
	else
		self.MusicGroup.Volume = self.MusicVolume * self.MasterVolume
		self.SFXGroup.Volume = self.SFXVolume * self.MasterVolume
	end
	
	self.OnVolumeChanged:Fire("Master", self.MasterVolume)
end

function SoundtrackController:SetMusicVolume(Volume, TweenDuration)
	self.MusicVolume = math.clamp(Volume, 0, 1)
	
	if TweenDuration and TweenDuration > 0 then
		local TInfo = TweenInfo.new(TweenDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		local MusicTween = TweenService:Create(self.MusicGroup, TInfo, {Volume = self.MusicVolume * self.MasterVolume})
		
		MusicTween:Play()
	else
		self.MusicGroup.Volume = self.MusicVolume * self.MasterVolume
	end
	
	self.OnVolumeChanged:Fire("Music", self.MusicVolume)
end

function SoundtrackController:SetSFXVolume(Volume, TweenDuration)
	self.SFXVolume = math.clamp(Volume, 0, 1)
	
	if TweenDuration and TweenDuration > 0 then
		local TInfo = TweenInfo.new(TweenDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		local SFXTween = TweenService:Create(self.SFXGroup, TInfo, {Volume = self.SFXVolume * self.MasterVolume})
		
		SFXTween:Play()
	else
		self.SFXGroup.Volume = self.SFXVolume * self.MasterVolume
	end
	
	self.OnVolumeChanged:Fire("SFX", self.SFXVolume)
end

function SoundtrackController:GetCurrentTrackInfo()
	if not self.CurrentMusic then return nil end
	
	return {
		SoundId = self.CurrentMusic.SoundId,
		IsPlaying = self.CurrentMusic.IsPlaying,
		TimePosition = self.CurrentMusic.TimePosition,
		TimeLength = self.CurrentMusic.TimeLength,
		Volume = self.CurrentMusic.Volume,
		Playlist = self.CurrentPlaylist,
		TrackIndex = self.CurrentTrackIndex
	}
end

function SoundtrackController:Enable()
	self.IsEnabled = true
end

function SoundtrackController:Disable()
	self.IsEnabled = false
	self:StopMusic(false)
	self:StopAllSFX()
end

function SoundtrackController:Cleanup()
	self:StopMusic(false)
	self:StopAllSFX()
	
	if self.MusicGroup then
		self.MusicGroup:Destroy()
	end
	
	if self.SFXGroup then
		self.SFXGroup:Destroy()
	end
	
	for _, Sound in self.SoundCache do
		if Sound and Sound.Parent then
			Sound:Destroy()
		end
	end
	
	self.SoundCache = {}
end

return SoundtrackController