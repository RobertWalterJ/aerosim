// Shader sources for the 7-stage DJI / GoPro optical-sensor pipeline.
export const VERT = /* glsl */`varying vec2 vUv; void main(){ vUv = uv; gl_Position = vec4(position.xy, 0.0, 1.0); }`;

// Stage 2a: centre-weighted metering (70% of weight in the centre third), 32x32 log-luminance
export const METER = /* glsl */`
precision highp float; varying vec2 vUv; uniform sampler2D uScene; uniform float uS; uniform vec2 uTexel;
float lum(vec3 c){ return dot(c, vec3(0.2126,0.7152,0.0722)); }
void main(){
  vec2 cell = vec2(1.0/32.0);
  float sumL = 0.0;
  for(int j=0;j<6;j++) for(int i=0;i<6;i++){
    vec2 o = (vec2(float(i),float(j)) + 0.5)/6.0;
    vec2 uvF = vUv - 0.5*cell + o*cell;                    // frame-space uv
    vec2 uvS = 0.5 + (uvF - 0.5)/uS;                       // scene-space uv (overscan)
    float L = lum(texture2D(uScene, uvS).rgb);
    sumL += log2(clamp(L, 1e-4, 60.0));
  }
  vec2 c = abs(vUv - 0.5);
  float inC = (1.0 - smoothstep(0.155, 0.185, c.x)) * (1.0 - smoothstep(0.155, 0.185, c.y));
  float w = mix(0.3375, 6.3, inC);
  gl_FragColor = vec4(w * sumL/36.0, w, 0.0, 1.0);
}`;
export const REDUCE = /* glsl */`
precision highp float; varying vec2 vUv; uniform sampler2D uSrc;
void main(){ float a=0.0,b=0.0; for(int j=0;j<32;j++) for(int i=0;i<32;i++){ vec4 s = texture2D(uSrc, (vec2(float(i),float(j))+0.5)/32.0); a+=s.r; b+=s.g; } gl_FragColor = vec4(a/max(b,1e-5), 0.0, 0.0, 1.0); }`;
// Auto-exposure with metering lag (asymmetric: brightening scenes adapt a touch faster than darkening ones)
export const ADAPT = /* glsl */`
precision highp float; varying vec2 vUv; uniform sampler2D uMeter, uPrev; uniform float uDt, uTau, uEvComp, uMinE, uMaxE;
void main(){
  float meanLog = texture2D(uMeter, vec2(0.5)).r;          // log2 of weighted mean luminance
  float target = log2(0.13) - meanLog + uEvComp;           // exposure (log2) mapping the mean to ~20% grey
  target = clamp(target, log2(uMinE), log2(uMaxE));
  float prev = texture2D(uPrev, vec2(0.5)).r;
  float tau = target < prev ? uTau * 0.8 : uTau;
  float k = 1.0 - exp(-uDt/tau);
  gl_FragColor = vec4(prev + (target-prev)*k, target, 0.0, 1.0);
}`;

