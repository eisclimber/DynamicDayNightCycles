extends Node

## Duration of a real world day: 1 day = 60 * 60 * 24 = 86400 in seconds
const DEFAULT_SECONDS_PER_DAY := 86400.0
## Julian year length in days
const DAYS_IN_JULIAN_CALENDER_YEAR := 365.24
## Approximate and correction the zenit at sunrise/-set of the eath in degrees
const SUNRISE_SUNSET_ZENIT := 90.833
## Difference of sunrise zenit for the of civil twilight in degrees
const CIVIL_TWILIGHT_ZENIT_OFFSET = 6
## The duration of half a day in minutes using the real world's day duration (=DEFAULT_SECONDS_PER_DAY)
const REAL_WORLD_HALF_DAY_MINUTES = 720
## Begin of summertime in pct (based on 27 of March 2022 = Day 87 = Last Sunday in March)
const SUMMER_TIME_BEGIN_PCT = 0.2382
## End of summertime in pct (based on 30 of October 2022 = Day 303 = Last Sunday in October)
const SUMMER_TIME_END_PCT = 0.8296

## Hours per real-world day
const HOURS_PER_DAY := 24.0
## Minutes per real-world hour
const MINUTES_PER_HOUR := 60.0
## Seconds per real-world minute
const SECONDS_PER_MINUTE := 60.0
## Pct of half a day
const HALF_DAY_PCT := 0.5


## How many days a planet year has
@export var days_per_year := DAYS_IN_JULIAN_CALENDER_YEAR
## How many real-world(!) seconds a day has. The actual length of "planet-seconds" are determined in
## proportion of a normal day (day_duration / (24 * 60) and might differ from actual seconds
@export var day_duration := DEFAULT_SECONDS_PER_DAY
## Offset that is automatically added to the calculation of each day
## Can be used to start the year at day = 0 but use calculations of a later day
## E.g. For the year to start on 1st of February this variable must be set to of 31 days for year with 365 days
@export var year_start_day_offset := 0.0

## Latitude of the location for these calculations in degrees
@export var latitude := 48.4442
## Longitude of the locationfor these calculations in degrees
@export var longitude := 8.6913

## Aphel (furthest point in the planets orbit) in meters
@export var orbit_dimension_a := 152100000
## Experts only! Perihel (closest point in the planets orbit) in meters
@export var orbit_dimension_b := 147090000
## Experts only! "Skew" of the earth axis in degrees
@export var obliquity := -23.45


