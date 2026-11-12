// SDF raymarching renderer - main scene
// Tanguy Vallot
//
// Paste this file into a new shader on shadertoy.com.
// Drag the mouse horizontally to orbit the camera.

// Scene selection
// 0 : full scene (all objects on a noise terrain)
// 1 : basic primitives
// 2 : procedural noise and textures (marble, wood)
// 3 : complex shapes built with CSG
// 4 : terrain with a cave and overhangs
#define SCENE 0

// Light type: 0 = directional light, 1 = point light
#define POINT_LIGHT 0

// Output: 0 = shaded image, 1 = number of marching steps, 2 = field evaluation cost
#define VIEW 0

struct Ray {
    vec3 o; // Origin
    vec3 d; // Direction
};

struct Material {
    vec3 color;         // Base color
    float ka;           // Ambient coefficient
    float kd;           // Diffuse coefficient
    float ks;           // Specular coefficient
    float shininess;    // Specular exponent
    float reflectivity; // 0.0 = matte, 1.0 = perfect mirror
};

struct Val {
    float v;      // Signed distance
    int c;        // Evaluation cost
    Material mat; // Material
};

// Compute point on ray
// ray : The ray
// t : Distance
vec3 Point(Ray ray, float t)
{
    return ray.o + t * ray.d;
}

// Random direction in a hemisphere
// seed : Integer seed, from 0 to N
// n : Direction of the hemisphere
vec3 Hemisphere(int seed, vec3 n)
{
    float a = fract(sin(176.19 * float(seed))); // Uniform randoms
    float b = fract(sin(164.19 * float(seed)));

    float u = 2. * 3.1415 * a;   // Random angle
    float v = acos(2. * b - 1.); // Arccosine distribution to compensate at poles

    vec3 d = vec3(cos(u) * cos(v), sin(u) * cos(v), sin(v)); // Direction
    if (dot(d, n) < 0.) { d = -d; } // Hemisphere

    return d;
}

// Camera -------------------------------------------------------------------------------

// Rotation matrix around z axis
// a : Angle
mat3 Rz(float a)
{
    float sa = sin(a); float ca = cos(a);
    return mat3(ca, sa, 0., -sa, ca, 0., 0., 0., 1.);
}

// Compute the ray
// m : Mouse position
// p : Pixel
Ray CreateRay(vec2 m, vec2 p)
{
    float a = 3. * 3.14 * m.x;
    float le = 2.;

    // Origin
    vec3 ro = vec3(37., 0., 15.);
    ro *= Rz(a);

    // Target point
    vec3 ta = vec3(0., 0., 1.);

    // Orthonormal frame
    vec3 w = normalize(ta - ro);
    vec3 u = normalize(cross(w, vec3(0., 0., 1.)));
    vec3 v = normalize(cross(u, w));
    vec3 rd = normalize(p.x * u + p.y * v + le * w);
    return Ray(ro, rd);
}

// Primitives -------------------------------------------------------------------------------

// Sphere
// p : point
// c : center
// r : radius
Val Sphere(vec3 p, vec3 c, float r)
{
    float d = length(p - c) - r;
    Material mat;
    mat.color = vec3(0.9, 0.3, 0.2); // red
    mat.ka = 0.2;
    mat.kd = 0.6;
    mat.ks = 0.4;
    mat.shininess = 32.0;
    mat.reflectivity = 0.5;
    return Val(d, 1, mat);
}

// Plane
// p : point
// n : normal of the plane
// o : point on the plane
Val Plane(vec3 p, vec3 n, vec3 o)
{
    float d = dot((p - o), n);
    Material mat;
    mat.color = vec3(0.5);
    mat.ka = 0.15;
    mat.kd = 0.5;
    mat.ks = 0.0;
    mat.shininess = 4.0;
    mat.reflectivity = 0.5;
    return Val(d, 1, mat);
}