// Bloom (physically-motivated veiling glow from bright sources)
export const BLOOM_PRE = /* glsl */`
precision highp float; varying vec2 vUv; uniform sampler2D uScene, uExp; uniform vec2 uTexel; uniform float uKnee;
void main(){
  float e = exp2(texture2D(uExp, vec2(0.5)).r);
  vec3 c = vec3(0.0);
  c += texture2D(uScene, vUv + uTexel*vec2(-1.0,-1.0)).rgb; c += texture2D(uScene, vUv + uTexel*vec2( 1.0,-1.0)).rgb;
  c += texture2D(uScene, vUv + uTexel*vec2(-1.0, 1.0)).rgb; c += texture2D(uScene, vUv + uTexel*vec2( 1.0, 1.0)).rgb;
  c *= 0.25 * e;
  float l = max(c.r, max(c.g, c.b));
  float soft = clamp(l - uKnee + 0.5, 0.0, 1.0); soft = soft*soft*0.5;
  float w = max(soft, l - uKnee) / max(l, 1e-4);
  gl_FragColor = vec4(min(c*w, vec3(300.0)), 1.0);
}`;
export const BLOOM_DOWN = /* glsl */`
precision highp float; varying vec2 vUv; uniform sampler2D uSrc; uniform vec2 uTexel;
void main(){
  vec3 a = texture2D(uSrc, vUv + uTexel*vec2(-2.,-2.)).rgb, b = texture2D(uSrc, vUv + uTexel*vec2(0.,-2.)).rgb, c = texture2D(uSrc, vUv + uTexel*vec2(2.,-2.)).rgb;
  vec3 d = texture2D(uSrc, vUv + uTexel*vec2(-2.,0.)).rgb, e = texture2D(uSrc, vUv).rgb, f = texture2D(uSrc, vUv + uTexel*vec2(2.,0.)).rgb;
  vec3 g = texture2D(uSrc, vUv + uTexel*vec2(-2.,2.)).rgb, h = texture2D(uSrc, vUv + uTexel*vec2(0.,2.)).rgb, i = texture2D(uSrc, vUv + uTexel*vec2(2.,2.)).rgb;
  vec3 j = texture2D(uSrc, vUv + uTexel*vec2(-1.,-1.)).rgb, k = texture2D(uSrc, vUv + uTexel*vec2(1.,-1.)).rgb, l = texture2D(uSrc, vUv + uTexel*vec2(-1.,1.)).rgb, m = texture2D(uSrc, vUv + uTexel*vec2(1.,1.)).rgb;
  gl_FragColor = vec4(e*0.125 + (a+c+g+i)*0.03125 + (b+d+f+h)*0.0625 + (j+k+l+m)*0.125, 1.0);
}`;
export const BLOOM_UP = /* glsl */`
precision highp float; varying vec2 vUv; uniform sampler2D uLow, uHigh; uniform vec2 uTexel; uniform float uWeight;
void main(){
  vec3 s = texture2D(uLow, vUv + uTexel*vec2(-1.,-1.)).rgb + 2.*texture2D(uLow, vUv + uTexel*vec2(0.,-1.)).rgb + texture2D(uLow, vUv + uTexel*vec2(1.,-1.)).rgb
         + 2.*texture2D(uLow, vUv + uTexel*vec2(-1.,0.)).rgb + 4.*texture2D(uLow, vUv).rgb + 2.*texture2D(uLow, vUv + uTexel*vec2(1.,0.)).rgb
         + texture2D(uLow, vUv + uTexel*vec2(-1.,1.)).rgb + 2.*texture2D(uLow, vUv + uTexel*vec2(0.,1.)).rgb + texture2D(uLow, vUv + uTexel*vec2(1.,1.)).rgb;
  gl_FragColor = vec4(texture2D(uHigh, vUv).rgb + s/16.0 * uWeight, 1.0);
}`;

