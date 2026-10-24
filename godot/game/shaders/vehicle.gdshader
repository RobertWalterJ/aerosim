// Vehicles and road furniture (game/new_models4.gd): car paint with a clear coat, rubber, chrome, glass, trim, lamp lenses,
// painted sheet metal and concrete. Everything is procedural (no photographs): a fine metallic flake in the paint, hairline
// scratches and rust freckles where the vertex alpha says the finish is worn, road dirt thrown up the lower panels, rain that
// darkens and glosses, snow on what faces up, and the cloud and drone shadows like the rest of the world.
//   kind 0 car paint:   rgb is the paint; alpha is the condition (1 clean, lower = dirty, faded and rusty)
//   kind 1 rubber:      tyre black; alpha 1 new, lower = dusty grey
//   kind 2 metal:       rgb is the metal (chrome, aluminium, zinc, steel); alpha 1 polished, lower = dull
//   kind 3 glass:       dark mirror glass; rgb tints it
//   kind 4 trim:        black and grey plastic, seats, cloth, rubber seals; alpha lowers the sheen
//   kind 5 lamp lens:   glossy coloured plastic; glows with the uniform `glow` (headlamps, tail lamps at night)
//   kind 6 sheet:       painted sheet steel and signs (flat colour, satin); alpha is the condition
//   kind 7 concrete:    cast concrete with pits and stains; alpha is the condition
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// The body is shared with vehicle_pbr.gdshader (the Blender vehicles); see vehicle_body.gdshaderinc.
#include "res://game/shaders/vehicle_body.gdshaderinc"
