#include <color>
#include <random/sine_fract>
#include <random/sine_fract_linker>
#include <random/ndim>

varying coords: vec2<f32>;

const FREQUENCY: vec2<f32> = vec2<f32>(2.0, 2.0);

fn voronoi(pos: vec2<f32>) -> vec3<f32> {
  var sampledPos = pos * FREQUENCY;

  let iPos = floor(sampledPos);
  let fPos = fract(sampledPos);

  var f1 = 1.0;
  var f2 = 1.0;

  for (var y: i32 = -1; y <= 1; y = y + 1) {
    for (var x: i32 = -1; x <= 1; x = x + 1) {
      let neighbor = vec2<f32>(f32(x), f32(y));
      let featurePoint = RANDOM__random2d__f32_2d(iPos + neighbor);
      let offset = neighbor + featurePoint - fPos;
      let d = dot(offset, offset);
      
      if (d < f1) {
        f2 = f1;
        f1 = d;
      } else if (d < f2) {
        f2 = d;
      }
    }
  }

  var intensity = 0.0;

  intensity += smoothstep(0.00, 0.15, abs(f1 - f2));

  return intensity * COLORS.WHITE.rgb;
}

fn blend(x: vec3<f32>, y: vec3<f32>) -> vec3<f32> {
  return 0.5 * (x + y);
}

fn color_at(pos: vec2<f32>) -> vec4<f32> {
  var color = vec3<f32>(0.0);

  const LAYERS: i32 = 4;

  for (var i: i32 = 0; i < LAYERS; i = i + 1) {
    color = blend(voronoi(pos + RANDOM__random2d__f32(f32(i))), color);
  }

  return vec4<f32>(color, 1.0);
}

@fragment
fn main(input: FragmentInputs) -> FragmentOutputs {
  fragmentOutputs.color = color_at(fragmentInputs.coords);
}