// Stages 1, 3, 4 + exposure + sensor noise: rolling shutter / jello, flare+ghost (in lens plane), Brown-Conrady + lateral CA.
export const SENSOR = /* glsl */`
precision highp float; varying vec2 vUv;
uniform sampler2D uScene, uDepth, uBloom, uExp;
uniform float uS, uAspect, uTime, uReadout, uVibAmp, uVibFreq, uBloomK;
uniform vec2 uTan, uK, uSunS, uWRS;                 // tan half-fov (x,y); k1,k2; sun uv in scene space; (yaw, pitch) rates rad/s
uniform sampler2D uSunTex; uniform float uInView; float gSunVis;
uniform float uWRoll, uGlare, uIso, uCA, uGhostK, uFrame, uFlareI, uVig;
float hash(vec2 p){ p = fract(p*vec3(0.1031,0.1030,0.0973).xy); p += dot(p, p.yx+33.33); return fract((p.x+p.y)*p.x); }
float gSunVisDummy;
vec3 ghostCol = vec3(0.0513, 1.0, 0.402);            // #40FFAA in linear

vec3 flare(vec2 uvS, float e){
  // work in frame units (output frame height = 1): d = (uvS - sunS) * S * (aspect,1)
  vec2 d = (uvS - uSunS) * uS * vec2(uAspect, 1.0);
  float ang = radians(10.0); vec2 n = vec2(sin(ang), cos(ang)); vec2 pp = vec2(n.y, -n.x);
  float al = dot(d, n), pe = dot(d, pp);
  float streak = exp(-pe*pe/(2.0*0.0025*0.0025)) * exp(-al*al/(2.0*0.65*0.65));
  float halo = exp(-dot(d,d)/(2.0*0.02*0.02)) * 0.8 + exp(-dot(d,d)/(2.0*0.12*0.12)) * 0.08;
  vec3 c = (vec3(1.0,0.93,0.82)*streak*1.1 + vec3(1.0,0.82,0.6)*halo) * gSunVis * uFlareI;
  // internal ghost orb: inverted through the optical centre
  vec2 sf = (uSunS - 0.5) * uS;                         // sun in centred frame units (frame width = 1)
  vec2 gp = -uGhostK * sf;
  vec2 gd = ((uvS - 0.5) * uS - gp) * vec2(uAspect, 1.0);
  float r = length(gd);
  float ring = exp(-pow((r-0.075)/0.0065, 2.0)) + 0.55*exp(-pow((r-0.052)/0.0045, 2.0)) + 0.12*smoothstep(0.075, 0.0, r);
  float fadeG = smoothstep(1.4, 0.15, length(sf*vec2(1.0,1.0))) ;
  c += ghostCol * ring * 0.55 * gSunVis * uFlareI * (0.35 + fadeG);
  // secondary smaller ghost
  vec2 gp2 = -0.28 * sf; float r2 = length(((uvS - 0.5) * uS - gp2) * vec2(uAspect, 1.0));
  c += vec3(0.9,0.5,0.35) * exp(-pow((r2-0.03)/0.005, 2.0)) * 0.25 * gSunVis * uFlareI * fadeG;
  return c;
}

void main(){
  gSunVis = texture2D(uSunTex, vec2(0.5)).r * uInView;
  vec2 uv = vUv;
  // --- Stage 1: rolling shutter (12 ms readout) + motor jello
  float tl = (uv.y - 0.5) * uReadout;                    // scanline time offset (top scanned first)
  vec2 shift = vec2(uWRS.x * tl / (2.0*uTan.x), -uWRS.y * tl / (2.0*uTan.y));
  vec2 pc = uv - 0.5;
  shift += vec2(-pc.y, pc.x) * uWRoll * tl * 0.9 * vec2(1.0/uAspect, 1.0);
  float jello = sin(uv.y * 190.0 + uTime * uVibFreq) * 0.6 + sin(uv.y * 71.0 - uTime * uVibFreq * 0.37) * 0.4;
  shift.x += jello * uVibAmp;
  shift.y += jello * uVibAmp * 0.25 * sin(uv.x*40.0 + uTime*uVibFreq*0.5);
  vec2 uvd = uv - vec2(shift.x, -shift.y);
  // --- Stage 4: Brown-Conrady radial distortion, r normalised to half-diagonal; lateral CA scales channels radially
  vec2 a = (uvd - 0.5) * 2.0;                            // -1..1
  vec2 tanXY = a * uTan;
  float r = length(tanXY) / length(uTan);
  float f = 1.0 + uK.x*r*r + uK.y*r*r*r*r;
  vec2 sR = 0.5 + 0.5*a*f*(1.0+uCA)/uS, sG = 0.5 + 0.5*a*f/uS, sB = 0.5 + 0.5*a*f*(1.0-uCA)/uS;
  float e = exp2(texture2D(uExp, vec2(0.5)).r);
  vec3 col = vec3(texture2D(uScene, sR).r, texture2D(uScene, sG).g, texture2D(uScene, sB).b) * e;
  vec3 bl = vec3(texture2D(uBloom, sR).r, texture2D(uBloom, sG).g, texture2D(uBloom, sB).b);
  col += bl * uBloomK;
  // --- Stage 3: anamorphic diffraction streak + cyan sensor ghost + veiling glare (lens plane => then distorted with the image)
  col += flare(sG, e);
  col += vec3(0.020,0.022,0.026) * uGlare * (0.4 + 0.6*gSunVis);
  // optical vignette (cos^4-like)
  float vr = length(a * vec2(1.0, 1.0)) * 0.7071; col *= 1.0 - uVig * vr*vr;
  // --- Stage 6a: sensor ISO noise (shot + read), luminance and chroma, scaled by analogue gain
  float lum = dot(col, vec3(0.2126,0.7152,0.0722));
  vec2 np = gl_FragCoord.xy + vec2(uFrame*17.0, uFrame*31.0);
  float n1 = hash(np) - 0.5, n2 = hash(np + 7.7) - 0.5, n3 = hash(np + 13.1) - 0.5;
  float amp = (0.004 + 0.045*sqrt(max(lum,0.0))) * uIso * 0.45;
  col += vec3(n1) * amp + vec3(n1*0.3+n2, n2*0.3-n3, n3*0.3+n1) * amp * 0.45;
  gl_FragColor = vec4(max(col, 0.0), 1.0);
}`;

