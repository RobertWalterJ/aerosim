// Tree leaves, desktop: alpha to coverage softens the cut-out leaf edges (needs the scene's MSAA, which desktop has).
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, specular_schlick_ggx, alpha_to_coverage;
#define TREE_A2C
#include "res://game/shaders/tree_leaf.gdshaderinc"
