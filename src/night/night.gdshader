shader_type canvas_item;
// Night over the street: a tinted shade everywhere except the headlights, the glow around
// the player's car, and street lamps on both sidewalks. Coordinates are the view's own.

uniform float darkness : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.03, 0.05, 0.16, 1.0);
uniform vec2 car = vec2(216.0, 604.0);
uniform float beam_length = 300.0;
uniform vec2 lamp_x = vec2(110.0, 322.0);
uniform float lamp_spacing = 260.0;
uniform float lamp_offset = 0.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

float beam(vec2 point) {
	vec2 offset = point - car;
	float ahead = -offset.y - 30.0;
	if (ahead < 0.0) {
		return 0.0;
	}
	float half_width = 16.0 + ahead * 0.4;
	float side = 1.0 - smoothstep(half_width * 0.55, half_width, abs(offset.x));
	return side * (1.0 - smoothstep(beam_length * 0.45, beam_length, ahead));
}

// Distance from the nearest lamp on one sidewalk; lamps scroll with the road.
float lamp_distance(vec2 point, float x, float phase) {
	float y = mod(point.y - lamp_offset + phase, lamp_spacing) - lamp_spacing * 0.5;
	return length(vec2(point.x - x, y));
}

void fragment() {
	float glow = 0.75 * (1.0 - smoothstep(24.0, 70.0, length(local - car)));
	float nearest = min(
		lamp_distance(local, lamp_x.x, 0.0), lamp_distance(local, lamp_x.y, lamp_spacing * 0.5)
	);
	float lamps = 0.8 * (1.0 - smoothstep(8.0, 72.0, nearest));
	float light = clamp(max(max(beam(local), glow), lamps), 0.0, 1.0);
	vec3 warm = vec3(1.0, 0.86, 0.55);
	vec4 shade = vec4(mix(tint.rgb, warm, light * 0.35), darkness * (1.0 - light * 0.85));
	float bulb = 1.0 - smoothstep(2.5, 4.5, nearest);
	COLOR = mix(shade, vec4(1.0, 0.93, 0.7, min(1.0, darkness * 1.5)), bulb);
}
