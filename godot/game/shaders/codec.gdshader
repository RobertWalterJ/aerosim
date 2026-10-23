// Stage 7: H.264-style macroblocking, chroma subsampling and motion hold when the video link is poor.
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D uSrc : filter_linear, repeat_disable;
uniform sampler2D uPrev : filter_linear, repeat_disable;
uniform vec2 uRes = vec2(1280.0, 720.0);
uniform float uBad = 0.0;
uniform float uFrame = 0.0;
uniform float uLink = 1.0;   // 0 disables the always-on H.264 look (link effects off)
vec4 T(sampler2D s, vec2 v) { return texture(s, vec2(v.x, 1.0 - v.y)); }
float hash(vec2 p) { p = fract(p * vec2(0.1031, 0.1030)); p += dot(p, p.yx + 33.33); return fract((p.x + p.y) * p.x); }
vec3 rgb2yuv(vec3 c) { return vec3(dot(c, vec3(0.299, 0.587, 0.114)), dot(c, vec3(-0.147, -0.289, 0.436)), dot(c, vec3(0.615, -0.515, -0.100))); }
vec3 yuv2rgb(vec3 y) { return vec3(y.x + 1.140 * y.z, y.x - 0.395 * y.y - 0.581 * y.z, y.x + 2.032 * y.y); }
void fragment() {
	vec2 vUv = vec2(UV.x, 1.0 - UV.y);
	vec3 c = T(uSrc, vUv).rgb;
	// always-on (subtle) H.264 look: soft chroma subsampling and slight shadow banding, rising with link badness
	if (uLink > 0.5) {
		vec2 e = vec2(1.0, 1.0) / uRes;
		vec3 yuv = rgb2yuv(c);
		vec3 ym = rgb2yuv((T(uSrc, vUv + vec2(e.x, 0.0)).rgb + T(uSrc, vUv - vec2(e.x, 0.0)).rgb + T(uSrc, vUv + vec2(0.0, e.y)).rgb + T(uSrc, vUv + vec2(0.0, -e.y)).rgb) * 0.25);
		float sub = 0.55 + 0.45 * uBad;   // chroma keeps less of its own detail as the link worsens (4:2:0)
		vec3 y = vec3(yuv.x, mix(yuv.yz, ym.yz, sub));
		y.x = floor(y.x * 256.0) / 256.0;   // a faint 8-bit band in the luma
		c = yuv2rgb(y);
	}
	if (uBad > 0.001) {
		vec2 px = vUv * uRes;
		float bs = uBad > 0.55 ? 16.0 : 8.0;
		vec2 blk = floor(px / bs); vec2 ctr = (blk + 0.5) * bs / uRes;
		vec3 avg = (T(uSrc, ctr + vec2(-0.25, -0.25) * bs / uRes).rgb + T(uSrc, ctr + vec2(0.25, -0.25) * bs / uRes).rgb + T(uSrc, ctr + vec2(-0.25, 0.25) * bs / uRes).rgb + T(uSrc, ctr + vec2(0.25, 0.25) * bs / uRes).rgb) * 0.25;
		vec3 yuv = rgb2yuv(c); vec3 ya = rgb2yuv(avg);
		float keep = 1.0 - smoothstep(0.1, 0.9, uBad);
		vec3 outYuv = vec3(mix(ya.x, yuv.x, keep * 0.7), ya.yz + (yuv.yz - ya.yz) * keep * 0.2);
		outYuv.x = floor(outYuv.x * (14.0 + 22.0 * (1.0 - uBad))) / (14.0 + 22.0 * (1.0 - uBad));
		outYuv.yz = floor(outYuv.yz * (6.0 + 10.0 * (1.0 - uBad))) / (6.0 + 10.0 * (1.0 - uBad));
		vec3 blocky = yuv2rgb(outYuv);
		float rb = hash(blk + floor(uFrame * 0.5));
		blocky *= 0.96 + 0.08 * hash(blk * 1.7 + uFrame);
		c = mix(c, blocky, smoothstep(0.0, 0.25, uBad));
		if (rb < uBad * 0.55) c = mix(c, T(uPrev, ctr).rgb, 0.85);
	}
	COLOR = vec4(c, 1.0);
}
