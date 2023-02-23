extends Control

enum PLOT_OPTION {
	EOT,
	Sunset,
	Sunrise,
	TwilightDuration,
	Declination
}

const DEFAULT_NUM_TICKS := 15
const GRAPH_BORDER_THICKNESS := 3
const VERTICAL_PLOT_MARGIN := 0.05
const TIKS_NUM_DECIMALS := 2

@export var plot_option := PLOT_OPTION.EOT :
	set(value):
		plot_option = value
		if plots_anchor:
			_plot_selected_eot_values()

var current_plot_rect_pos : Vector2
var current_plot_rect_size : Vector2

var zero_plot_line : Line2D

var full_eot_infos : Array

@onready var plots_anchor = %PlotsBackground
@onready var plot_outline = %PlotOutline
@onready var x_ticks_anchor = %XTicks
@onready var y_ticks_anchor = %YTicks
@onready var y_ticks_margin = %Margin
@onready var x_label = %XLabel
@onready var y_label = %YLabel
@onready var plot_option_dropdown = %PlotOptionDropdown


func _ready() -> void:
	for option in PLOT_OPTION.keys().size():
		plot_option_dropdown.add_item(PLOT_OPTION.keys()[option], option)
	
	full_eot_infos = $CustomEOT.get_all_values_till(365)
	
	# Wait till everything has settled before 1st draw
	await get_tree().process_frame
	
	_plot_selected_eot_values()


func _plot_selected_eot_values() -> void:
	var values = []
	var plotted_y_label = "EOT\n[planet min]"
	
	for i in range(full_eot_infos.size()):
		match (plot_option):
			PLOT_OPTION.EOT:
				values.append(full_eot_infos[i]["eot_vector"])
			PLOT_OPTION.Sunrise:
				values.append(Vector2(i, full_eot_infos[i]["sunrise"]))
			PLOT_OPTION.Sunset:
				values.append(Vector2(i, full_eot_infos[i]["sunset"]))
			PLOT_OPTION.TwilightDuration:
				values.append(Vector2(i, full_eot_infos[i]["twilight_duration"]))
			PLOT_OPTION.Declination:
				values.append(Vector2(i, full_eot_infos[i]["declination"]))
	
	match (plot_option):
		PLOT_OPTION.Sunrise:
			plotted_y_label = "Sunrise\n[planet min]"
		PLOT_OPTION.Sunset:
			plotted_y_label = "Sunset\n[planet min]"
		PLOT_OPTION.TwilightDuration:
			plotted_y_label = "Sunrise\n[planet min]"
		PLOT_OPTION.Declination:
			plotted_y_label = "Declination\n[deg]"
	
	_plot_vectors(values, 3, true, true, false, "Days since Jan 1", plotted_y_label)


func _plot_vectors(_vectors : PackedVector2Array, _line_thickness : float = 3, \
		_clear_plots : bool = true, _round_x_ticks : bool = false, _round_y_ticks : bool = false, \
		_x_label_text : String = "", _y_label_text : String = "") -> void:
	
	var x_values = []
	var y_values = []
	
	for i in range(_vectors.size()):
		x_values.append(_vectors[i].x)
		y_values.append(_vectors[i].y)
	
	_plot_values(x_values, y_values, _line_thickness, _clear_plots, _round_x_ticks, \
			_round_y_ticks, _x_label_text, _y_label_text)


func _plot_values(_x_values : Array, _y_values : Array, _line_thickness : float = 3, \
		_clear_plots : bool = true, _round_x_ticks : bool = false, _round_y_ticks : bool = false, \
		_x_label_text : String = "", _y_label_text : String = "", _ignore_nans : bool = true) -> void:
	
	assert(_x_values.size() == _y_values.size())
	
	for plot in plots_anchor.get_children():
		plot.queue_free()
	
	if zero_plot_line:
		zero_plot_line.queue_free()
		zero_plot_line = null
	
	var x_min = _x_values.min()
	var x_max = _x_values.max()
	
	var y_min = _y_values.min()
	var y_max = _y_values.max()
	
	if _ignore_nans and (is_nan(x_min) or is_nan(x_max)):
		printerr("Could not plot because either the min or max x-values are NAN.")
		return
	if _ignore_nans and (is_nan(y_min) or is_nan(y_max)):
		printerr("Could not plot because either the min or max y-values are NAN.")
		return
	
	_add_ticks_to_anchor(x_ticks_anchor, true, x_min, x_max, DEFAULT_NUM_TICKS, _round_x_ticks)
	_add_ticks_to_anchor(y_ticks_anchor, false, y_min, y_max, DEFAULT_NUM_TICKS, _round_y_ticks)
	
	x_label.text = _x_label_text
	y_label.text = _y_label_text
	
	var plots_rect_size = plots_anchor.size
	
	var min_draw_x = 0
	var max_draw_x = plots_rect_size.x
	
	var min_draw_y = plots_rect_size.y * VERTICAL_PLOT_MARGIN
	var max_draw_y = plots_rect_size.y * (1 - VERTICAL_PLOT_MARGIN)
	
	if y_max > 0 and y_min < 0:
		var zero_y_pos = _find_draw_y_pos(0, y_min, y_max, min_draw_y, max_draw_y)
		zero_plot_line = Line2D.new()
		zero_plot_line.width = _line_thickness
		zero_plot_line.default_color = Color.WHITE
		plots_anchor.add_child(zero_plot_line)
		zero_plot_line.name = "ZeroPlotLine"
		zero_plot_line.add_point(Vector2(0, zero_y_pos))
		zero_plot_line.add_point(Vector2(plots_rect_size.x, zero_y_pos))
	
	var plot_line = Line2D.new()
	plot_line.name = "Plot"
	plot_line.width = _line_thickness
	plot_line.default_color = Color.BLUE
	plots_anchor.add_child(plot_line)
	var plot_no = plots_anchor.get_child_count() - int(!!zero_plot_line)
	plot_line.name = ("Plot %d" % plot_no)
	
	for i in range(_x_values.size()):
		if _ignore_nans and is_nan(_x_values[i]):
			continue
		var x_pos = _find_draw_x_pos(_x_values[i], x_min, x_max, min_draw_x, max_draw_x)
		var y_pos = _find_draw_y_pos(_y_values[i], y_min, y_max, min_draw_y, max_draw_y)
		
		plot_line.add_point(Vector2(x_pos, y_pos))
	
	_draw_graph_border(GRAPH_BORDER_THICKNESS)