func get_full_info_about_day(_day : float) -> Dictionary:
	"""
	Calculates a set of metrics that describe a day of a planet with specified length.
	The metrics include:
		- "day": The (actual) day of the input starting from Jan 1st (including the year_start_day_offset)
		- "year_pct": The percentage of the day in respect of the year
		- "eot": The value of the equation of time (eot) in minutes
		- "eot_vecor": A vector with the day as x and the eot value as y
		- "declination": The declination (vertical angle) of the plane of the elliptic
		- "solar_noon": The time where the sun stands highes (true noon) in minutes
		- "sunrise": Time of the sunrise in minutes
		- "sunset": Time of the sunset in minutes
		- "is_summertime": If (roughly) is summertime -> +1 hour (based on year 2022 in Germany)
	
	Be Aware: The metrics are approximations and are calculated for UTC-0 
				and do not reflect to summer/winter-time.
	
	Parameters:
		_day: number of day starting from the first day in the year.
	
	returns a Dictionary containing all the values
	"""
	var day = fposmod(_day + year_start_day_offset, days_per_year)
	
	var year_pct = fposmod(day, days_per_year) / days_per_year
	
	var real_world_eot_value = calculate_eot(day)
	var eot_pct =  0.5 + real_world_eot_value * 60 / DEFAULT_SECONDS_PER_DAY
	var eot_value = eot_pct * day_duration / 60  - _calculate_half_day_minutes()
	
	var declination = calculate_declination(day)
	
	var real_world_solar_noon = _calculate_solar_noon_time(real_world_eot_value, declination)
	var solar_noon_pct = 0.5 + real_world_solar_noon / DEFAULT_SECONDS_PER_DAY
	var solar_noon = solar_noon_pct * day_duration / 60
	
	var real_world_sunrise = _calculate_sunrise_or_set_time(real_world_eot_value, declination, false)
	var sunrise_pct = (60 * real_world_sunrise) / DEFAULT_SECONDS_PER_DAY
	var sunrise = sunrise_pct * day_duration / 60
	
	var real_world_sunset = _calculate_sunrise_or_set_time(real_world_eot_value, declination, true)
	var sunset_pct = (60 * real_world_sunset) / DEFAULT_SECONDS_PER_DAY
	var sunset = sunset_pct * day_duration / 60
	
	var real_world_twilight_duration = _calculate_twilight_duration(real_world_eot_value, declination)
	var twilight_duration_pct = (60 * real_world_twilight_duration) / DEFAULT_SECONDS_PER_DAY
	var twilight_duration = twilight_duration_pct * day_duration / 60
	
	return {
		"day" : day, # The day of the eot data (actual day including day offset)
		"year_pct" : year_pct, # The percentage of the day in respect of the year
		"day_duration" : day_duration, # The duration of a day
		"eot" : eot_value, # The value of the equation of time (eot)
		"eot_vector" : Vector2(day, eot_value), # A vector of the day and eot
		"eot_hour_time" : planet_minutes_to_hours(_calculate_half_day_minutes() + eot_value),
		"declination" : declination, # The declination (of the sun at that time)
		"solar_noon": solar_noon, # Time of midday
		"sunrise" : sunrise, # Time of sunrise
		"sunset" : sunset, # Time of sunset
		"twilight_duration" : twilight_duration, # Duration of twilight_duration (starts after sunrise/before sunset)
		# Pcts respectively to day_length in seconds
		"eot_pct" : eot_pct, # EOT in pct
		"one_hour_pct" : day_duration / (HOURS_PER_DAY * MINUTES_PER_HOUR), # Pct of the duration of one hour
		"solar_noon_pct" : solar_noon_pct, # Pct of solar noon
		"sunrise_pct" : sunrise_pct, # Pct of sunrise
		"sunset_pct" : sunset_pct, # Pct of sunset
		"twilight_duration_pct" : twilight_duration_pct, # Pct of twilight duration
		# Is Summertime
		"is_summertime" : (year_pct >= SUMMER_TIME_BEGIN_PCT and year_pct <= SUMMER_TIME_END_PCT) # If is summer time (based on 2022)
	}


func calculate_eot(_day : float, _prevent_leap_year_offset : bool = true) -> float:
	"""
	Calculates an approximation of the equation of time (eot) of a planet with custom day and year length.
	
	Be Aware: The metrics are approximations, are calculated using UTC-0 
				and do not reflect to summer/winter-time.
	
	Parameters:
		_day: number of day starting from the first day in the year.
		_prevent_leap_year_offset: prevents offsets in the eot that would need to be compensated with a leap year.
	
	returns the eot in minutes for the given day and specified planets orbit.
	"""
	
	return _calculate_eot_or_declination(_day, true, _prevent_leap_year_offset)


func calculate_declination(_day : float, _prevent_leap_year_offset : bool = true) -> float:
	"""
	Calculates an approximation of the declination of a planet with custom day and year length.
	
	Be Aware: The metrics are approximations, are calculated using UTC-0 
				and do not reflect to summer/winter-time.
	
	Parameters:
		_day: number of day starting from the first day in the year.
		_prevent_leap_year_offset: prevents offsets in the eot that would need to be compensated with a leap year.
	
	returns the declination in degrees for the given day and specified planets orbit.
	"""
	
	return _calculate_eot_or_declination(_day, false, _prevent_leap_year_offset)