// Ellipsoid (approximate distance, scaled by the smallest radius)
// p : point in space
// c : center of the ellipsoid
// r : radii along each axis
Val Ellipsoid(vec3 p, vec3 c, vec3 r)
{
    vec3 q = (p - c) / r;
    float d = length(q) - 1.0;
    d *= min(min(r.x, r.y), r.z);
    Material mat;
    mat.color = vec3(0.6, 0.2, 0.7); // purple
    mat.ka = 0.2;
    mat.kd = 0.6;
    mat.ks = 0.3;
    mat.shininess = 25.0;
    mat.reflectivity = 0.5;
    return Val(d, 1, mat);
}

// Box
// p : point in space
// c : center of the box
// s : half-size of the box
Val Box(vec3 p, vec3 c, vec3 s)
{
    vec3 d = abs(p - c) - s;
    float outside = length(max(d, 0.0));
    float inside = min(max(d.x, max(d.y, d.z)), 0.0);
    float dist = outside + inside;
    Material mat;
    mat.color = vec3(0.2, 0.5, 0.8); // blue
    mat.ka = 0.25;
    mat.kd = 0.55;
    mat.ks = 0.35;
    mat.shininess = 20.0;
    mat.reflectivity = 0.5;
    return Val(dist, 1, mat);
}

// Infinite cylinder along the z axis
// p : point in space
// c : point on the cylinder axis
// r : radius of the cylinder
Val Cylinder(vec3 p, vec3 c, float r)
{
    vec2 d = p.xy - c.xy;
    float dist = length(d) - r;
    Material mat;
    mat.color = vec3(0.3, 0.8, 0.3); // green
    mat.ka = 0.2;
    mat.kd = 0.6;
    mat.ks = 0.3;
    mat.shininess = 16.0;
    mat.reflectivity = 0.5;
    return Val(dist, 1, mat);
}

// Capsule between points a and b
// p : point in space
// a, b : endpoints of the capsule segment
// r : radius of the capsule
Val Capsule(vec3 p, vec3 a, vec3 b, float r)
{
    vec3 pa = p - a;
    vec3 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    float dist = length(pa - h * ba) - r;
    Material mat;
    mat.color = vec3(0.3, 1.0, 0.3); // light green
    mat.ka = 0.2;
    mat.kd = 0.5;
    mat.ks = 0.4;
    mat.shininess = 28.0;
    mat.reflectivity = 0.5;
    return Val(dist, 1, mat);
}

// Torus
// p : point in space
// c : center of the torus
// r : main radius
// t : tube radius
Val Torus(vec3 p, vec3 c, float r, float t)
{
    vec3 q = p - c;
    vec2 k = vec2(length(q.xz) - r, q.y);
    float dist = length(k) - t;
    Material mat;
    mat.color = vec3(1.0, 0.6, 0.1); // orange
    mat.ka = 0.25;
    mat.kd = 0.55;
    mat.ks = 0.3;
    mat.shininess = 24.0;
    mat.reflectivity = 0.5;
    return Val(dist, 1, mat);
}

// Operators ---------------------------------------------------------------

// Union
// a, b : field functions of the left and right sub-trees
Val Union(Val a, Val b)
{
    Val res;
    if (a.v < b.v) res = a;
    else res = b;
    res.c = a.c + b.c + 1;
    return res;
}

// Intersection
Val Intersection(Val a, Val b)
{
    Val res;
    if (a.v > b.v) res = a;
    else res = b;
    res.c = a.c + b.c + 1;
    return res;
}

// Difference (a minus b), keeps the material of a
Val Difference(Val a, Val b)
{
    Val res = a;
    res.v = max(a.v, -b.v);
    res.c = a.c + b.c + 1;
    return res;
}

