# New models (built by Claude, not DSH): the contract

DSH finds modelling hard, so all new 3D models for `SPEC-NEW-EXPERIENCES.md` are made first, by Claude, as code in
`game/new_models.gd` (class `NewModels`). DSH only wires them up. DSH must not model anything: if a model is wrong, write the
request in `LOGIC-NOTES.md` under "Requests for Claude" and carry on with the model that exists.

Each function returns an `ArrayMesh` (materials set; vertex colours used for variation) or a `Dictionary` of named meshes.
Scale is real metres; forward is -Z; up is +Y; the origin is the centre of mass (planes, birds) or the ground contact point (deer, balloon basket).

| Function | Returns | Notes |
|---|---|---|
| `NewModels.plane()` | `{"body": ArrayMesh, "prop": ArrayMesh, "prop_pivot": Vector3, "camera": Vector3, "span": float, "length": float, "outline_plan": PackedVector2Array, "outline_side": PackedVector2Array}` | FPV plane, 1.1 m span, orange wing and white fuselage. `prop` spins about its own +Z axis at `prop_pivot` (nose). `camera` is the nose camera position. |
| `NewModels.bird(kind, flap)` | `ArrayMesh` | kind in `"goose"`, `"gull"`, `"starling"`, `"hawk"`; `flap` 0..1 is the wing cycle (0 up, 0.5 down); a few frames (8) are baked by the caller into a MultiMesh of 8 poses or a vertex-animated shader. Also `NewModels.bird_wing_pose_count()` returns 8. |
| `NewModels.balloon()` | `{"envelope": ArrayMesh, "basket": ArrayMesh, "flame": Vector3}` | hot-air balloon, 22 m tall envelope with coloured gores, basket with burner at `flame`. |
| `NewModels.deer()` | `{"body": ArrayMesh, "head_up": ArrayMesh, "head_down": ArrayMesh}` | grazing and alert poses. |
| `NewModels.firework_shell_proxy()` | `ArrayMesh` | a tiny 6 cm shell shape (optional, for the barge). |
| `NewModels.barge()` | `ArrayMesh` | launch barge: flat deck 12 x 5 m with a rack of 20 mortar tubes. |

The preview contact sheet is `docs/realism/models/new_models_sheet.jpg`; the test is `test/new_models_test.gd`.
