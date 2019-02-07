#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;

in vec2 fs_Pos;
out vec4 out_Col;

float FOVY = radians(90.0);
float EPSILON = 0.002;

float random1(vec2 p , vec2 seed) {
  return fract(sin(dot(p + seed, vec2(127.1, 311.7))) * 43758.5453);
}


// a function that uses the NDC coordinates of the current fragment (i.e. its fs_Pos value) and projects a ray from that pixel.
vec3 castRay(vec3 eye) {
    float len = length(u_Ref - eye);
    vec3 F = normalize(u_Ref - eye);
    vec3 R = normalize(cross(F, u_Up));
    float aspect = u_Dimensions.x / u_Dimensions.y;
    float alpha = FOVY / 2.0;
    vec3 V = u_Up * len * tan(alpha);
    vec3 H = R * len * aspect * tan(alpha);

    vec3 point = u_Ref + (fs_Pos.x * H + fs_Pos.y * V);
    vec3 ray_dir = normalize(point - eye);

    return ray_dir;
}

//Sphere SDF
float sphereSDF(vec3 p, float r, vec3 scale){
  return length(p * scale) - r;
}

//Torus SDF
float torusSDF( vec3 p, vec2 t )
{
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}

//round box SDF
float roundBoxSDF( vec3 p, vec3 b, float r )
{
  vec3 d = abs(p) - b;
  return length(max(d,0.0)) - r
         + min(max(d.x,max(d.y,d.z)),0.0); // remove this line for an only partially signed sdf
}

//sceneSDF
float sceneSDF(vec3 p)
{
  float roundBox = roundBoxSDF(p, vec3(1.0, 1.0, 1.0), 0.01);
  return roundBox;
}

float rayMarch(vec3 rayDir, vec3 cameraOrigin)
{
    int MAX_ITER = 50;
	float MAX_DIST = 50.0;

    float totalDist = 0.0;
    float totalDist2 = 0.0;
	vec3 pos = cameraOrigin;
	float dist = EPSILON;
    vec3 col = vec3(0.0);
    float glow = 0.0;

    for(int j = 0; j < MAX_ITER; j++)
	{
		dist = sceneSDF(pos);
		totalDist = totalDist + dist;
		pos += dist * rayDir;

        if(dist < EPSILON || totalDist > MAX_DIST)
		{
			break;
		}
	}

    return totalDist  ;
}

void main() {

  vec3 dir = castRay(u_Eye);
  //vec3 color = 0.5 * (dir + vec3(1.0, 1.0, 1.0));
  out_Col = vec4(0.5 * (fs_Pos + vec2(1.0)), 0.5 * (sin(u_Time * 3.14159 * 0.01) + 1.0), 1.0);

  float t = rayMarch(dir, u_Eye);
  if (t < 50.0){
    out_Col = vec4(0.0);
  }
  //out_Col = vec4(color, 1.0);
}