// Smooth difference, k controls the blending radius
Val SmoothDifference(Val a, Val b, float k)
{
    float h = clamp(0.5 + 0.5 * (a.v + b.v) / k, 0.0, 1.0);
    float d = mix(a.v, -b.v, h) - k * h * (1.0 - h);
    Val res = a;
    res.v = d;
    res.c = a.c + b.c;
    // Keep the material of a: blending materials creates artifacts
    return res;
}

// Rotation around Y axis
mat3 RotateY(float a)
{
    float c = cos(a);
    float s = sin(a);
    return mat3(
        c, 0.0, -s,
        0.0, 1.0, 0.0,
        s, 0.0, c
    );
}

// Rotation around X axis
mat3 RotateX(float a)
{
    float c = cos(a);
    float s = sin(a);
    return mat3(
        1.0, 0.0, 0.0,
        0.0, c, -s,
        0.0, s, c
    );
}

// Rotation around Z axis
mat3 RotateZ(float a)
{
    float c = cos(a);
    float s = sin(a);
    return mat3(
        c, -s, 0.0,
        s, c, 0.0,
        0.0, 0.0, 1.0
    );
}

// Translation
// p : point in space
// offset : translation vector
vec3 Translate(vec3 p, vec3 offset)
{
    return p - offset;
}

// Scaling (the resulting distance must be multiplied by s)
// p : point in space
// s : scale factor
vec3 Scale(vec3 p, float s)
{
    return p / s;
}

// Noise and procedural textures ----------------------------------------------------

float hash(vec3 p)
{
    return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
}

// Value noise based on trilinear interpolation
float noise(vec3 p)
{
    vec3 i = floor(p);
    vec3 f = fract(p);

    float n000 = hash(i + vec3(0.0, 0.0, 0.0));
    float n100 = hash(i + vec3(1.0, 0.0, 0.0));
    float n010 = hash(i + vec3(0.0, 1.0, 0.0));
    float n110 = hash(i + vec3(1.0, 1.0, 0.0));
    float n001 = hash(i + vec3(0.0, 0.0, 1.0));
    float n101 = hash(i + vec3(1.0, 0.0, 1.0));
    float n011 = hash(i + vec3(0.0, 1.0, 1.0));
    float n111 = hash(i + vec3(1.0, 1.0, 1.0));

    vec3 u = f * f * (3.0 - 2.0 * f);

    return mix(
        mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
        mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y),
        u.z);
}

// Displace a surface with noise
Val Perturb(Val v, vec3 p, float amplitude, float frequency)
{
    float n = noise(p * frequency);
    v.v += amplitude * (n - 0.5);
    return v;
}

// Sum of noise octaves
float Turbulence(vec3 p, int octaves)
{
    float sum = 0.0;
    float freq = 1.0;
    float amp = 1.0;
    for (int i = 0; i < octaves; ++i)
    {
        sum += abs(noise(p * freq)) * amp;
        freq *= 2.0;
        amp *= 0.5;
    }
    return sum;
}

// Displace a surface with turbulence instead of simple noise
Val PerturbTurbulence(Val v, vec3 p, float amplitude, float frequency, int octaves)
{
    float t = Turbulence(p * frequency, octaves);
    v.v += amplitude * (t - 0.5); // Center around 0
    return v;
}

// Marble pattern in [0, 1]
float Marble(vec3 p, float frequency, float scale, int octaves)
{
    float t = Turbulence(p * frequency, octaves);
    float pattern = sin(p.x * frequency + scale * t);
    return 0.5 + 0.5 * pattern;
}

// Wood pattern in [0, 1] (concentric rings)
float Wood(vec3 p, float frequency, float scale, int octaves)
{
    float radius = length(p.xz);
    float t = Turbulence(p * frequency, octaves);
    float pattern = sin(radius * frequency + scale * t);
    return 0.5 + 0.5 * pattern;
}

// Complex shapes -------------------------------------------------------------------