func _calculate_eot_or_declination(_day : float, _return_eot : bool, _prevent_leap_year_offset : bool = true) -> float:
	"""
	Calculates an approximation of the equation of time (eot) or declination of a planet with custom day and year length.
	EOT is the difference of the the local time and mean local time at that date.
	It can be further used to calculate like sunrise or sunset
	
	The planet has an orbit with dimensions (orbit_dimension_a, orbit_dimension_b) 
	aswell as the given obliquity. 
	
	The default values produce values very similar to the earth.
	
	Parameters:
		_day: number of day starting from the first day in the year.
		_return_eot: if true returns the value for the eot, if false the declination on that day
		_prevent_leap_year_offset: prevents offsets in the eot that would need to be compensated with a leap year.
	
	returns the eot in minutes or the declination in degrees for the given day and specified planets orbit.
	"""
	# Based an approximate implementation from "The Latitude and Longitude of the Sun" by David Williams
	var d = _day
	
	if (_prevent_leap_year_offset):
		d = fmod(d, int(days_per_year)) # Prevents (leap year) offset
	
	var e = _calculate_eccentricity(orbit_dimension_a, orbit_dimension_b)
	
	var w = deg_to_rad(360.0 / days_per_year) # Average Angle Speed per day
	
	var year_length_factor = (DAYS_IN_JULIAN_CALENDER_YEAR / days_per_year)
	
	# 10 days from December solstice to New Year (Jan 1) scaled from the real earth year
	var solstice_offset = 10.0 * year_length_factor
	# 12 days from December solstice to perihelion scaled from the real earth year
	var solice_perhelion_offset = 12.0 * w * year_length_factor
	
	var a = w * (d + solstice_offset)
	var b = a + 2 * e * sin(a - solice_perhelion_offset)
	
	if _return_eot:
		var c = (a - atan(tan(b) / cos(deg_to_rad(obliquity)))) / PI
		return REAL_WORLD_HALF_DAY_MINUTES * (c - round(c)) # Eot in minutes
	else:
		var c = deg_to_rad(obliquity) * cos(b)
		return rad_to_deg(atan(c / sqrt(1 - pow(c, 2)))) # Declination in degrees


func _calculate_solar_noon_time(_eot_value : float, _declination : float) -> float:
	"""
	Calculates the solar noon time (true midday) from the eot and declination on that day.
	
	Parameters:
		_eot_value: The eot value of a day.
		_declination: The declination of a day.
	
	returns the time solar noon time (true midday) (in planet minutes)
	"""
	
	return REAL_WORLD_HALF_DAY_MINUTES - 4 * longitude - _eot_value


func _calculate_sunrise_or_set_time(_eot_value : float, _declination : float, _is_sunset : bool) -> float:
	"""
	Calculates the time of the sunset or sunrise from the eot and declination on that day.
	
	Parameters:
		_eot_value: The eot value of a day.
		_declination: The declination of a day.
		_is_sunset: if true returns the time of sunset, else the sunrise.
	
	returns the time for sunrise or sunset (in planet minutes)
	"""
	
	return _calculate_time_of_zenit_angle(SUNRISE_SUNSET_ZENIT, _eot_value, _declination, _is_sunset)


func _calculate_twilight_duration(_eot_value : float, _declination : float) -> float:
	"""
	Calculates the time of the dawn from the eot and declination on that day.
	
	Parameters:
		_eot_value: The eot value of a day.
		_declination: The declination of a day.
		_is_dusk: if true returns the time of sunset, else the sunrise.
	
	returns the duration of the twilight on that day (in planet minutes)
	"""
	
	var dawn_start_zenit = SUNRISE_SUNSET_ZENIT
	var dawn_end_zenit = SUNRISE_SUNSET_ZENIT - CIVIL_TWILIGHT_ZENIT_OFFSET

	var dawn_start_time = _calculate_time_of_zenit_angle(dawn_start_zenit, _eot_value, _declination, false)
	var dawn_end_time = _calculate_time_of_zenit_angle(dawn_end_zenit, _eot_value, _declination, false)
	
	return abs(dawn_end_time - dawn_start_time)


func _calculate_time_of_zenit_angle(_zenit : float, _eot_value : float, _declination : float, _is_evening : bool) -> float:
	"""
	Calculates the time of the sunset or sunrise from the eot and declination on that day.
	
	Parameters:
		_zenit : angle for the sun to reach.
		_eot_value: The eot value of a day.
		_declination: The declination of a day.
		_is_sunset: if true returns the time of sunset, else the sunrise.
	
	returns the time to reach sunrise's or sunset's angle (in planet minutes)
	"""
	
	var angle_dir = pow(-1, int(_is_evening))
	var zenit = deg_to_rad(_zenit)
	var lat = deg_to_rad(latitude)
	var decl = deg_to_rad(_declination)
	
	var hour_angle = angle_dir * rad_to_deg(acos(cos(zenit) / (cos(lat) * cos(decl)) - tan(lat) * tan(decl)))
	
	return REAL_WORLD_HALF_DAY_MINUTES - 4 * (longitude + hour_angle) - _eot_value


