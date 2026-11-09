#include <metal_stdlib>
using namespace metal;
struct Uniforms {
    float4 viewport; // width, height, aspect, scale
    float4 camera; // center x, center z, opacity, fabric
    float4 style; // glow, grid, time, unused
    float4 bodies[3];
};
constant float3 palette[3] = {float3(.20,.72,1.0), float3(1.0,.25,.43), float3(1.0,.65,.25)};
struct Out { float4 position [[position]]; float2 uv; float3 color; float alpha; float2 world; };
float2 project(float3 p, constant Uniforms &u) {
    p.x -= u.camera.x; p.z -= u.camera.y;
    float perspective = 1.0 / max(.5, 1.0 - p.z*.12 - p.y*.03);
    float tilt = u.camera.w > .5 ? .58 : .86;
    return float2(p.x/u.viewport.z, p.y*.84-p.z*tilt)* (1.48/u.viewport.w)*perspective + float2(0,u.camera.w > .5 ? -.14 : -.40);
}
vertex Out fullscreen(uint id [[vertex_id]]) {
    float2 p = float2((id<<1)&2, id&2);
    Out o; o.position=float4(p*2-1,0,1); o.uv=float2(p.x,1-p.y); return o;
}
fragment float4 background(Out in [[stage_in]]) {
    float2 p = in.uv-.5;
    float v = exp(-dot(p*float2(1,1.2),p*float2(1,1.2))*3.5);
    return float4(float3(.0008,.0014,.004)+float3(.001,.0017,.004)*v,1);
}
vertex Out gridVertex(uint id [[vertex_id]], constant Uniforms &u [[buffer(0)]]) {
    const uint n = 256;
    uint cell = id/6, corner = id%6;
    constexpr uint2 offsets[6] = {uint2(0,0),uint2(1,0),uint2(0,1),uint2(1,0),uint2(1,1),uint2(0,1)};
    float2 w = (float2(uint2(cell%n,cell/n)+offsets[corner])/float(n)-.5) * u.viewport.w*4.8;
    float potential=0; float3 tint=0; float total=0;
    for(uint j=0;j<3;j++) {
        float r2=dot(w-u.bodies[j].xy,w-u.bodies[j].xy);
        potential += .18*u.bodies[j].z*rsqrt(r2+.04);
        float weight=exp(-r2*.5); tint += palette[j]*weight; total+=weight;
    }
    float height=-.30-1.3*(1-exp(-potential*.85));
    Out o; o.position=float4(project(float3(w.x,height,w.y),u),.5,1);
    o.world=w; o.color=float3(.12,.18,.34)+tint*.14; o.uv=0; o.alpha=height; return o;
}
fragment float4 gridFragment(Out in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float2 coord=in.world / .16;
    float2 deriv=max(fwidth(coord),float2(.0001));
    float2 dist=abs(fract(coord-.5)-.5)/deriv;
    float line=1-smoothstep(.3,1.15,min(dist.x,dist.y));
    float alias=1-smoothstep(.45,1.5,max(deriv.x,deriv.y));
    float fade=exp(-dot(in.world,in.world)/(u.viewport.w*u.viewport.w*1.8));
    float edge=1-smoothstep(.65,1.05,abs(in.position.x/u.viewport.x*2-1));
    float horizon=smoothstep(-3.2,-.6,in.world.y);
    float intensity=line*alias*fade*edge*horizon*u.style.y*u.camera.z*.045;
    return float4(in.color*intensity,1);
}
struct TrailVertex { float4 point; float4 tangent; float4 color; };
vertex Out trailVertex(uint id [[vertex_id]], const device TrailVertex *v [[buffer(1)]], constant Uniforms &u [[buffer(0)]]) {
    TrailVertex a=v[id];
    float2 p=project(float3(a.point.x,.42,a.point.y),u);
    float2 q=project(float3(a.tangent.x,.42,a.tangent.y),u);
    float2 d=(q-p)*u.viewport.xy;
    float2 normal=length(d)>1e-5 ? normalize(float2(-d.y,d.x)) : float2(0,1);
    float width=mix(.35,1.45,sqrt(a.point.w))*max(.65,u.viewport.y/1080.0);
    Out o; o.position=float4(p+normal*a.point.z*width*2/u.viewport.xy,0,1);
    o.uv=float2(a.point.z,0); o.color=a.color.xyz; o.alpha=a.point.w; return o;
}
fragment float4 trailFragment(Out in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float aa=1-smoothstep(.2,1,abs(in.uv.x));
    return float4(in.color*aa*pow(in.alpha,1.6)*u.camera.z*1.5,1);
}
vertex Out starVertex(uint id [[vertex_id]], uint instance [[instance_id]], constant Uniforms &u [[buffer(0)]]) {
    constexpr float2 corners[6]={float2(-1,-1),float2(1,-1),float2(-1,1),float2(1,-1),float2(1,1),float2(-1,1)};
    float2 uv=corners[id];
    float2 p=project(float3(u.bodies[instance].x,.42,u.bodies[instance].y),u);
    float size=90*max(.45,u.viewport.y/1080.0);
    Out o; o.position=float4(p+uv*size*2/u.viewport.xy,0,1); o.uv=uv; o.color=palette[instance]; o.alpha=float(instance); return o;
}
fragment float4 starFragment(Out in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float r=length(in.uv);
    float core=exp(-r*r/0.0012);
    float corona=exp(-r*37)*1.3;
    float halo=exp(-r*7.5)*.08*(1-smoothstep(.7,1.,r));
    float rays=exp(-abs(in.uv.x)*230)*exp(-abs(in.uv.y)*26)+exp(-abs(in.uv.y)*230)*exp(-abs(in.uv.x)*26);
    float3 col=mix(in.color,float3(1),.5)*core*4.8 + in.color*(corona+halo+rays*.055)*u.style.x;
    return float4(col*u.camera.z,1);
}
fragment float4 bloomHorizontal(Out in [[stage_in]], texture2d<float> source [[texture(0)]]) {
    constexpr sampler s(filter::linear,address::clamp_to_edge);
    float3 c=0; float weight=0;
    for(int i=-8;i<=8;i++) {
        float w=exp(-float(i*i)/22.0); float3 v=source.sample(s,in.uv+float2(float(i)*2/source.get_width(),0)).rgb;
        c+=max(v-.8,0.0)*w; weight+=w;
    }
    return float4(c/weight,1);
}
fragment float4 bloomVertical(Out in [[stage_in]], texture2d<float> source [[texture(0)]]) {
    constexpr sampler s(filter::linear,address::clamp_to_edge);
    float3 c=0; float weight=0;
    for(int i=-8;i<=8;i++) { float w=exp(-float(i*i)/22.0); c+=source.sample(s,in.uv+float2(0,float(i)/source.get_height())).rgb*w; weight+=w; }
    return float4(c/weight,1);
}
fragment float4 composite(Out in [[stage_in]], texture2d<float> scene [[texture(0)]], texture2d<float> bloom [[texture(1)]], constant Uniforms &u [[buffer(0)]]) {
    constexpr sampler s(filter::linear,address::clamp_to_edge);
    float3 c=scene.sample(s,in.uv).rgb+bloom.sample(s,in.uv).rgb*.5*u.style.x;
    c=c/(1+c); // preserve chroma in SDR, sRGB attachment performs encoding
    float noise=fract(sin(dot(in.position.xy,float2(12.9898,78.233)))*43758.5453)-.5;
    c+=noise/3500.;
    return float4(max(c,0.),1);
}
