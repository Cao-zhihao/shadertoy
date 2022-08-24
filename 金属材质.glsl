float sdfPlane(vec3 p){
    return p.y + 0.5;
}

float sdfCircle(vec3 p){
    return length(p - vec3(0.,.5,0.)) - 1.2;
}

float sdfRect(vec3 p){
    vec3 b = vec3(1.,1.,1.);
    vec3 q = abs(p - vec3(0.,0.5,0.)) - b;
    return length(max(q,0.)) + min(max(q.x,max(q.y,q.z)),0.);
}

float sdfCombo(vec3 p){
    return min(sdfRect(p),sdfCircle(p));
}

float map(vec3 p){
    return min(sdfPlane(p),sdfCombo(p));
}

float rayMatch(vec3 ro,vec3 rd){
    float d = 0.;
    for(int i = 0;i < 255;i++){
        vec3 p = ro + rd * d;
        float sd = map(p);
        d = d + sd;
        if(sd < 0.001 || d > 40.0){
            break;
        }
    }
    return d;
}

float shadow(vec3 ro,vec3 rd){
    float hit = 1.;
    float t = 0.02;
    
    for(int i = 0;i < 255;i++){
        vec3 p = ro + rd * t;
        float h = map(p);
        if(h < 0.001){
            return 0.;
        }
        t += h;
        hit = min(hit, 10. * h / t);
        if(t >= 10.0){
            break;
        }
    }
    return clamp(hit,0.,1.);
}

mat3 cameraToWorld(vec3 ro,vec3 lookAt){
    vec3 a = normalize(lookAt - ro);
    vec3 b = cross(vec3(0.,1.,0),a);
    vec3 c = cross(a,b);
    return mat3(b,c,a);
}

//法向量法1，这种法向量更好理解
// vec3 normal(vec3 p){
//     float d = map(p);
//     vec2 dd = vec2(0.001,0.);
//     float dx = d - map(p - dd.xyy);
//     float dy = d - map(p - dd.yxy);
//     float dz = d - map(p - dd.yyx);
//     return normalize(vec3(dx,dy,dz));
// }

//法向量法2，这种法向量更加高级？
vec3 normal(in vec3 p)
{
    const float h = 0.0001; 
    const vec2 k = vec2(1.,-1.);
    return normalize(k.xyy*map(p+ k.xyy*h)+
                     k.yyx*map(p+ k.yyx*h)+
                     k.yxy*map(p+ k.yxy*h)+
                     k.xxx*map(p+ k.xxx*h));
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
        if(sdfPlane(p) < 0.001){
            float k = mod(floor(p.x * 2.) + floor(p.z * 2.),2.);
            baseColor = 0.4 + k * vec3(0.6);
        }else{
            baseColor = vec3(0.76, 0.8, 0.8);
        }
        float rough = 0.2;
        
        float shadow = shadow(sp,l);
        vec3 diffuse = disney_diffuse(baseColor,rough,HdotL,NdotL,NdotV);
        vec3 specular = g_specular(baseColor,rough,NdotH,NdotV,NdotL,HdotV);
        vec3 k = shadow * clamp(diffuse + specular,0.,1.) * NdotL * 3.14;
        col += lc * k;
        return col;
}

vec3 rayMatchColor(in vec3 ro,in vec3 rd,out bool hit,out vec3 p,out vec3 n){
    vec3 col = vec3(0.);
    float d = rayMatch(ro,rd);
    if(d <= 40.0){
        p = ro + rd * d;
        n = normal(p);
        vec3 lp = vec3(0.,5.,-8.);
        vec3 lc = vec3(0.7);
        col += calLightColor(rd,p,n,lp,lc);
        vec3 lp2 = vec3(0.,2.,4.);
        vec3 lc2 = vec3(0.3);
        col += calLightColor(rd,p,n,lp2,lc2);
        hit = true;
    }else{
        hit = false;
    }
    return col;
}


void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy - 0.5;
    uv.x = uv.x * iResolution.x / iResolution.y;
    float t = iTime * 0.2;
    vec3 ro = vec3(5. * cos(t),3.0,5. * sin(t));
    if (iMouse.z > 0.01)
    {
        float theta = iMouse.x / iResolution.x*2.*3.14;
        ro = vec3(5.*sin(theta),3.,5.*cos(theta));
    }
    vec3 rd = cameraToWorld(ro,vec3(0.,0.,0.)) * vec3(uv,1.);
    vec3 col = vec3(0.);
    bool hit;
    vec3 p;
    vec3 n;
    col += rayMatchColor(ro,rd,hit,p,n);
    if(hit && sdfCombo(p) < 0.001){
        vec3 rro = p + n * 0.002;
        vec3 rrd = normalize(reflect(normalize(rd),n));
        vec3 pp;
        vec3 nn;
        vec3 rColor = rayMatchColor(rro,rrd,hit,pp,nn) * 0.618;
        col += rColor;
    }
    fragColor = vec4(col,1.);
}