// Sphere drilled by five cylinders
Val SphereWithMultipleHoles(vec3 p, vec3 center, float radius)
{
    Val base = Sphere(p, center, radius);

    vec3 dirs[5];
    dirs[0] = normalize(vec3(1.0, 0.0, 0.0));
    dirs[1] = normalize(vec3(0.0, 1.0, 0.0));
    dirs[2] = normalize(vec3(0.0, 0.0, 1.0));
    dirs[3] = normalize(vec3(1.0, 1.0, 0.0));
    dirs[4] = normalize(vec3(-1.0, 0.5, 1.0));

    float rCyl = 0.3;

    for (int i = 0; i < 5; ++i)
    {
        vec3 q = p - center;
        vec3 d = q - dot(q, dirs[i]) * dirs[i];
        float dist = length(d) - rCyl;
        Val cyl = Val(dist, 1, base.mat);
        base = Difference(base, cyl);
    }

    return base;
}

// Half ellipsoid with ridges, like a shell
Val ShellStructure(vec3 p, vec3 center, vec3 size)
{
    vec3 q = (p - center) / size;
    float d = length(q) - 1.0;
    d *= min(min(size.x, size.y), size.z);

    // Cut the bottom half (z < 0)
    float dz = (p.z - center.z);
    d = max(d, -dz);

    float ridges = 0.15 * sin(10.0 * length(p.xy - center.xy));
    d += ridges;

    Material mat;
    mat.color = vec3(0.4, 0.7, 0.2);
    mat.ka = 0.2;
    mat.kd = 0.6;
    mat.ks = 0.3;
    mat.shininess = 30.0;
    mat.reflectivity = 0.;
    return Val(d, 5, mat);
}

// Water drop shape
Val WaterDrop(vec3 p, vec3 center, float scale)
{
    vec3 q = (p - center) / scale;
    float r = length(q.xy);
    float d = length(vec2(r, q.z - r)) - 1.0;
    d *= scale;

    Material mat;
    mat.color = vec3(0.2, 0.6, 0.9);
    mat.ka = 0.2;
    mat.kd = 0.6;
    mat.ks = 0.5;
    mat.shininess = 50.0;
    mat.reflectivity = 0.0;
    return Val(d, 4, mat);
}

// Box drilled by a vertical cylinder
Val HoledBox(vec3 p, vec3 center, vec3 size, float holeRadius)
{
    Val box = Box(p, center, size);
    Val cyl = Cylinder(p, center, holeRadius);
    return Difference(box, cyl);
}

// Staircase of cubes with a sphere on top
Val Stairs(vec3 p)
{
    Val v = Val(1e5, 0, Material(vec3(0.0), 0.0, 0.0, 0.0, 1.0, 0.0));

    for (int i = 0; i < 4; ++i)
    {
        vec3 offset = vec3(float(i), float(i), float(i));
        Val box = Box(p, offset, vec3(0.5));
        v = Union(v, box);
    }

    Val sphere = Sphere(p, vec3(2.0, 2.0, 3.0), 0.6);
    v = Union(v, sphere);

    return v;
}

// Terrain height from fractal noise
float TerrainHeight(vec2 p)
{
    float h = 0.0;
    float freq = 0.2;
    float amp = 1.5;
    for (int i = 0; i < 4; ++i)
    {
        h += amp * noise(vec3(p * freq, 0.0));
        freq *= 2.0;
        amp *= 0.5;
    }
    return h;
}

// Heightfield terrain, distance divided by the Lipschitz constant
Val Terrain(vec3 p)
{
    float h = TerrainHeight(p.xy);
    float d = p.z - h;
    float lipschitz = 1.5;

    Material mat;
    mat.color = vec3(0.3, 0.25, 0.2);
    mat.ka = 0.15;
    mat.kd = 0.5;
    mat.ks = 0.1;
    mat.shininess = 8.0;
    mat.reflectivity = 0.0;
    return Val(d / lipschitz, 1, mat);
}

// Scenes ----------------------------------------------------------------------------

