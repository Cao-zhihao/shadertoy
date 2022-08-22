#define RAYmarch_time 128
#define precision .001
#define AA 4
#define PI 3.1415926

vec2 fixuv(in vec2 c)
{
    return (c.xy / iResolution.xy - .5);
}

float sdfPlane(vec3 p){
    return p.y + .5;
}

vec4 opElongate( in vec3 p, in vec3 h )
{
    //return vec4( p-clamp(p,-h,h), 0.0 ); // faster, but produces zero in the interior elongated box
    vec3 q = abs(p)-h;
    return vec4( max(q,0.0), min(max(q.x,max(q.y,q.z)),0.0) );
}

float sdTorus( vec3 p, vec2 t )
{
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}

float sdfSphere(in vec3 p)
{
    return length(p) - 1.;
}

float sdfBox(in vec3 p,in vec3 r,in float rad)
{
    vec3 b = abs(p) - r;
    return length(max(b,0.)) + min(max(max(b.x,b.y),b.z),0.) - rad;
}

float sdBox1( vec3 p, vec3 b )
{
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

vec2 opU(vec2 a,vec2 b)
{
    return a.x < b.x ? a : b;
}

vec2 map(in vec3 p)
{
    //vec2 d = vec2(sdfSphere(p - vec3(0.,1.,0.)),2.);
    vec3 q = p - vec3(0.,1.1,1.8);
    vec4 w = opElongate( q, vec3(0.1,0.,0.) );
    vec2 d = vec2(sdfBox(p - vec3(0.,0.,0.),vec3(.5,1.5,1.3),.5),3.); 
    d = opU (d, vec2(w.w+sdTorus( w.xzy, vec2(0.01,0.01) ),4.));
    d = opU (d, vec2(sdBox1( p - vec3(.3,1.,-1.9), vec3(.04,.2,1.)),5.));
    d = opU (d, vec2(sdBox1( p - vec3(-.3,1.,-1.9), vec3(.04,.2,1.)),6.));
    d = opU (d, vec2(sdfPlane(p),7.));
    return d;
} 

// vec2 rayMarch(in vec3 ro,in vec3 rd)
// {
//     float t=.1;
//     float tmax = 40.;
//     vec2 res = vec2(-1.);
//     if(rd.y < 0.)
//     {
//         float tp = -ro.y/rd.y;
//         tmax = min(tmax,tp);
//         res = vec2(tp,1.);//这里为什么能变成直线平面？
//     }
//     for(int i=0;i<RAYmarch_time&&t<tmax;i++)
//     {
//         vec3 p = ro + t*rd;
//         vec2 d = map(p);
//         if(d.x<precision)
//         {   
//             res = vec2(t,d.y);
//             break;
//         }
//         t += d.x;
//     }
//     return res;
// }

vec2 rayMatch(vec3 ro,vec3 rd){
    float t = .1;
    vec2 d = vec2(-1.);
    for(int i = 0;i < 255;i++){
        vec3 p = ro + rd * t;
        vec2 sd = map(p);
        t = t + sd.x;
        if(sd.x < 0.001 || t > 40.0){
            d = vec2(t,sd.y);
            break;
        }
    }
    return d;
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
    vec3 x = normalize(cross(cp, z));
    vec3 y = cross(z,x);
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
float softshadow( in vec3 ro, in vec3 rd, float k )
{
    float res = 1.0;
    float ph = 1e20;
    float mint = .1;
    float maxt = 100.;
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

//棋盘优化抗锯齿，去摩尔纹！思想是想办法让边缘线性平滑过渡https://iquilezles.org/articles/checkerfiltering/
vec2 tri( in vec2 x )
{
    vec2 h = fract(x*.5)-.5;
    return 1.-2.*abs(h);
}

// square (x) and triangular (y) signals
float checkersGrad( in vec2 uv, in vec2 ddx, in vec2 ddy )
{
    vec2 w = max(abs(ddx), abs(ddy)) + 0.01;    // filter kernel
    vec2 i = (tri(uv+0.5*w) - tri(uv-0.5*w))/w;   // analytical integral (box filter)
    return 0.5 - 0.5*i.x*i.y;                   // xor pattern
}


float disney_a(float f90,float k){
    return 1. + (f90 - 1.) * pow(1. - k,5.);
}

float disney_f90(float rough,float HdotL){
    return 0.5 + 2. * rough * HdotL * HdotL;
}

vec3 disney_diffuse(vec3 color,float rough,float HdotL,float NdotL,float NdotV){
    float f90 = disney_f90(rough,HdotL);
    return color / 3.14 * disney_a(f90,NdotL) * disney_a(f90,NdotV);
}

float ggx(float rough,float NdotH){
    float rr = rough * rough;
    float num = max(3.14 * pow(NdotH * NdotH * (rr - 1.) + 1.,2.),0.001);
    return rr / num;
}

float smith_ggx(float k,float d){
    return d / (d * (1. - k) + k);
}

float smith(float rough,float NdotV,float NdotL){
    float a = pow((rough + 1.) / 2.,2.);
    float k = a / 2.;
    return smith_ggx(k,NdotV) * smith_ggx(k,NdotL);
}

vec3 fresnel(vec3 f0,float HdotV){
    return f0 + (1. - f0) * pow(1. - HdotV,5.);
}

vec3 g_specular(vec3 baseColor,float rough,float NdotH,float NdotV,float NdotL,float HdotV){
    return ggx(rough,NdotH) * smith(rough,NdotV,NdotL) * fresnel(baseColor,HdotV) / (4. * NdotL * NdotV);
}

vec3 calLightColor(vec3 rd,vec3 p,vec3 n,vec3 lp,vec3 lc){
        vec3 sp = p + n * 0.002;
        vec3 col = vec3(0.);
        vec3 l = normalize(lp - p);
        vec3 v = normalize(-rd);
        vec3 h = normalize(l + v);
        
        float NdotL = clamp(dot(n,l),0.,1.);
        float HdotL = clamp(dot(h,l),0.,1.);
        float NdotV = clamp(dot(n,v),0.,1.);
        float NdotH = clamp(dot(n,h),0.,1.);
        float HdotV = clamp(dot(h,v),0.,1.);
        vec3 baseColor;
        if(map(p).y > 2.9&&map(p).y < 3.1){
            baseColor = vec3(0.223, 0.77, 0.73);
        }
        else if(map(p).y > 3.9&&map(p).y <4.1){
            baseColor = vec3(1);
        }
        float rough = 0.2;
        float shadow = softshadow(sp,l,5.);
        vec3 diffuse = disney_diffuse(baseColor,rough,HdotL,NdotL,NdotV);
        vec3 specular = g_specular(baseColor,rough,NdotH,NdotV,NdotL,HdotV);
        vec3 k = shadow * clamp(diffuse + specular,0.,1.) * NdotL * 3.14;
        col += lc * k;
        return col;
}

vec3 rayMatchColor(in vec3 ro,in vec3 rd,out vec3 p,out vec3 n){
    vec3 col = vec3(0.5 + 0.5*cos(iTime+vec3(0,2,4)));
    vec2 d = rayMatch(ro,rd);
    if(d.x <= 40.0){
        col = vec3(0.);
        p = ro + rd * d.x;
        n = calcNormal(p);
        vec3 lp = vec3(0.,5.,-8.);
        vec3 lc = vec3(0.7);
        col += calLightColor(rd,p,n,lp,lc);
        vec3 lp2 = vec3(0.,2.,4.);
        vec3 lc2 = vec3(0.3);
        col += calLightColor(rd,p,n,lp2,lc2);
    }
    return col;
}




void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fixuv(fragCoord);
    uv.x = uv.x * iResolution.x / iResolution.y;
    vec3 col = vec3(0.);
    for(int m=0; m<AA; m++)
    {
        for(int o=0; o<AA; o++)
        {
            vec2 offset = 2.*(vec2(float(m),float(o))/float(AA) - 0.5);
            vec2 uv = fixuv(fragCoord + offset);
            uv.x = uv.x * iResolution.x / iResolution.y;
            vec2 px = fixuv(fragCoord + vec2(1.,0.) + offset);
            px.x = px.x * iResolution.x / iResolution.y;
            vec2 py = fixuv(fragCoord + vec2(0.,1.) + offset);
            py.x = py.x * iResolution.x / iResolution.y;//去摩尔纹的关键在这两步
            float t = iTime * 0.2;
            vec3 ro = vec3(8. * cos(t),3.0,8. * sin(t));
            if (iMouse.z > 0.01)
            {
                float theta = iMouse.x / iResolution.x*2.*3.14;
                ro = vec3(8.*sin(theta),3.0,8.*cos(theta));
            }
            vec3 rd = setCamera(vec3(0.,0.,0.),ro,0.) * vec3(uv,1.);
            vec3 p;
            vec3 n;
            col += rayMatchColor(ro,rd,p,n);
            if(map(p).y > 4.9&&map(p).y <6.1){
                vec3 rro = p + n * 0.002;
                vec3 rrd = normalize(reflect(normalize(rd),n));
                vec3 pp;
                vec3 nn;
                vec3 rColor = rayMatchColor(rro,rrd,pp,nn) * 0.618;
                col += rColor;
            }
            vec3 ta =vec3(0.);
            mat3 cam = setCamera(ta,ro,0.);
            if(map(p).y > 6.9&&map(p).y <7.1){
            vec3 rdx = normalize(cam*vec3(px,1.));
            vec3 rdy = normalize(cam*vec3(py,1.));
            vec3 ddx = ro.y *  (rd/rd.y - rdx/rdx.y);
            vec3 ddy = ro.y * (rd/rd.y - rdy/rdy.y);
            vec3 c = vec3(.01) + vec3(.5)*checkersGrad(p.xz,ddx.xz,ddy.xz);
            col += c;
            }
        }
    }
    fragColor = vec4(col / float(AA*AA), 1.);
}