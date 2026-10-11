extends Node3D
## The player: headset and hands when OpenXR is running, otherwise a desktop
## fly camera for testing. Drop one into any scene where the player starts.

## Desktop camera height above the rig (eye height).
@export var desktop_eye_height: float = 1.6
## Desktop camera pitch; negative looks down.
@export_range(-85.0, 85.0) var desktop_pitch_degrees: float = -11.5

var xr_interface: XRInterface


func _ready():
	xr_interface = XRServer.find_interface("OpenXR")
	var force_desktop := "--desktop" in OS.get_cmdline_user_args()
	if not force_desktop and xr_interface and xr_interface.is_initialized():
		print("OpenXR initialized successfully")

		# Turn off v-sync!
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

		# Change our main viewport to output to the HMD
		get_viewport().use_xr = true
		$XROrigin3D/XRCamera3D.make_current()
	else:
		get_viewport().use_xr = false
		# Untracked hands would just sit on the floor, so switch them off.
		$XROrigin3D.hide()
		$XROrigin3D.process_mode = Node.PROCESS_MODE_DISABLED
		$DesktopPlayer.position.y = desktop_eye_height
		$DesktopPlayer/Camera3D.rotation.x = deg_to_rad(desktop_pitch_degrees)
		$DesktopPlayer.activate()
		print("Desktop mode: WASD move, Q/E down/up, Shift boost, mouse look, left click press, Escape releases cursor")
