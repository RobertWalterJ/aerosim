// Auto-exposure with metering lag. Brightening scenes adapt a touch faster than darkening ones.
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D uMeter : filter_nearest, repeat_disable;
uniform sampler2D uPrev : filter_nearest, repeat_disable;
uniform float uDt = 0.016;
uniform float uTau = 0.35;
uniform float uEvComp = 0.0;
uniform float uMinE = 0.03;
uniform float uMaxE = 40.0;
void fragment() {
	float meanLog = texture(uMeter, vec2(0.5)).r;
	float target = log2(0.13) - meanLog + uEvComp;
	target = clamp(target, log2(uMinE), log2(uMaxE));
	float prev = texture(uPrev, vec2(0.5)).r;
	float tau = target < prev ? uTau * 0.8 : uTau;
	float k = 1.0 - exp(-uDt / tau);
	COLOR = vec4(prev + (target - prev) * k, target, 0.0, 1.0);
}