// Basic primitives and transformations
Val BasicPrimitives(vec3 p)
{
    Val v = Sphere(p, vec3(6.5, 0., 5.5), 2.25);

    // Ellipsoid, uniformly scaled down by half
    vec3 offsetEllipsoid = vec3(-10., 0., 4.);
    float scaleEllipsoid = 0.5;
    vec3 prEllipsoid = Translate(p, offsetEllipsoid);
    prEllipsoid = Scale(prEllipsoid, scaleEllipsoid);
    Val ellip = Ellipsoid(prEllipsoid, vec3(0.), vec3(1., 2., 1.5));
    ellip.v *= scaleEllipsoid;
    v = Union(v, ellip);

    // Same ellipsoid at its real size
    vec3 centerEllipsoid2 = vec3(-13., 0., 4.);
    vec3 prEllipsoid2 = Translate(p, centerEllipsoid2);
    Val ellip2 = Ellipsoid(prEllipsoid2, vec3(0.), vec3(1.0, 2.0, 1.5));
    v = Union(v, ellip2);

    // Box rotated by 45 degrees
    vec3 centerBox = vec3(-5., 0., 4.);
    float angle = 3.1415 / 4.0;
    vec3 rotY = inverse(RotateY(angle)) * (p - centerBox);
    Val box = Box(rotY, vec3(0.), vec3(1.5));
    v = Union(v, box);

    // Cylinder
    vec3 offset = vec3(0., 0., 4);
    vec3 pr = Translate(p, offset);
    Val cyl = Cylinder(pr, vec3(0.), 1.5);
    v = Union(v, cyl);

    // Capsule
    Val capsule = Capsule(p, vec3(15., 0., 3.), vec3(15., 0., 6.), 0.75);
    v = Union(v, capsule);

    // Torus
    Val torus = Torus(p, vec3(7., 0., 6.), 3.0, 1.0);
    v = Union(v, torus);

    return v;
}

// Noise displacement and procedural textures
Val ProceduralTextures(vec3 p)
{
    // Sphere with noise bumps
    Val v = Sphere(p, vec3(-6., 12., 4.), 2.0);
    v = Perturb(v, p, 0.2, 1.0);

    // Torus with turbulence and marble texture
    Val t = Torus(p, vec3(-20., 0., 6.), 3.0, 1.0);
    t = PerturbTurbulence(t, p, 0.25, 2.0, 4);
    float m = Marble(p, 4.0, 6.0, 4);
    t.mat.color = mix(vec3(0.8), vec3(0.3), m);
    v = Union(v, t);

    // Capsule with wood texture
    Val c = Capsule(p, vec3(-10., 12., 4.), vec3(-10., 14., 6.), 0.75);
    c = Perturb(c, p, 0.1, 5.0);
    float w = Wood(p, 3.0, 5.0, 4);
    c.mat.color = mix(vec3(0.35, 0.2, 0.1), vec3(0.6, 0.4, 0.2), w);
    v = Union(v, c);

    return v;
}

// Complex shapes built with CSG
Val ComplexShapes(vec3 p)
{
    Val v = SphereWithMultipleHoles(p, vec3(5., 0., 12), 2.0);
    v = Union(v, ShellStructure(p, vec3(5.0, 5.0, 3.), vec3(2.0)));
    v = Union(v, WaterDrop(p, vec3(5.0, 5.0, 7.0), 1.0));
    v = Union(v, HoledBox(p, vec3(-5.0, 0.0, 10), vec3(1.5), 0.5));
    v = Union(v, Stairs(p - vec3(8.0, 8.0, 3.0)));
    return v;
}

