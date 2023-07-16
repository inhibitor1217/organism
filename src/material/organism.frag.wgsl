#include <color>
#include <random/sine_fract>
#include <random/sine_fract_linker>
#include <random/ndim>

varying coords: vec2<f32>;

const FREQUENCY: vec2<f32> = vec2<f32>(1.5, 1.5);

fn voronoi(
  pos: vec2<f32>,
  offsetA: ptr<function, vec2<f32>>,
  offsetB: ptr<function, vec2<f32>>,
) -> vec2<f32> {
  let iPos = floor(pos);
  let fPos = fract(pos);

  var dist = vec2<f32>(16.0, 16.0);

  for (var y: i32 = -1; y <= 1; y = y + 1) {
    for (var x: i32 = -1; x <= 1; x = x + 1) {
      let neighbor = vec2<f32>(f32(x), f32(y));
      let featurePoint = RANDOM__random2d__f32_2d(iPos + neighbor);
      let offset = neighbor + featurePoint - fPos;
      let d = dot(offset, offset);
      
      if (d < dist.x) {
        dist.y = dist.x;
        *offsetB = *offsetA;
        dist.x = d;
        *offsetA = offset;
      } else if (d < dist.y) {
        dist.y = d;
        *offsetB = offset;
      }
    }
  }

  return sqrt(dist);
}

fn voronoiLayer(pos: vec2<f32>) -> vec3<f32> {
  var offsetA: vec2<f32>;
  var offsetB: vec2<f32>;
  let dist = voronoi(pos, &offsetA, &offsetB);

  let midpoint = 0.5 * (offsetA + offsetB);
  let normal = normalize(offsetB - offsetA);
  let proj = dot(midpoint, normal);

  var color = vec3<f32>(0.0);

  color += proj * COLORS.WHITE.rgb;

  color += (1.0 - smoothstep(0.00, 0.02, proj)) * COLORS.WHITE.rgb;

  return color;
}

fn blend(x: vec3<f32>, y: vec3<f32>) -> vec3<f32> {
  return mix(x, y, 0.3);
}

fn color_at(pos: vec2<f32>) -> vec4<f32> {
  let sampledPos = pos * FREQUENCY;

  var color = vec3<f32>(0.0);

  const LAYERS: i32 = 3;

  for (var i: i32 = 0; i < LAYERS; i = i + 1) {
    let sampleOffset = f32(i);
    color = blend(voronoiLayer(sampledPos + RANDOM__random2d__f32(sampleOffset)), color);
  }

  return vec4<f32>(color, 1.0);
}

@fragment
fn main(input: FragmentInputs) -> FragmentOutputs {
  fragmentOutputs.color = color_at(fragmentInputs.coords);
}
