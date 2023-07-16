#include <color>

varying coords: vec2<f32>;

fn color_at(pos: vec2<f32>) -> vec4<f32> {
  return vec4<f32>(fract(pos.xy), 0.0, 1.0);
}

@fragment
fn main(input: FragmentInputs) -> FragmentOutputs {
  fragmentOutputs.color = color_at(fragmentInputs.coords);
}
