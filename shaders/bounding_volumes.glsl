// SDF raymarching renderer - bounding volume experiment
// Tanguy Vallot
//
// Shows the per-pixel cost of evaluating the distance field, with and
// without a bounding box around an expensive object.
// Paste this file into a new shader on shadertoy.com.

// 0 = object evaluated everywhere, 1 = object wrapped in a bounding box
#define USE_BOUNDING_VOLUME 1

// Normalization of the cost heatmap (lower = more contrast)
#define COST_SCALE 1000

// Extra cost added to the object to simulate an expensive SDF
// (noise, many CSG nodes...)
const int ObjectExtraCost = 100;

struct Ray {
    vec3 o; // Origin
    vec3 d; // Direction
};

struct Val {
    float v; // Signed distance
    int c;   // Evaluation cost
};

// Compute point on ray
vec3 Point(Ray ray, float t)
{
    return ray.o + t * ray.d;
}

// Camera -------------------------------------------------------------------------------

// Rotation matrix around z axis
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
    float le = 3.5;

    vec3 ro = vec3(37., 0., 15.);
    ro *= Rz(a);

    vec3 ta = vec3(0., 0., 1.);

    vec3 w = normalize(ta - ro);
    vec3 u = normalize(cross(w, vec3(0., 0., 1.)));
    vec3 v = normalize(cross(u, w));
    vec3 rd = normalize(p.x * u + p.y * v + le * w);
    return Ray(ro, rd);
}

// Primitives -------------------------------------------------------------------------------

Val Sphere(vec3 p, vec3 c, float r)
{
    return Val(length(p - c) - r, 1);
}

// Box with half-size s
Val Box(vec3 p, vec3 c, vec3 s)
{
    vec3 d = abs(p - c) - s;
    float outside = length(max(d, 0.0));
    float inside = min(max(d.x, max(d.y, d.z)), 0.0);
    return Val(outside + inside, 1);
}

// Torus with main radius r and tube radius t
Val Torus(vec3 p, vec3 c, float r, float t)
{
    vec3 q = p - c;
    vec2 k = vec2(length(q.xz) - r, q.y);
    return Val(length(k) - t, 1);
}

Val Union(Val a, Val b)
{
    Val res;
    if (a.v < b.v) res = a;
    else res = b;
    res.c = a.c + b.c + 1;
    return res;
}

// Scene ----------------------------------------------------------------------------

// The "expensive" object: a torus and a sphere
Val ExpensiveObject(vec3 p)
{
    Val a = Torus(p, vec3(0.), 3.0, 1.0);
    Val b = Sphere(p, vec3(0., 0., 1.5), 2.0);
    Val res = Union(a, b);
    res.c += ObjectExtraCost;
    return res;
}

// Same object, only evaluated inside its bounding box.
// Outside, the distance to the box is a valid lower bound of the
// distance to the object, so sphere tracing stays correct.
Val BoundedObject(vec3 p)
{
    Val bound = Box(p, vec3(0.), vec3(5.0));
    if (bound.v < 0.0)
    {
        Val res = ExpensiveObject(p);
        res.c += bound.c;
        return res;
    }
    return bound;
}

Val object(vec3 p)
{
#if USE_BOUNDING_VOLUME == 1
    return BoundedObject(p);
#else
    return ExpensiveObject(p);
#endif
}

// Sphere tracing -----------------------------------------------------------------------

const int Steps = 200;
const float Epsilon = .01;

// Trace ray, accumulating the evaluation cost in c
bool SphereTrace(Ray ray, float e, out float t, out int s, out int c)
{
    bool h = false;
    t = 0.0;
    c = 0;

    for (int i = 0; i < Steps; i++)
    {
        s = i;
        Val val = object(Point(ray, t));
        c += val.c;
        if (val.v < 0.)
        {
            h = true;
            break;
        }
        t += max(Epsilon, val.v);
        if (t > e)
        {
            break;
        }
    }
    return h;
}

// False colors for a cost value
vec3 ShadeSteps(int n, int m)
{
    float t = float(n) / float(m);
    return .5 + mix(vec3(.05, .05, .5), vec3(.65, .39, .65), t);
}

void mainImage(out vec4 color, in vec2 pxy)
{
    vec2 pixel = (-iResolution.xy + 2. * pxy) / iResolution.y;
    vec2 m = iMouse.xy / iResolution.xy;
    Ray ray = CreateRay(m, pixel);

    float t;
    int s, c;
    SphereTrace(ray, 100., t, s, c);

    color = vec4(ShadeSteps(c, COST_SCALE), 1.);
}
