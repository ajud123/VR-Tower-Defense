class_name Boombox
extends StaticBody3D
## Cozy tabletop radio / boombox sitting on the picnic bench beside the player.
## Plays spatial 3D cozy acoustic music right out of its speakers.
## Poke it with a VR hand, point + trigger, or left-click on desktop to cycle
## through the 3 radio stations or turn it OFF.

const STATIONS := [
	{"label": "FM 1  TOWN", "path": "res://assets/audio/music/station_town.ogg"},
	{"label": "FM 2  HARVEST", "path": "res://assets/audio/music/station_harvest.ogg"},
	{"label": "FM 3  TAVERN", "path": "res://assets/audio/music/station_tavern.ogg"},
	{"label": "RADIO OFF", "path": ""},
]

const ON_LED_COLOR := Color(1.0, 0.78, 0.25)
const OFF_LED_COLOR := Color(0.22, 0.18, 0.15)
const HOVER_COLOR := Color(1.0, 0.9, 0.55)
const COOLDOWN_MSEC := 300

@export var start_station: int = 0
@export var music_volume_db: float = -12.5

@onready var _dial: Label3D = $Dial
@onready var _led: MeshInstance3D = $PowerLED
@onready var _speaker_l: MeshInstance3D = $SpeakerLeft
@onready var _speaker_r: MeshInstance3D = $SpeakerRight
@onready var _body: MeshInstance3D = $Body
@onready var _notes: CPUParticles3D = $MusicMotes
@onready var _poke_zone: Area3D = $PokeZone

var _player: AudioStreamPlayer3D
var _station_index: int = 0
var _streams: Array[AudioStream] = []
var _hover_count: int = 0
var _next_click_msec: int = 0
var _pulse_time: float = 0.0
var _led_mat: StandardMaterial3D
var _body_mat: StandardMaterial3D


func _ready() -> void:
	# Duplicate materials so hover/power glow only affects this radio.
	if _led and _led.mesh and _led.mesh.material:
		_led_mat = _led.mesh.material.duplicate() as StandardMaterial3D
		_led.material_override = _led_mat
	if _body and _body.mesh and _body.mesh.material:
		_body_mat = _body.mesh.material.duplicate() as StandardMaterial3D
		_body.material_override = _body_mat

	for st in STATIONS:
		var path: String = st.path
		_streams.append(Audio.load_looping(path) if not path.is_empty() else null)

	_player = AudioStreamPlayer3D.new()
	_player.bus = &"Music" if AudioServer.get_bus_index("Music") != -1 else &"Master"
	_player.volume_db = music_volume_db
	_player.unit_size = 1.6
	_player.max_distance = 12.0
	_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_player.position = Vector3(0, 0.065, 0.04)
	add_child(_player)

	if _poke_zone:
		_poke_zone.area_entered.connect(func(_hand: Area3D) -> void: interact())

	_apply_station(clampi(start_station, 0, STATIONS.size() - 1), false)


func _process(delta: float) -> void:
	if _player and _player.playing:
		_pulse_time += delta
		var thump := 1.0 + sin(_pulse_time * 8.5) * 0.045
		_speaker_l.scale = Vector3(thump, 1.0, thump)
		_speaker_r.scale = Vector3(thump, 1.0, thump)
	else:
		_speaker_l.scale = Vector3.ONE
		_speaker_r.scale = Vector3.ONE


func interact(_point: Vector3 = Vector3.ZERO) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_click_msec:
		return
	_next_click_msec = now + COOLDOWN_MSEC
	Audio.play_3d("radio_click", global_position)
	_apply_station((_station_index + 1) % STATIONS.size(), true)
	# Cute tactile bounce when tapped.
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.06, 0.93, 1.06), 0.06)
	tween.tween_property(self, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hover_enter() -> void:
	_hover_count += 1
	_update_hover()


func hover_exit() -> void:
	_hover_count = maxi(_hover_count - 1, 0)
	_update_hover()


func _update_hover() -> void:
	if _body_mat:
		_body_mat.emission_enabled = _hover_count > 0
		_body_mat.emission = HOVER_COLOR
		_body_mat.emission_energy_multiplier = 0.18 if _hover_count > 0 else 0.0


func _apply_station(index: int, play_tune: bool) -> void:
	_station_index = index
	var station: Dictionary = STATIONS[index]
	var stream: AudioStream = _streams[index]
	_dial.text = station.label

	var playing := stream != null
	if playing:
		_player.stream = stream
		_player.play()
		_dial.modulate = Color(0.92, 1.0, 0.85)
	else:
		_player.stop()
		_dial.modulate = Color(0.6, 0.62, 0.58)

	if _led_mat:
		_led_mat.albedo_color = ON_LED_COLOR if playing else OFF_LED_COLOR
		_led_mat.emission_enabled = playing
		_led_mat.emission = ON_LED_COLOR
		_led_mat.emission_energy_multiplier = 1.4 if playing else 0.0

	if _notes:
		_notes.emitting = playing

	if play_tune and playing:
		_pulse_time = 0.0
