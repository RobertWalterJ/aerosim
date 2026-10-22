// Auto-exposure with metering lag. Brightening scenes adapt a touch faster than darkening ones.
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D uMeter : filter_nearest, repeat_disable;
uniform sampler2D uPrev : filter_nearest, repeat_disable;
uniform float uDt = 0.016;
uniform float uTau = 0.35;
uniform float uEvComp = 0.0;
uniform float uBias = 0.0;        // extra exposure change, in stops: the camera stops down when the sun is in the picture
uniform float uMinE = 0.03;
uniform float uMaxE = 8.0;
void fragment() {
	float meanLog = texture(uMeter, vec2(0.5)).r;
	float target = log2(0.13) - meanLog + uEvComp + uBias;
	target = clamp(target, log2(uMinE), log2(uMaxE));
	float prev = texture(uPrev, vec2(0.5)).r;
	// into brightness the camera is slow to stop down, so the picture washes out for a moment; back into shade it opens up a little quicker
	float tau = target < prev ? uTau * 2.6 : uTau * 1.6;
	float k = 1.0 - exp(-uDt / tau);
	COLOR = vec4(prev + (target - prev) * k, target, 0.0, 1.0);
}
