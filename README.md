# DynamicDayNightCycles

A Godot 4.x Plugin for Dynamic Day Night Cycles.

## Description

The plugin allows correctly simulating the daylight, nighttime, dawn and dusk of you game's planet.
It calculates the alteration of day-lengths throughout a year so days get shorter in the winter and longer in the summer.

The plugin allows full customization of the days per year's, day duration and the location on the planet to give the most immersive results.

## Features

- A `CustomEOT`-Node node that can be customized for calculating a planet's day-night-cycle.
- The `daytime_shader.tres`-Shader for tinting the screen throughout the day with dawn and dusk.
- The `DayColorVisualizer`-Scene for testing the shader's look on an example image.
- The `EOTPlot`-Scene for displaying the evolution of dawn, dusk and more throughout the year.

## How To

- Add a `CustomEOT`-Node to your Scene.
- Configure the *Days per Year*, *Day Duration* (in seconds), *Year Start Day*, *Latitude* and *Longitude* to fit your game's worlds setting.
- Add a `ColorRect`-Node as an Overlay over your game and add the `daytime_shader.tres` to it.
- Alter the `day_time_colors`-Texture with either an a GradientTexture or an ImageTexture resembling a gradient if you want. The gradient should have with the (morning-)night color at 0.0, then day-color at 0.5 and and end on the (evening-)night at 1.0. The colors between those points will be scrolled during sunrise/dawn and sunset/dusk.
- Change the `shader_opacity` for more/less opacity.
- If you want longer twilights and increase `twilight_duration_factor`. Be careful this might break the shader when using high values!
- Update the value of `current_time` during the course of your game's day to match the "progress" of your day in percent.
- Each new day calculate the value for the day using the `CustomEOT`-Node's `get_full_info_about_day(_day)`-function. Use the corresponding entries from the dictionary `sunrise_time`, `sunset_time` and `twilight_duration` in the shader.

*Code example coming soon.*

## Installation

- Download the latest release from GitHub for your version of Godot.
- Create an `addons/`-folder in the root of your project and place the `dynamic_day_night_cycles`-folder inside.

## 📃 Credits

Made by Luca "eisclimber" Dreiling.

Calculations are based on "The Latitude and Longitude of the Sun" by David Williams.