// Stages 5 & 6: 10-stop DR S-curve (Rec.709 / D-Cinelike-ish) + ISP unsharp-mask halos
export const ISP = /* glsl */`
precision highp float; varying vec2 vUv; uniform sampler2D uSrc; uniform vec2 uTexel; uniform float uGlare, uSharp, uRadius, uSat, uFrame;
vec3 curve(vec3 x){
  vec3 st = log2(max(x, 1e-5)/0.18);                      // stops relative to mid-grey
  vec3 t = clamp((st + 6.2)/10.0, 0.0, 1.0);              // 10-stop window: shadow crush below, hard clip above
  vec3 s = t*t*(3.0-2.0*t);
  vec3 v = mix(t, s, 0.62);
  v = pow(v, vec3(1.07));                                 // slight toe
  v = mix(v, vec3(0.5), 0.22*uGlare) + 0.03*uGlare;       // veiling glare lifts blacks, washes mids
  return v;                                               // already display-referred (gamma-encoded)
}
vec3 sat(vec3 c){ float l = dot(c, vec3(0.299,0.587,0.114)); return mix(vec3(l), c, uSat); }
void main(){
  vec3 c0 = sat(curve(texture2D(uSrc, vUv).rgb));
  vec2 o = uTexel * uRadius;
  vec3 blur = sat(curve(texture2D(uSrc, vUv + vec2(o.x,0.)).rgb)) + sat(curve(texture2D(uSrc, vUv - vec2(o.x,0.)).rgb))
            + sat(curve(texture2D(uSrc, vUv + vec2(0.,o.y)).rgb)) + sat(curve(texture2D(uSrc, vUv - vec2(0.,o.y)).rgb));
  blur += 0.7071*(sat(curve(texture2D(uSrc, vUv + o).rgb)) + sat(curve(texture2D(uSrc, vUv - o).rgb)) + sat(curve(texture2D(uSrc, vUv + vec2(o.x,-o.y)).rgb)) + sat(curve(texture2D(uSrc, vUv + vec2(-o.x,o.y)).rgb)));
  blur /= 4.0 + 4.0*0.7071;
  vec3 hp = c0 - blur;                                    // 3x3 Laplacian-style high-pass
  vec3 res = c0 + uSharp * hp;                            // amount 1.4 -> bright/dark edge halos
  res = clamp(res, -0.02, 1.02);
  gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}`;

