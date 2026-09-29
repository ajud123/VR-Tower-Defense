extends Node3D

var xr_interface: XRInterface

func _ready():
	xr_interface = XRServer.find_interface("OpenXR")
	var force_desktop := "--desktop" in OS.get_cmdline_user_args()
	if not force_desktop and xr_interface and xr_interface.is_initialized():
		$DesktopControls.hide()
		print("OpenXR initialized successfully")

		# Turn off v-sync!
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

		# Change our main viewport to output to the HMD
		get_viewport().use_xr = true
	else:
		get_viewport().use_xr = false
		$DesktopPlayer.activate()
		print("Desktop mode: WASD move, Q/E down/up, Shift boost, mouse look, Escape releases cursor")