// Terrain with a cave (sphere subtraction) and four overhangs (ellipsoids)
Val TerrainScene(vec3 p)
{
    Val terrain = Terrain(p);

    Val cave = Sphere(p, vec3(8., 9., 0.), 8.0);
    Val terrainCut = Difference(terrain, cave);
    terrainCut.mat = terrain.mat;

    Val hill1 = Ellipsoid(p, vec3(-5., 15., 0.8), vec3(4.0, 4.0, 2.0));
    Val hill2 = Ellipsoid(p, vec3( 0., 15., 0.8), vec3(4.0, 4.0, 2.0));
    Val hill3 = Ellipsoid(p, vec3( 5., 15., 0.8), vec3(4.0, 4.0, 2.0));
    Val hill4 = Ellipsoid(p, vec3(10., 15., 0.8), vec3(4.0, 4.0, 2.0));

    Val result = Difference(terrainCut, hill1);
    result = Difference(result, hill2);
    result = Difference(result, hill3);
    result = Difference(result, hill4);

    result = Union(result, hill1);
    result = Union(result, hill2);
    result = Union(result, hill3);
    result = Union(result, hill4);

    result.mat = terrain.mat;
    return result;
}

// Flat ground
Val Ground(vec3 p)
{
    return Plane(p, vec3(0., 0., 1.), vec3(0.0, 0.0, -4.0));
}

// Signed distance field of the whole scene
Val object(vec3 p)
{
    // Start with an empty field
    Val v = Val(1e5, 0, Material(vec3(0.0), 0., 0., 0., 1., 0.));

#if SCENE == 0
    v = Union(v, BasicPrimitives(p));
    v = Union(v, ProceduralTextures(p));
    v = Union(v, ComplexShapes(p));
    v = Union(v, TerrainScene(p));
#elif SCENE == 1
    v = Union(v, BasicPrimitives(p));
    v = Union(v, Ground(p));
#elif SCENE == 2
    v = Union(v, ProceduralTextures(p));
    v = Union(v, Ground(p));
#elif SCENE == 3
    v = Union(v, ComplexShapes(p));
    v = Union(v, Ground(p));
#else
    v = Union(v, TerrainScene(p));
#endif

    return v;
}

// Analysis of the scalar field -----------------------------------------------------------------

const int Steps = 200;       // Number of steps
const float Epsilon = .01;   // Marching epsilon

// Object normal (forward differences)
// p : point
vec3 ObjectNormal(vec3 p)
{
    const float eps = .001;
    vec3 n;
    float v = object(p).v;
    n.x = object(vec3(p.x + eps, p.y, p.z)).v - v;
    n.y = object(vec3(p.x, p.y + eps, p.z)).v - v;
    n.z = object(vec3(p.x, p.y, p.z + eps)).v - v;
    return normalize(n);
}

// Trace ray using sphere tracing
// ray : The ray
// e : Maximum distance
// t : Distance to the hit point
// s : Number of steps
// c : Evaluation cost
// returns true on hit
bool SphereTrace(Ray ray, float e, out float t, out int s, out int c)
{
    bool h = false;

    // Start at the origin
    t = 0.0;
    c = 0;

    for (int i = 0; i < Steps; i++)
    {
        s = i;
        vec3 p = Point(ray, t);
        Val val = object(p);
        float v = val.v;
        c += val.c;
        // Hit object
        if (v < 0.)
        {
            h = true;
            break;
        }
        // Move along ray
        t += max(Epsilon, v);
        // Escape: marched too far away
        if (t > e)
        {
            break;
        }
    }
    return h;
}

// Ambient occlusion: fraction of short hemisphere rays that hit nothing
float AmbientOcclusion(vec3 p, vec3 n)
{
    const int N = 4; // Number of rays
    float occlusion = 0.0;

    for (int i = 0; i < N; ++i)
    {
        vec3 dir = Hemisphere(i, n);
        float t;
        int s, c;
        bool hit = SphereTrace(Ray(p + Epsilon * n, dir), 2.0, t, s, c);
        if (hit)
        {
            occlusion += 1.0;
        }
    }

    // 1.0 : no occlusion, 0.0 : fully occluded
    return 1.0 - (occlusion / float(N));
}