// Stage 7: H.264-style macroblocking, chroma subsampling, motion hold on RF link loss
export const CODEC = /* glsl */`
precision highp float; varying vec2 vUv; uniform sampler2D uSrc, uPrev; uniform vec2 uRes; uniform float uBad, uFrame, uTime;
float hash(vec2 p){ p = fract(p*vec2(0.1031,0.1030)); p += dot(p, p.yx+33.33); return fract((p.x+p.y)*p.x); }
vec3 rgb2yuv(vec3 c){ return vec3(dot(c,vec3(0.299,0.587,0.114)), dot(c,vec3(-0.147,-0.289,0.436)), dot(c,vec3(0.615,-0.515,-0.100))); }
vec3 yuv2rgb(vec3 y){ return vec3(y.x + 1.140*y.z, y.x - 0.395*y.y - 0.581*y.z, y.x + 2.032*y.y); }
void main(){
  vec3 c = texture2D(uSrc, vUv).rgb;
  if (uBad > 0.001) {
    vec2 px = vUv*uRes;
    float bs = uBad > 0.55 ? 16.0 : 8.0;
    vec2 blk = floor(px/bs); vec2 ctr = (blk + 0.5)*bs/uRes;
    // 4-tap block average (DCT DC term)
    vec3 avg = (texture2D(uSrc, ctr + vec2(-0.25,-0.25)*bs/uRes).rgb + texture2D(uSrc, ctr + vec2(0.25,-0.25)*bs/uRes).rgb + texture2D(uSrc, ctr + vec2(-0.25,0.25)*bs/uRes).rgb + texture2D(uSrc, ctr + vec2(0.25,0.25)*bs/uRes).rgb) * 0.25;
    float q = mix(1.0, 0.82, uBad);
    vec3 yuv = rgb2yuv(c), ya = rgb2yuv(avg);
    // keep a fraction of AC detail inside the block, quantise chroma per block
    float keep = 1.0 - smoothstep(0.1, 0.9, uBad);
    vec3 outYuv = vec3(mix(ya.x, yuv.x, keep*0.7), ya.yz + (yuv.yz - ya.yz)*keep*0.2);
    outYuv.x = floor(outYuv.x*(14.0+22.0*(1.0-uBad)))/(14.0+22.0*(1.0-uBad));
    outYuv.yz = floor(outYuv.yz*(6.0+10.0*(1.0-uBad)))/(6.0+10.0*(1.0-uBad));
    vec3 blocky = yuv2rgb(outYuv);
    float rb = hash(blk + floor(uFrame*0.5));
    blocky *= 0.96 + 0.08*hash(blk*1.7 + uFrame);            // per-block luma flicker
    c = mix(c, blocky, smoothstep(0.0, 0.25, uBad));
    // stale macroblocks: previous frame persists for some blocks
    if (rb < uBad*0.55) c = mix(c, texture2D(uPrev, ctr).rgb, 0.85);
  }
  gl_FragColor = vec4(c, 1.0);
}`;

export const BLIT = /* glsl */`
precision highp float; varying vec2 vUv; uniform sampler2D uSrc; uniform float uAspectScreen, uAspectSrc;
void main(){
  vec2 uv = vUv; vec2 s = vec2(1.0);
  if (uAspectScreen > uAspectSrc) { s.x = uAspectScreen/uAspectSrc; } else { s.y = uAspectSrc/uAspectScreen; }
  uv = (uv-0.5)*s + 0.5;
  if (uv.x<0.0||uv.x>1.0||uv.y<0.0||uv.y>1.0) { gl_FragColor = vec4(0.0,0.0,0.0,1.0); return; }
  vec3 c = texture2D(uSrc, uv).rgb;
  gl_FragColor = vec4(pow(c, vec3(1.0)), 1.0);   // ISP output is already display-referred
}`;

export const HIST = /* glsl */`
precision highp float; varying vec2 vUv; uniform sampler2D uSrc; uniform vec2 uTexel;
void main(){ vec3 s = vec3(0.0); for(int j=0;j<4;j++) for(int i=0;i<4;i++) s += texture2D(uSrc, vUv + (vec2(float(i),float(j))-1.5)*uTexel*3.0).rgb; gl_FragColor = vec4(s/16.0, 1.0); }`;

export const SUNVIS = /* glsl */`
precision highp float; varying vec2 vUv; uniform sampler2D uDepth, uPrev; uniform vec2 uSunS;
void main(){
  float v = 0.0;
  for(int j=-2;j<=2;j++) for(int i=-2;i<=2;i++){
    vec2 p = uSunS + vec2(float(i),float(j))*0.0045;
    float inside = step(0.0,p.x)*step(p.x,1.0)*step(0.0,p.y)*step(p.y,1.0);
    float d = texture2D(uDepth, clamp(p,0.0,1.0)).r; v += inside * step(0.99999, d);
  }
  float prev = texture2D(uPrev, vec2(0.5)).r;
  gl_FragColor = vec4(mix(prev, v/25.0, 0.45), 0.0, 0.0, 1.0);
}`;
