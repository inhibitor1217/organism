#include <color>
#include <noise/simplex>
#include <random/sine_fract>
#include <random/sine_fract_linker>
#include <random/ndim>

varying coords: vec2<f32>;

const FREQUENCY: vec2<f32> = vec2<f32>(1.5, 1.5);

fn palette(t: f32) -> vec3<f32> {
  const A: vec3<f32> = vec3<f32>(.2, .7, .4);
  const B: vec3<f32> = vec3<f32>(.6, .9, .2);
  const C: vec3<f32> = vec3<f32>(.6, .8, .7);
  const D: vec3<f32> = vec3<f32>(.5, .1, .0);

  return A + B * cos(6.28318 * (C * t + D));
}

fn voronoi(
  pos: vec2<f32>,
  seed: i32,
  nearest: ptr<function, vec4<f32>>,
  secondNearest: ptr<function, vec4<f32>>,
) -> vec2<f32> {
  let sampleOffset = f32(seed) * vec2<f32>(16.0, 16.0);

  let iPos = floor(pos);
  let fPos = fract(pos);

  var dist = vec2<f32>(16.0, 16.0);

  for (var y: i32 = -1; y <= 1; y = y + 1) {
    for (var x: i32 = -1; x <= 1; x = x + 1) {
      let neighbor = vec2<f32>(f32(x), f32(y));
      let featurePoint = RANDOM__random2d__f32_2d(iPos + neighbor + sampleOffset);
      let offset = neighbor + featurePoint - fPos;
      let d = dot(offset, offset);
      
      if (d < dist.x) {
        dist.y = dist.x;
        *secondNearest = *nearest;
        dist.x = d;
        *nearest = vec4<f32>(offset, iPos + neighbor + featurePoint);
      } else if (d < dist.y) {
        dist.y = d;
        *secondNearest = vec4<f32>(offset, iPos + neighbor + featurePoint);
      }
    }
  }

  return sqrt(dist);
}

fn isHole(pos: vec2<f32>) -> bool {
  var d = 0.0;

  d += length(pos * vec2<f32>(1.5, 1.0));
  d += 1.5 * NOISE_SIMPLEX__noise2d__f32(pos);

  return d < 4.0;
}

fn voronoiLayer(
  pos: vec2<f32>,
  seed: i32,
) -> f32 {
  var nearest: vec4<f32>;
  var secondNearest: vec4<f32>;
  let dist = voronoi(pos, seed, &nearest, &secondNearest);

  let nearestOffset = nearest.xy;
  let secondNearestOffset = secondNearest.xy;

  let nearestFeaturePoint = nearest.zw;
  let secondNearestFeaturePoint = secondNearest.zw;

  let midpoint = 0.5 * (nearestOffset + secondNearestOffset);
  let normal = normalize(secondNearestOffset - nearestOffset);
  let proj = dot(midpoint, normal);

  var intensity = 0.0;

  let isExterior = !isHole(nearestFeaturePoint);
  let isInterior = !isExterior && isHole(secondNearestFeaturePoint);

  // Fill
  if (isExterior) {
    intensity += proj;
  }
  
  // Outline
  if (!isInterior) {
    intensity += .5 * (1.0 - smoothstep(0.00, 0.02, proj));
  }

  return intensity;
}

fn color_at(pos: vec2<f32>) -> vec4<f32> {
  let sampledPos = pos * FREQUENCY;

  const LAYERS: i32 = 6;
  const LAYER_SCALE: f32 = 0.85;
  const LAYER_OFFSET: f32 = 1.0;

  var color = vec3<f32>(0.0);
  var scale = pow(1. / LAYER_SCALE, f32(LAYERS));
  var offset = vec2<f32>(cos(1.0), sin(1.0));
  var offsetAmount = f32(-LAYERS) * LAYER_OFFSET;

  for (var i: i32 = 0; i < LAYERS; i = i + 1) {
    scale *= LAYER_SCALE;
    offsetAmount += LAYER_OFFSET;

    let layerSampledPos = sampledPos * scale + offset * offsetAmount;
    let layerIntensity = voronoiLayer(layerSampledPos, i);
    let layerColor = palette(f32(i));

    if (layerIntensity > 0.0) {
      color = layerIntensity * layerColor + color * 0.5;
    } else {
      color = color * 0.9;
    }
  }

  return vec4<f32>(color, 1.0);
}

@fragment
fn main(input: FragmentInputs) -> FragmentOutputs {
  fragmentOutputs.color = color_at(fragmentInputs.coords);
}
