#define Tmin 0.1
#define Tmax 150.
#define RAYmarch_time 128
#define precision .001
#define AA 6
#define PI 3.1415926

vec2 fixuv(in vec2 c)
{
    return (2.*c - iResolution.xy) / min(iResolution.x,iResolution.y);
}

float sdfSphere(in vec3 p)
{
    return length(p) - 1.;
}

float sdfPlane(in vec3 p)
{
    return p.y;
}

vec2 opU(vec2 a,vec2 b)
{
    return a.x < b.x ? a : b;
}

vec2 map(in vec3 p)
{
    vec2 d = vec2(sdfSphere(p),2.);
    d = opU(d, vec2(sdfPlane(p + vec3(0.,1.,0.)),1.));
    return d;
} 

vec2 rayMarch(in vec3 ro,in vec3 rd)
{
    float t=Tmin;
    vec2 res = vec2(-1.);
    for(int i=0;i<RAYmarch_time&&t<Tmax;i++)
    {
        vec3 p = ro + t*rd;
        vec2 d = map(p);
        if(d.x<precision)
        {   
            res = vec2(t,d.y);
            break;
        }
        t += d.x;
    }
    return res;
}


vec3 calcNormal(in vec3 p)
{
    const float h = 0.0001; 
    const vec2 k = vec2(1.,-1.);
    return normalize(k.xyy*map(p+ k.xyy*h).x+
                     k.yyx*map(p+ k.yyx*h).x+
                     k.yxy*map(p+ k.yxy*h).x+
                     k.xxx*map(p+ k.xxx*h).x);
}

mat3 setCamera(in vec3 ta,vec3 ro,float cr)
{
    vec3 z = normalize(ta - ro);
    vec3 cp = vec3(sin(cr),cos(cr),0.);
    vec3 x = normalize(cross(z, cp));
    vec3 y = cross(x,z);
    return mat3(x,y,z);
}

//软阴影法1
// float softshadow(in vec3 ro,in vec3 rd,float k)
// {
//     float res = 1.;
//     for(float t = Tmin;t < Tmax;)
//     {
//         float h = map(ro + rd*t);
//         if(h < 0.001)
//         {
//             return 0.;
//         }
//         res = min(res,k * h / t);
//         t += h;
//     }
//     return res;
// }

//软阴影法2,比第一种强在哪里呢？
float softshadow( in vec3 ro, in vec3 rd, float mint, float maxt, float k )
{
    float res = 1.0;
    float ph = 1e20;
    for( float t=mint; t<maxt; )
    {
        float h = map(ro + rd*t).x;
        if( h<0.001 )
            return 0.0;
        float y = h*h/(2.0*ph);
        float d = sqrt(h*h-y*y);
        res = min( res, k*d/max(0.0,t-y) );
        ph = h;
        t += h;
    }
    return res;
}

vec3 render(vec2 uv)
{   
    vec3 col = vec3(0.);
    vec3 ro = vec3(4.*cos(iTime),2.,4.*sin(iTime));
    vec3 ta = vec3(0.);
    mat3 cam = setCamera(ta,ro,0.);
    vec3 rd = normalize(cam*vec3(uv,1.));
    vec2 t = rayMarch(ro,rd);
    if(t.y > 0.)
    {
        vec3 p = ro + rd * t.x;
        vec3 n = calcNormal(p);
        vec3 light = vec3(2.,3.,0.);
        float dif = clamp(dot(normalize(light - p),n),0.,1.);
        p += precision*n;//这一步意义？
        float st = softshadow(p,normalize(light - p),Tmin,Tmax,5.);
        dif *= st;
        float amb = 0.5 + 0.5*dot(n,vec3(0.,1.,0.));
        vec3 c = vec3(0.);
        if(t.y > 1.9&&t.y <2.1)
        {
            c = vec3(1.,0.,0.);
        }
        else if(t.y > 0.9&&t.y < 1.1)
        {
            c = vec3(.23);
        }
        col = amb* c+ dif * (vec3(.7));
    }
    return sqrt(col);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec3 col = vec3(0.);
    vec2 uv = fixuv(fragCoord);
    for(int m=0; m<AA; m++)
    {
        for(int n=0; n<AA; n++)
        {
            vec2 offset = 2.*(vec2(float(m),float(n))/float(AA) - 0.5);
            vec2 uv = fixuv(fragCoord + offset);
            col += render(uv);
        }
    }
    fragColor = vec4(col / float(AA*AA), 1.);
}