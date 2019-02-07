#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;

in vec2 fs_Pos;
out vec4 out_Col;

float FOVY = radians(90.0);
float EPSILON = 0.02;

float random1( vec3 p , vec3 seed) {
  return fract(sin(dot(p + seed, vec3(987.654, 123.456, 531.975))) * 85734.3545);
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


float getMetaBlob(float s1, float s2, float s3, float s4, float s5, float s6)
{
    float k =1.2;
	return -log(exp(-k*s1)+exp(-k*s2)+exp(-k*s3)+exp(-k*s4)+exp(-k*s5)+exp(-k*s6))/k;
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
float rand = random1(vec3(1.0,1.0,1.0), vec3(1.0,1.0,1.0));

  float roundBox1 = roundBoxSDF(p + vec3(4.0 * cos(u_Time* 0.04) , 6.0 * cos(u_Time* 0.02), 1.0* cos(u_Time* 0.01)), vec3(0.5, 0.5, 0.5), 0.5);
  float roundBox2 = roundBoxSDF(p + vec3(4.0 * cos(u_Time* 0.03), 6.0 * cos(u_Time* 0.01), 1.0 * cos(u_Time* 0.01)), vec3(0.5, 0.5, 0.5), 0.5);
  float roundBox3 = roundBoxSDF(p + vec3(4.0 * sin(u_Time* 0.02), 6.0 * sin(u_Time* 0.02), 1.0 * sin(u_Time* 0.01)), vec3(0.5, 0.5, 0.5), 0.5);
  float roundBox4 = roundBoxSDF(p + vec3(4.0 * sin(u_Time* 0.04) , 6.0 * sin(u_Time* 0.01), 1.0 * sin(u_Time* 0.01)), vec3(0.5, 0.5, 0.5), 0.5);
  float torus1 = torusSDF(p + vec3(0.0, -4.0, 0.0) , vec2(6.0, 0.5));
  float sphere1 = sphereSDF(p + vec3(0.0, 4.0, 0.0), 2.0, vec3(1.0, 1.0, 1.0));
  //float torus1 = roundBoxSDF(p, vec3(1.0, 1.0, 1.0), 0.8);
  //float sphere1 = roundBoxSDF(p, vec3(1.0, 1.0, 1.0), 0.8);

  float meta = getMetaBlob(roundBox1, roundBox2, roundBox3, roundBox4, torus1, sphere1);
  return meta;
}



// Bounding Volumne Hierarchy
// Cube
struct Cube {
	vec3 min;
	vec3 max;
};

// Ray-cube intersection
float cubeIntersect(vec3 raydir, vec3 origin, Cube cube) {
    float tNear = -9999999.0;
    float tFar = 9999999.0;
    float far = 9999999.0;
    //X SLAB

    //if ray is parallel to x plane
    if (raydir.x == 0.0f) {
        if (origin.x < cube.min.x) {
            return far;
        }
        if (origin.x > cube.max.x) {
            return far;
        }
    }
    float t0 = (cube.min.x - origin.x) / raydir.x;
    float t1 = (cube.max.x - origin.x) / raydir.x;
    // swap
    if (t0 > t1) {
        float temp = t0;
        t0 = t1;
        t1 = temp;
    }
    if (t0 > tNear) {
        tNear = t0;
    }
    if (t1 < tFar) {
        tFar = t1;
    }

    //Y SLAB
    if (raydir.y == 0.0f) {
        if (origin.y < cube.min.y) {
            return far;
        }
        if (origin.y > cube.max.y) {
            return far;
        }
    }
    t0 = (cube.min.y - origin.y) / raydir.y;
    t1 = (cube.max.y - origin.y) / raydir.y;
    // swap
    if (t0 > t1) {
        float temp = t0;
        t0 = t1;
        t1 = temp;
    }
    if (t0 > tNear) {
        tNear = t0;
    }
    if (t1 < tFar) {
        tFar = t1;
    }

     //Z SLAB
    if (raydir.z == 0.0f) {
        if (origin.z < cube.min.z) {
            return far;
        }
        if (origin.z > cube.max.z) {
            return far;
        }
    }
    t0 = (cube.min.z - origin.z) / raydir.z;
    t1 = (cube.max.z - origin.z) / raydir.z;
    // swap
    if (t0 > t1) {
        float temp = t0;
        t0 = t1;
        t1 = temp;
    }
    if (t0 > tNear) {
        tNear = t0;
    }
    if (t1 < tFar) {
        tFar = t1;
    }

//    if (tNear < 0.0) {
//        return far;
//    }

    // missed the cube
    if (tNear > tFar) {
        return far;
    }

    return tNear;

}


Cube sceneBB() {
	Cube cube;
	cube.min = vec3(-6.0, -6.0, -6.0);
	cube.max = vec3(6.0, 8.0, 6.0);
	return cube;
}

Cube sphereBB() {
	Cube cube;
	cube.min = vec3(-1.0, -5.0, -1.0);
	cube.max = vec3(1.0, 8.0, 1.0);
	return cube;
}

Cube metaCubesBB() {
	Cube cube;
	cube.min = vec3(-3.0, -6.0, -3.0);
	cube.max = vec3(3.0, 8.0, 3.0);
	return cube;
}

Cube torusBB() {
    Cube cube;
	cube.min = vec3(-6.0, -6.0, -6.0);
	cube.max = vec3(6.0, -2.0, 6.0);
	return cube;

}

float BVH(vec3 origin, vec3 dir, Cube cubes[4]) {
    float currT = 999999.0;
    for (int i = 0; i < cubes.length(); i++) {
        float t = cubeIntersect(dir, origin, cubes[i]);
        if (currT > t) {
            currT = t;
        }
    }
    return currT;
  }

float rayMarch(vec3 rayDir, vec3 cameraOrigin)
{
    // check for bounding boxes
    Cube cubes[4];
    cubes[0] = sceneBB();
    cubes[1] = sphereBB();
    cubes[2] = metaCubesBB();
    cubes[3] = torusBB();
    if (BVH(cameraOrigin, rayDir, cubes) > 50.0) {
        return 10000.0;
    }
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