func _add_ticks_to_anchor(_ticks_anchor : Control, _horizontal_ticks : bool, _min_value : float, \
		_max_value : float, _num_ticks : int, _round_ticks : bool = false) -> void:
	
	assert(_ticks_anchor != null)
	
	for child in _ticks_anchor.get_children():
		child.queue_free()
	
	var tick_values = _generate_tick_values(_num_ticks, _min_value, _max_value, _round_ticks)
	
	if !_horizontal_ticks:
		# Invert to draw positive y towards the top
		tick_values.reverse()
		
		# Update vertical margin
#		var y_margin_size = plots_anchor.size.y * VERTICAL_PLOT_MARGIN
#		y_ticks_margin.add_constant_override("margin_top", y_margin_size)
#		y_ticks_margin.add_constant_override("margin_bottom", y_margin_size)
	
	for i in range(tick_values.size()):
		var tick_label = Label.new()
		tick_label.name = "TickLabel" + str(i)
		_ticks_anchor.add_child(tick_label)
		if _round_ticks:
			tick_label.text = str(tick_values[i])
		else:
			tick_label.text = str(tick_values[i]).pad_decimals(TIKS_NUM_DECIMALS)
		
		if i < tick_values.size() - 1:
			var spacer = Control.new()
			spacer.name = "Spacer" + str(i)
			_ticks_anchor.add_child(spacer)
			if _horizontal_ticks:
				spacer.size_flags_horizontal = SIZE_EXPAND_FILL
			else:
				spacer.size_flags_vertical = SIZE_EXPAND_FILL


func _generate_tick_values(_num_ticks : int, _min_value : float, _max_value : float, \
		_round_ticks : bool = false) -> PackedFloat32Array:
	
	assert(_max_value > _min_value)
	
	var value_range = _max_value - _min_value
	
	if value_range <= 0:
		_num_ticks = 1
	
	var step_size = float(value_range) / float(_num_ticks)
	
	var ticks = []
	for i in range(_num_ticks + 1):
		var tick_value = _min_value + i * step_size
		if _round_ticks:
			tick_value = int(tick_value) # Or use: stepify(tick_value,0.01)
		ticks.append(tick_value)
	
	return ticks


func _find_draw_x_pos(_value : float, _val_min : float, _val_max : float, _draw_min : float, \
		_draw_max : float) -> float:
	
	return _transpose_pct_range(_value, _val_min, _val_max, _draw_min, _draw_max) + _draw_min


func _find_draw_y_pos(_value : float, _val_min : float, _val_max : float, _draw_min : float, \
		_draw_max : float, _ignore_nans : bool = true) -> float:
	
	if (_ignore_nans and is_nan(_value)):
		return 0.0
	
	# Subtract from _draw_max as we want to draw towards negative y
	return _draw_max - _transpose_pct_range(_value, _val_min, _val_max, _draw_min, _draw_max) + _draw_min


func _transpose_pct_range(_value : float, _from_min : float, _from_max : float, _to_min : float, \
		_to_max : float) -> float:
	
	assert(_value <= _from_max)
	assert(_value >= _from_min)
	
	var from_range = _from_max - _from_min
	var to_range = _to_max - _to_min
	
	var from_pct = (_value - _from_min) / from_range
	
	return to_range * from_pct + _to_min


func _draw_graph_border(_line_thickness : float) -> void:
	if !plot_outline:
		return
	
	var line_offset = _line_thickness / 2.0
	plot_outline.clear_points()
	plot_outline.add_point(plots_anchor.position \
		+ Vector2(-line_offset, -line_offset))
	plot_outline.add_point(plots_anchor.position \
		+ Vector2(-line_offset, plots_anchor.size.y + line_offset))
	plot_outline.add_point(plots_anchor.position \
		+ plots_anchor.size + Vector2(line_offset, line_offset))
	plot_outline.add_point(plots_anchor.position \
		+ Vector2(plots_anchor.size.x + line_offset, -line_offset))
	plot_outline.add_point(plots_anchor.position \
		+ Vector2(-line_offset, -line_offset))
	plot_outline.width = _line_thickness
	plot_outline.default_color = Color.WHITE


#func _on_CustomPlotDisplay_resized() -> void:
#	draw_graph_border(GRAPH_BORDER_THICKNESS)
#	if plots_anchor:
#		var new_y_margin_size = plots_anchor.rect_size.y * VERTICAL_PLOT_MARGIN
#		y_ticks_margin.add_constant_override("margin_top", new_y_margin_size)
#		y_ticks_margin.add_constant_override("margin_bottom", new_y_margin_size)
#
#		current_plot_rect_pos = plots_anchor.rect_rotation
#		current_plot_rect_size = plots_anchor.rect_size


func log2(_a : float) -> float:
	return log(_a) / log(2)


func _on_PlotOptionDropdown_item_selected(_index : int) -> void:
	plot_option = _index
