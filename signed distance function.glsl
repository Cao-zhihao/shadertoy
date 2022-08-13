vec2 fixuv(in vec2 c)
{
    return 2.*(2.*c - iResolution.xy) / min(iResolution.x,iResolution.y);
}

float sdfRect(in vec2 p,vec2 b)
{
    vec2 d = abs(p) - b;
    return length(max(d,0.))+min(max(d.x,d.y),0.);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fixuv(fragCoord);
    float d = sdfRect(uv,vec2(.5+.2*cos(iTime),.5+.2*sin(iTime)));
    vec3 col = 1. - sign(d) * vec3(.4,.5,.6); 
    col *= 1. - exp(-3.*abs(d));
    col *=.8 + .2 * sin(150. *abs(d)); 
    fragColor = vec4(col,1.);
}