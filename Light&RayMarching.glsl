#define Tmin 0.1
#define Tmax 20.
#define RAYmarch_time 128
#define precision .001
#define ric 1.5
#define AA 4

vec2 fixuv(in vec2 c)
{
    return (2.*c - iResolution.xy) / min(iResolution.x,iResolution.y);
}

float sdfSphere(in vec3 p,vec3 b)
{
    vec3 d = abs(p) - b;
    return length(max(d,0.)) + min(max(d.x,max(d.y,d.z)),0.);
}

float rayMarch(in vec3 ro,in vec3 rd)
{
    float t=Tmin;
    for(int i=0;i<RAYmarch_time&&t<Tmax;i++)
    {
        vec3 p = ro + t*rd;
        float d = sdfSphere(p,vec3(.5));
        if(d<precision)
        {
            break;
        }
        t += d;
    }
    return t;
}


vec3 calcNormal(in vec3 p)
{
    const float h = 0.0001;
    const vec2 k = vec2(1.,-1.);
    return normalize(k.xyy*sdfSphere(p+ k.xyy*h,vec3(.5))+
                     k.yyx*sdfSphere(p+ k.yyx*h,vec3(.5))+
                     k.yxy*sdfSphere(p+ k.yxy*h,vec3(.5))+
                     k.xxx*sdfSphere(p+ k.xxx*h,vec3(.5)));
}

mat3 setCamera(in vec3 ta,vec3 ro,float cr)
{
    vec3 z = normalize(ta - ro);
    vec3 cp = vec3(sin(cr),cos(cr),0.);
    vec3 x = normalize(cross(z, cp));
    vec3 y = cross(x,z);
    return mat3(x,y,z);
}

vec3 render(vec2 uv)
{   
    vec3 col = vec3(0.);
    vec3 ro = vec3(2.*cos(iTime),1.,2.*sin(iTime));
    vec3 ta = vec3(0.);
    mat3 cam = setCamera(ta,ro,0.);
    vec3 rd = normalize(cam*vec3(uv,2.));
    float t = rayMarch(ro,rd);
    if(t<Tmax)
    {
        vec3 p = ro + rd * t;
        vec3 n = calcNormal(p);
        vec3 light = vec3(1.);
        float dif = clamp(dot(normalize(light - p),n),0.,1.);
        float amb = 0.5 + 0.5*dot(n,vec3(0.,1.,0.));
        col = amb* vec3(0.6)+ dif * (0.5 + 0.5*cos(iTime+uv.xyx+vec3(0,2,4)));
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