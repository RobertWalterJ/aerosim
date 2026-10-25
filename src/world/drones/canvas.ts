// Thin adapter over src/world/ProceduralTextures.ts canvas helpers for the
// drone textures (no duplicated helpers: canvases, normal maps, lattice noise
// and texture wrapping all come from ProceduralTextures).
import * as THREE from 'three';
import { mkCanvas, normalFromHeight, tex, lattice } from '../ProceduralTextures';
import { mulberry32 } from '../../util/noise';

export type Ctx2D = CanvasRenderingContext2D;

export function makeCanvas(w: number, h: number): { canvas: HTMLCanvasElement; ctx: Ctx2D } {
  const canvas = mkCanvas(w, h);
  const ctx = canvas.getContext('2d');
  if (!ctx) throw new Error('drone textures: 2D context unavailable');
  return { canvas, ctx };
}

export function toTexture(canvas: HTMLCanvasElement, opts: { srgb: boolean; repeat?: boolean; name?: string }): THREE.CanvasTexture {
  const t = tex(canvas, opts.srgb, opts.repeat ?? false);
  if (!opts.repeat) t.wrapS = t.wrapT = THREE.ClampToEdgeWrapping;
  if (opts.name) t.name = opts.name;
  return t;
}

export const rng = mulberry32;
export const makeValueNoise = lattice;
/** Height field (0..1) to a normal-map canvas (OpenGL convention, wraps). */
export const normalCanvas = normalFromHeight;

export function putPixels(ctx: Ctx2D, data: Uint8ClampedArray, w: number, h: number): void {
  const img = ctx.createImageData(w, h);
  img.data.set(data);
  ctx.putImageData(img, 0, 0);
}

/** Read back a canvas as a height field from its red channel. */
export function readHeight(ctx: Ctx2D, w: number, h: number): Float32Array {
  const d = ctx.getImageData(0, 0, w, h).data;
  const out = new Float32Array(w * h);
  for (let i = 0; i < out.length; i++) out[i] = d[i * 4]! / 255;
  return out;
}

export const css = (c: THREE.Color): string => '#' + c.getHexString(THREE.SRGBColorSpace);