func _calculate_eccentricity(_a : float, _b : float) -> float:
	"""
	Calculates the eccentricity of an ellipse with dimensions a and b.
	
	Parameters:
		_a: first dimension of the ellispe (e.g. width)
		_b: second dimension of the ellispe (e.g. heigh)
	
	returns eccentricity of an ellipse
	"""
	
	var semi_major = max(_a, _b)
	var semi_minor = min(_a, _b)
	
	return (semi_major - semi_minor) / (semi_major + semi_minor)


func _calculate_half_day_minutes() -> float:
	"""
	Calculates the duration of minutes in hald a day:
	
	12hours a 60 minutes = 720 minutes for the real world, then scale acordignly
	
	returns the duration of minutes in half a day
	"""
	
	return REAL_WORLD_HALF_DAY_MINUTES * get_planet_time_scale()


func get_all_values_till(_end_day : int) -> Array:
	"""
	Returns a list of all dates till _end_day
	
	Parameters:
		_end_day: the last day (exclusive) for which values are calculated
		_plotable: if plotable the y values will be negated to be plotted in a normal graph
	
	returns list of eot values for each day
	"""
	
	return get_all_values_between(0, _end_day)


func get_all_values_between(_start_day : int, _end_day : int) -> Array:
	"""
	Returns a list of all dates between _start_day and _end_day
	
	Parameters:
		_start_day: the first day (inclusive) for which a value is calculated
		_end_day: the last day (exclusive) for which values are calculated
		_plotable: if plotable the y values will be negated to be plotted in a normal graph
	
	returns list of eot values for each day
	"""
	
	var values = []
	for i in range(_start_day, _end_day):
		values.append(get_full_info_about_day(i))
	return values


func get_eot_values_till(_end_day : int) -> Array:
	"""
	Returns a list the eot of all dates till _end_day
	
	Parameters:
		_end_day: the last day (exclusive) for which values are calculated
		_plotable: if plotable the y values will be negated to be plotted in a normal graph
	
	returns list of eot values for each day
	"""
	
	return get_eot_values_between(0, _end_day)


func get_eot_values_between(_start_day : int, _end_day : int) -> Array:
	"""
	Returns a list of all dates between _start_day and _end_day
	
	Parameters:
		_start_day: the first day (inclusive) for which a value is calculated
		_end_day: the last day (exclusive) for which values are calculated
		_plotable: if plotable the y values will be negated to be plotted in a normal graph
	
	returns list of eot values for each day
	"""
	
	var values = []
	for i in range(_start_day, _end_day):
		values.append(Vector2(i, calculate_eot(i)))
	return values


func planet_seconds_to_minutes(_seconds : float) -> float:
	"""
	Converts planet-seconds to planet-minutes (no real seconds/minutes!!)
	
	Parameters:
		_seconds: planet seconds to be converted in planet minutes
	
	returns the planet minutes
	"""
	
	return _seconds * get_planet_time_scale() / SECONDS_PER_MINUTE


func planet_minutes_to_seconds(_minutes : float) -> float:
	"""
	Converts planet-minutes to planet-seconds (no real seconds/minutes!!)
	
	Parameters:
		_minutes: planet minutes to be converted in planet seconds
	
	returns the planet seconds
	"""
	
	return _minutes / get_planet_time_scale() * SECONDS_PER_MINUTE


func planet_hours_to_minutes(_hour : float) -> float:
	"""
	Converts planet-hour to planet-minutes (no real hours/minutes!!)
	
	Parameters:
		_hour: planet hours to be converted in planet hours
	
	returns the planet minutes
	"""
	
	return _hour * get_planet_time_scale() * MINUTES_PER_HOUR


func planet_minutes_to_hours(_minutes : float) -> float:
	"""
	Converts planet-hour to planet-minutes (no real hours/minutes!!)
	
	Parameters:
		_minutes: planet minutes to be converted in planet hours
	
	returns the planet hours
	"""
	
	return _minutes * get_planet_time_scale() / MINUTES_PER_HOUR


func get_planet_time_scale() -> float:
	"""
	Calculates and returns the scale of real-world time to planet time
	
	returns the planet's time scale
	"""
	return day_duration / DEFAULT_SECONDS_PER_DAY
