#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;
uniform float u_RingSize;
uniform vec3 u_Color;

in vec2 fs_Pos;
out vec4 out_Col;

float FOVY = radians(45.0);
float EPSILON = 0.02;

float random1( vec3 p , vec3 seed) {
  return fract(sin(dot(p + seed, vec3(987.654, 123.456, 531.975))) * 85734.3545);
}

float random1( vec2 p , vec2 seed) {
  return fract(sin(dot(p + seed, vec2(127.1, 311.7))) * 43758.5453);
}


float interpNoise2D(float x, float y) {
    float intX = floor(x);
    float intY = floor(y);
    float fractX = fract(x);
    float fractY = fract(y);

    float v1 = random1(vec2(intX, intY), vec2(1.0, 1.0));
    float v2 = random1(vec2(intX + 1.0, intY), vec2(1.0, 1.0));
    float v3 = random1(vec2(intX, intY + 1.0), vec2(1.0, 1.0));
    float v4 = random1(vec2(intX + 1.0, intY + 1.0), vec2(1.0, 1.0));

    float i1 = mix(v1, v2, fractX);
    float i2 = mix(v3, v4, fractX);
    return mix(i1, i2, fractY);
}

float fbm(float x, float y) {
  float total = 0.f;
  float persistence = 0.5f;
  int octaves = 8;
  float roughness = 1.0;

  vec2 pos = vec2(x, y);
  vec2 shift = vec2(100.0);

  mat2 rot = mat2(cos(0.5), sin(0.5),
                      -sin(0.5), cos(0.50));

  for (int i = 0; i < octaves; i++) {
    float freq = pow(2.0, float(i));
    float amp = pow(persistence, float(i));

    pos = rot * pos * 1.0 + shift;

    total += abs(interpNoise2D( pos.x / 100.0  * freq, pos.y / 20.0 * freq)) * amp * roughness;
    roughness *= interpNoise2D(pos.x / 5.0  * freq, pos.y / 5.0 * freq);
  }
  return  total;
}

float worley(float x, float y, float scale) {
    float scale_invert = abs(80.0 - scale);
    vec2 pos = vec2(x/scale_invert, y/scale_invert);

    float m_dist = 40.f;  // minimun distance
    vec2 m_point = vec2(0.f, 0.f);       // minimum point

    for (int j=-1; j<=1; j++ ) {
        for (int i=-1; i<=1; i++ ) {
            vec2 neighbor = vec2(floor(pos.x) + float(j), floor(pos.y) + float(i));
            vec2 point = neighbor + random1(neighbor, vec2(1.f, 1.f));
            float dist = distance(pos, point);

            if( dist < m_dist ) {
                m_dist = dist;
                m_point = point;
            }
        }
    }
    return m_dist;
}


