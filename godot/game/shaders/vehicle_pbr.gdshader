// The Blender vehicles (Blender 3, lane/vehicles: game/vehicle_assets.gd): the same finishes as vehicle.gdshader (clear-coat paint,
// rubber, metal, trim, lenses, sheet), coloured by the uniform `tint` (the paint per instance) with the baked ambient
// occlusion in the vertex colour, the condition in the vertex alpha, and optional photographed detail maps.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#define VEHICLE_MAPS
#include "res://game/shaders/vehicle_body.gdshaderinc"
