extends Control
class_name DayColorVisualizer

const HOURS_PER_DAY := 24.0
const MINUTES_PER_HOUR := 60.0

@export var background_texture : Texture :
	set(value):
		background_texture = value
		if background_texture_rect:
			background_texture_rect.texture = value

@export var daytime_color_texture : Texture :
	set(value):
		daytime_color_texture = value
		if daytime_shader:
			daytime_shader.set_shader_param("day_time_colors", value)

@export var twilight_duration_factor := 1.0 :
	set(value):
		twilight_duration_factor = value
		if daytime_shader:
			daytime_shader.set_shader_param("twilight_duration_factor", value)

var eot_values : Dictionary
var daytime_shader : ShaderMaterial
var play_day_shader : bool
var playback_value : float
var playback_duration : float

@onready var eot_node = %CustomEOT
@onready var background_texture_rect = %BackgroundColor
@onready var daytime_shader_area = %CurrentDayShaderArea
@onready var day_spin_box = %DaySpinBox
@onready var daytime_time_slider = %DayTimeSlider
@onready var current_time_label = %CurrentTimeLabel
@onready var days_per_year_spin_box = %DaysPerYearSpinBox
@onready var playback_speed_spin_box = %SpeedSpinBox
@onready var twilight_factor_spin_box = %TwilightFactorSpinBox


func _ready() -> void:
	daytime_shader = daytime_shader_area.material
	days_per_year_spin_box.value = eot_node.days_per_year
	
	# Connect it after initial setting it to prevent double eot calculation
	days_per_year_spin_box.value_changed.connect(_on_DaysPerYearSpinBox_value_changed)
	day_spin_box.max_value = eot_node.days_per_year
	
	_on_SpeedSpinBox_value_changed(playback_speed_spin_box.value)
	
	update_displayed_day(day_spin_box.value)


func _process(_delta : float) -> void:
	if play_day_shader:
		process_daytime(_delta)


func process_daytime(_delta : float) -> void:
	var slider_range = daytime_time_slider.max_value - daytime_time_slider.min_value
	var playback_delta = slider_range / playback_duration * _delta
	playback_value = daytime_time_slider.min_value + fposmod(playback_value + playback_delta, slider_range)
	daytime_time_slider.value = playback_value


func update_displayed_day(_day : float) -> void:
	eot_values = eot_node.get_full_info_about_day(_day)
	
#	printt("DayColorVisualizer.gd: Displaying new EOT values: ", eot_values)
	
	if daytime_shader:
		daytime_shader.set_shader_parameter("sunrise_time", eot_values["sunrise_pct"])
		daytime_shader.set_shader_parameter("sunset_time", eot_values["sunset_pct"])
		daytime_shader.set_shader_parameter("twilight_duration", eot_values["twilight_duration_pct"])
	
	update_displayed_time(daytime_time_slider.value)


func update_displayed_time(_time : float) -> void:
	var day_pct = _time / (daytime_time_slider.max_value - daytime_time_slider.min_value)
	var time = day_pct * HOURS_PER_DAY
	var hour = int(time)
	var minute = (time - hour) * MINUTES_PER_HOUR
	current_time_label.text = "%2d:%02d" % [hour, minute]
	daytime_shader.set_shader_parameter("current_time", day_pct)


func _on_DaySpinBox_value_changed(_value : float) -> void:
	eot_values = eot_node.get_full_info_about_day(_value)
	update_displayed_day(_value)


func _on_DayTimeSlider_value_changed(_value : float) -> void:
	update_displayed_time(_value)


func _on_AutoPlayCheckBox_toggled(_button_pressed : bool) -> void:
	play_day_shader = _button_pressed
	

func _on_SpeedSpinBox_value_changed(_value : float) -> void:
	playback_duration = _value


func _on_TwilightFactorSpinBox_value_changed(_value : float) -> void:
	twilight_duration_factor = _value


func _on_DaysPerYearSpinBox_value_changed(_value : float) -> void:
	$CustomEOT.days_per_year = _value
	update_displayed_day(_value)
