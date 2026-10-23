// Tree leaves, phones and touch devices (no MSAA there): plain alpha scissor, same look otherwise.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, specular_schlick_ggx;
#include "res://game/shaders/tree_leaf.gdshaderinc"