// reference from class slides
float triangleWave( float x, float freq, float amp)
{
    return floor(abs(mod((x*freq) , amp) - (0.5 * amp)));
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

float opSubtraction( float d1, float d2 ) { return max(-d1,d2); }

float opIntersection( float d1, float d2 ) { return max(d1,d2); }

float opSmoothIntersection( float d1, float d2, float k )
{
    float h = clamp( 0.5 - 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) + k*h*(1.0-h);
    }

float SDFblob(float sphere, float cube) {
    return (opSmoothIntersection(sphere, cube, 0.25));
}

float getMetaBlob(float s1, float s2, float s3, float s4, float s5, float s6, float s7)
{
    float k =1.2;
	return -log(exp(-k*s1)+exp(-k*s2)+exp(-k*s3)+exp(-k*s4)+exp(-k*s5)+exp(-k*s6)+exp(-k*s7))/k;
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
  float pulse = smoothstep(1.0, -1.0,  0.5 * (sin(u_Time / 15.0) + 1.0));

  float roundBox1 = roundBoxSDF(p + vec3(4.0 * cos(u_Time* 0.04) , 6.0 * cos(u_Time* 0.02), 1.0* cos(u_Time* 0.01)), vec3(0.5, 0.5, 0.5), 0.5);
  float roundBox2 = roundBoxSDF(p + vec3(4.0 * cos(u_Time* 0.03), 6.0 * cos(u_Time* 0.01), 1.0 * cos(u_Time* 0.01)), vec3(0.5, 0.5, 0.5), 0.5);
  float roundBox3 = roundBoxSDF(p + vec3(4.0 * sin(u_Time* 0.02), 6.0 * sin(u_Time* 0.02), 1.0 * sin(u_Time* 0.01)), vec3(0.5, 0.5, 0.5), 0.5);
  float roundBox4 = roundBoxSDF(p + vec3(4.0 * sin(u_Time* 0.04) , 6.0 * sin(u_Time* 0.01), 1.0 * sin(u_Time* 0.01)), vec3(0.5, 0.5, 0.5), 0.5);
  float torus1 = torusSDF(p + vec3(0.0, -2.0, 0.0) , vec2(u_RingSize, 0.7));
  float sphere1 = sphereSDF(p + vec3(0.0, 4.0, 0.0),  4.0, vec3(1.0, 1.0, 1.0));
  float cube1 = roundBoxSDF(p + vec3(0.0, 4.0, 0.0), vec3(4.0, 0.01, 4.0), 0.5);
  float flatCyn = SDFblob(sphere1, cube1);
  float sphere2 = sphereSDF(p + vec3(0.0, -7.0, 0.0), pulse* 1.0, vec3(1.0, 1.0, 1.0));


  //float torus1 = roundBoxSDF(p, vec3(1.0, 1.0, 1.0), 0.8);
  //float sphere1 = roundBoxSDF(p, vec3(1.0, 1.0, 1.0), 0.8);

  float meta = getMetaBlob(roundBox1, roundBox2, roundBox3, roundBox4, torus1, flatCyn, sphere2);
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
	cube.min = vec3(-7.0, -8.0, -7.0);
	cube.max = vec3(7.0, 8.0, 7.0);
	return cube;
}

Cube sphereBB() {
	Cube cube;
	cube.min = vec3(-1.0, -8.0, -1.0);
	cube.max = vec3(1.0, -6.0, 1.0);
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
	cube.min = vec3(-7.0, -7.0, -7.0);
	cube.max = vec3(7.0, -2.0, 7.0);
	return cube;

}

Cube flatCynBB() {
    Cube cube;
	cube.min = vec3(-4.0, 6.0, -4.0);
	cube.max = vec3(4.0, 4.0, 4.0);
	return cube;

}

float BVH(vec3 origin, vec3 dir, Cube cubes[5]) {
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
    Cube cubes[5];
    cubes[0] = sceneBB();
    cubes[1] = sphereBB();
    cubes[2] = metaCubesBB();
    cubes[3] = torusBB();
    cubes[4] = flatCynBB();
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

// calculate normals
vec3 getNormal(vec3 p) {
   vec3 normal = normalize(vec3(
        sceneSDF(vec3(p.x + EPSILON, p.y, p.z)) - sceneSDF(vec3(p.x - EPSILON, p.y, p.z)),
        sceneSDF(vec3(p.x, p.y + EPSILON, p.z)) - sceneSDF(vec3(p.x, p.y - EPSILON, p.z)),
        sceneSDF(vec3(p.x, p.y, p.z  + EPSILON)) - sceneSDF(vec3(p.x, p.y, p.z - EPSILON))
    ));
    float eps = 0.0001; // or some other value
     vec2 h = vec2(eps,0);
    return normalize( vec3(sceneSDF(p+h.xyy) - sceneSDF(p-h.xyy),
                           sceneSDF(p+h.yxy) - sceneSDF(p-h.yxy),
                           sceneSDF(p+h.yyx) - sceneSDF(p-h.yyx) ) );
}

vec3 getShading(vec3 pos , vec3 lightp, vec3 color, vec3 rayDir)
{
	vec3 norm = getNormal(pos);
    vec3 lightdir = normalize(pos - lightp);

    vec3 amb = vec3(0.08);
    vec3 diffuse = vec3(0.5 * pow(0.5+0.5*dot(norm, -lightdir), 3.0));
    vec3 phong = vec3(0.8 * pow(max(dot(-rayDir, reflect(lightdir, norm)), 0.0), 20.0));

    return (amb + diffuse + phong) * color;
}


void main() {

  vec3 dir = castRay(u_Eye);


  //vec3 color = 0.5 * (dir + vec3(1.0, 1.0, 1.0));
  //out_Col = vec4(0.5 * (vec2(1.0)), 0.5 * (sin(u_Time * 3.14159 * 0.01) + 1.0), 1.0);

  float t = rayMarch(dir, u_Eye);
  if (t < 50.0){
    vec3 light1 = getShading(u_Eye + t * dir, vec3(5.0,10.0,-20.0), vec3(1.0,1.0,1.0), dir);
    vec3 light2 = getShading(u_Eye + t * dir, vec3(-20,10.0,5.0), vec3(0.5,0.4,0.1), dir);
    vec3 light3 = getShading(u_Eye + t * dir, vec3(25.0,5.0,-5.0), vec3(0.7,0.3,0.1), dir);
    vec3 color = light1+light2+light3;
    out_Col = vec4(color , 1.0);
  } else {
     vec3 background = vec3(0.05, 0.03, 0.0);
    vec3 highlight = u_Color;
    float textureMap = worley(fs_Pos.x * 80.0, fs_Pos.y * 60.0 ,5.0 * sin(u_Time / 80.0)) - 0.15 * fbm(fs_Pos.x, fs_Pos.y);

    vec3 backgroundCol = textureMap * (highlight) + (1.0 - textureMap) * (background);

    out_Col = vec4(backgroundCol, 1.0);
  }
  //out_Col = vec4(color, 1.0);
}
