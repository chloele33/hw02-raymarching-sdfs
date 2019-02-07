#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;

in vec2 fs_Pos;
out vec4 out_Col;

float FOVY = 90.0;


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

void main() {

  vec3 dir = castRay(u_Eye);
  vec3 color = 0.5 * (dir + vec3(1.0, 1.0, 1.0));
  //out_Col = vec4(0.5 * (fs_Pos + vec2(1.0)), 0.5 * (sin(u_Time * 3.14159 * 0.01) + 1.0), 1.0);
  out_Col = vec4(color, 1.0);
}
