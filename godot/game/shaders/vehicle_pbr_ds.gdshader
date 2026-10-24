// vehicle_pbr.gdshader drawn from both sides: the cabin (door cards, headliner, seats) of the Blender vehicles, which is
// seen from inside through the glass and from outside through an open door.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
#define VEHICLE_MAPS
#include "res://game/shaders/vehicle_body.gdshaderinc"