// Lighting -------------------------------------------------------------------------------

// Background color
// ray : Ray
vec3 background(Ray ray)
{
    return mix(vec3(.45, .55, .99), vec3(.65, .69, .99), ray.d.z * .5 + .5);
}

// Direction towards the light from point p
vec3 LightDirection(vec3 p)
{
#if POINT_LIGHT == 1
    const vec3 lp = vec3(0., 10., 15.);
    return normalize(lp - p);
#else
    return normalize(vec3(0.0, 1.0, -0.3));
#endif
}

// Hard shadow
// p : Point
// n : Normal
// l : Light direction
float Shadow(vec3 p, vec3 n, vec3 l)
{
    float t;
    int s;
    int c;
    bool hit = SphereTrace(Ray(p + Epsilon * n, l), 100., t, s, c);
    if (!hit)
    {
        return 1.;
    }
    return 0.;
}

// Phong shading with shadows and ambient occlusion, no reflection
// p : Point
// n : Normal at point
// eye : Eye ray
// mat : Material at point
vec3 ShadeSimple(vec3 p, vec3 n, Ray eye, Material mat)
{
    vec3 l = LightDirection(p);
    vec3 v = normalize(-eye.d);
    vec3 r = reflect(-l, n);

    float shadow = Shadow(p, n, l);

    float diff = max(dot(n, l), 0.0);
    float spec = pow(max(dot(r, v), 0.0), mat.shininess);

    vec3 ambient = mat.ka * background(Ray(p, n));
    vec3 diffuse = mat.kd * diff * mat.color;
    vec3 specular = mat.ks * spec * vec3(1.0);

    float ao = AmbientOcclusion(p, n);

    return ambient + ao * shadow * (diffuse + specular);
}

// Full shading: Phong + shadows + ambient occlusion + one reflection bounce
vec3 Shade(vec3 p, vec3 n, Ray eye, Material mat)
{
    vec3 color = ShadeSimple(p, n, eye, mat);

    if (mat.reflectivity > 0.0)
    {
        vec3 rdir = reflect(eye.d, n);
        Ray rray = Ray(p + Epsilon * n, rdir);
        float rt;
        int rs, rc;
        bool rhit = SphereTrace(rray, 100.0, rt, rs, rc);

        if (rhit)
        {
            vec3 rp = Point(rray, rt);
            vec3 rn = ObjectNormal(rp);
            Val rval = object(rp);
            vec3 reflectedColor = ShadeSimple(rp, rn, rray, rval.mat);
            color = mix(color, reflectedColor, mat.reflectivity);
        }
    }

    return color;
}

// False colors for a count (steps or cost)
// n : value
// m : normalization
vec3 ShadeSteps(int n, int m)
{
    float t = float(n) / float(m);
    return .5 + mix(vec3(.05, .05, .5), vec3(.65, .39, .65), t);
}

// Image
void mainImage(out vec4 color, in vec2 pxy)
{
    // Convert pixel coordinates
    vec2 pixel = (-iResolution.xy + 2. * pxy) / iResolution.y;

    // Mouse
    vec2 m = iMouse.xy / iResolution.xy;

    // Camera
    Ray ray = CreateRay(m, pixel);

    // Trace ray
    float t = 0.0;
    int s = 0;
    int c;
    bool hit = SphereTrace(ray, 100., t, s, c);

    vec3 rgb = background(ray);
    if (hit)
    {
        vec3 p = Point(ray, t);
        vec3 n = ObjectNormal(p);
        Val val = object(p);
        rgb = Shade(p, n, ray, val.mat);
    }

#if VIEW == 1
    rgb = ShadeSteps(s, Steps);
#elif VIEW == 2
    rgb = ShadeSteps(c, 500);
#endif

    color = vec4(rgb, 1.);
}
