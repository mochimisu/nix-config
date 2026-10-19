#version 320 es
// @duration @duration@
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
uniform float progress;
uniform float seed;
uniform vec4 window_rect;
uniform vec2 resolution;
out vec4 fragColor;
const bool closing = @closing@;
const vec3 ink = @sekaiInk@;
const vec3 teal = @sekaiTeal@;
const vec3 mint = @sekaiMint@;
const vec3 lavender = @sekaiLavender@;
const vec3 pink = @sekaiPink@;
const vec3 pearl = @sekaiSurface@;
float hash(float n) { return fract(sin(n * 127.1 + seed * 19.19) * 43758.5453); }
// Shared jittered vertices make irregular triangles that still tile exactly.
vec2 vertex(vec2 p, vec2 grid) {
    float key=p.x*17.0+p.y*83.0;
    vec2 jitter=vec2(hash(key+211.0),hash(key+379.0))-0.5;
    if(p.x==0.0 || p.x==grid.x) jitter.x=0.0;
    if(p.y==0.0 || p.y==grid.y) jitter.y=0.0;
    return (p+jitter*0.56)/grid;
}
float edgeDistance(vec2 a,vec2 b,vec2 p) {
    vec2 e=b-a;return -(e.x*(p.y-a.y)-e.y*(p.x-a.x))/length(e);
}
void main() {
    float t=clamp(progress,0.0,1.0);
    vec4 original=texture(tex,v_texcoord);
    if(any(lessThan(textureSize(tex,0),ivec2(2)))) {fragColor=vec4(0.0);return;}
    if(t<=0.001) {fragColor=closing?original:vec4(0.0);return;}
    if(t>=(closing?1.0:0.99)) {fragColor=closing?vec4(0.0):original;return;}
    vec2 extent=max(window_rect.zw,vec2(0.00001));
    vec2 uv=(v_texcoord-window_rect.xy)/extent;
    vec2 size=vec2(textureSize(tex,0))*extent;
    vec2 grid=size.x>=size.y?vec2(5.0,4.0):vec2(4.0,5.0);
    vec2 pixel=uv*size;
    // Blackmoon DP-1 is the 2560x1440 panel configured at transform 1;
    // DP-3 is the unrotated 3440x1440 panel. Close snapshots and fragment
    // derivatives are panel-oriented, before the final display transform.
    // The plugin exposes panel resolution but no monitor-transform uniform.
    // Keep this host-specific mapping aligned with its monitor configuration.
    bool portraitPanel=closing && all(lessThan(abs(resolution-vec2(2560.0,1440.0)),vec2(0.5)));
    vec2 screenRight=portraitPanel?vec2(0.0,-1.0):vec2(1.0,0.0);
    vec2 screenDown=portraitPanel?vec2(1.0,0.0):vec2(0.0,1.0);
    if(closing && (any(lessThan(uv,vec2(0.0))) || any(greaterThan(uv,vec2(1.0))))) {fragColor=vec4(0.0);return;}
    float lastLanding=0.0;
    vec2 rippleOrigin=size*0.5;
    if(!closing) for(int k=0;k<40;++k) {
        float key=float(k),cell=floor(key*0.5);
        if(hash(cell+601.0)<0.25 && mod(key,2.0)>0.5) continue;
        float landing=hash(key+37.0)*0.14+mix(0.49,0.73,hash(key+71.0));
        if(landing>lastLanding) {
            lastLanding=landing;
            rippleOrigin=(vec2(mod(cell,grid.x),floor(cell/grid.x))+0.5)/grid*size;
        }
    }
    vec4 result=vec4(0.0);
    float totalCoverage=0.0;
    for(int i=0;i<40;++i) {
        float n=float(i),cell=floor(n*0.5),halfIndex=mod(n,2.0);
        vec2 index=vec2(mod(cell,grid.x),floor(cell/grid.x));
        vec2 a=vertex(index,grid)*size;
        vec2 b=vertex(index+vec2(1,0),grid)*size;
        vec2 c=vertex(index+vec2(1,1),grid)*size;
        vec2 d=vertex(index+vec2(0,1),grid)*size;
        bool merged=hash(cell+601.0)<0.25;
        if(merged && halfIndex>0.5) continue;
        vec2 v0,v1,v2;
        if(merged) {v0=a;v1=b;v2=c;}
        else if(hash(cell+503.0)<0.5) {
            v0=a;v1=halfIndex<0.5?b:c;v2=halfIndex<0.5?c:d;
        } else {
            v0=halfIndex<0.5?a:b;v1=halfIndex<0.5?b:c;v2=d;
        }
        vec2 center=merged?(a+b+c+d)*0.25:(v0+v1+v2)/3.0;
        float birth=closing?0.0:hash(n+37.0)*0.14;
        float duration=closing?1.0:mix(0.49,0.73,hash(n+71.0));
        float age=clamp((t-birth)/duration,0.0,1.0);
        if(!closing && t<=birth) continue;
        float departure=age;
        if(closing) age=1.0-age;
        float remaining=pow(1.0-age,closing?mix(1.35,1.7,hash(n+101.0)):mix(1.7,3.0,hash(n+101.0)));
        // Stagger release by 0–18 ms and let each shard accelerate differently.
        // All finish their varied fall by 200 ms as the progressive fade continues.
        float closeDelay=mix(0.0,18.0,hash(n+811.0))/240.0;
        float closeEnd=mix(180.0,200.0,hash(n+829.0))/240.0;
        float closePhase=clamp((t-closeDelay)/(closeEnd-closeDelay),0.0,1.0);
        if(closing) remaining=pow(closePhase,mix(0.85,2.2,hash(n+101.0)));
        float heading=hash(n+131.0)*6.2831853;
        vec2 direction=vec2(cos(heading),sin(heading));
        vec2 offset=direction*length(size)*mix(0.65,1.10,hash(n+163.0))*remaining;
        offset+=vec2(-direction.y,direction.x)*sin(age*3.14159265)*(1.0-age)*mix(-110.0,110.0,hash(n+197.0));
        if(closing) {
            // Mostly modest drops, with a few deeper falls for emphasis.
            // Direction stays downward and output remains clipped to the app.
            float screenHeight=dot(abs(screenDown),size);
            bool deepDrop=hash(n+853.0)>0.80;
            float drop=deepDrop?min(screenHeight*0.38,200.0)*mix(0.85,1.0,hash(n+163.0))
                               :min(screenHeight*0.28,155.0)*mix(0.55,1.0,hash(n+163.0));
            offset=screenRight*mix(-8.0,8.0,hash(n+131.0))*pow(closePhase,1.15)
                  +screenDown*drop*remaining;
        }
        vec2 delta=pixel-center-offset;
        float bound=max(max(length(v0-center),length(v1-center)),length(v2-center))+2.0;
        if(merged) bound=max(bound,length(d-center)+2.0);
        if(dot(delta,delta)>bound*bound) continue;
        float angle=mix(-0.75,0.75,hash(n+239.0))*remaining;
        if(closing) angle=mix(-1.0,1.0,hash(n+239.0))*min(0.17,18.0/bound)
                          *pow(closePhase,mix(0.7,1.5,hash(n+877.0)));
        vec2 source=center+mat2(cos(angle),-sin(angle),sin(angle),cos(angle))*delta;
        float edge=max(max(edgeDistance(v0,v1,source),edgeDistance(v1,v2,source)),edgeDistance(v2,v0,source));
        if(merged) edge=max(max(edgeDistance(a,b,source),edgeDistance(b,c,source)),max(edgeDistance(c,d,source),edgeDistance(d,a,source)));
        float coverage=1.0-smoothstep(-0.65,0.65,edge);
        if(coverage<=0.0) continue;
        vec4 card=texture(tex,window_rect.xy+clamp(source/size,0.0,1.0)*extent);
        float rim=(1.0-smoothstep(0.4,1.5,abs(edge)))*(1.0-smoothstep(0.65,0.98,age));
        vec3 tint=mix(mint,lavender,hash(n+281.0));
        card.rgb=mix(card.rgb,mix(tint,pearl,0.6)*card.a,rim*0.6);
        // One short local accent only after this piece reaches its final pose.
        float landed=closing?t-birth:t-birth-duration;
        float pulse=smoothstep(0.0,0.014,landed)*(1.0-smoothstep(0.035,0.105,landed));
        if(pulse>0.0) {
            float sweep=smoothstep(0.0,0.105,landed);
            vec2 join=mix(v0,v1,closing?mix(0.25,0.75,hash(n+719.0)):mix(0.12,0.88,sweep));
            vec2 seam=v1-v0;
            float along=dot(source-join,normalize(seam));
            float line=1.0-smoothstep(0.4,1.4,abs(edgeDistance(v0,v1,source)));
            float interior=step(2.0,source.x)*step(2.0,source.y)*step(source.x,size.x-2.0)*step(source.y,size.y-2.0);
            float glint=line*(1.0-smoothstep(7.0,20.0,abs(along)))*(closing?0.52:0.32);
            if(!closing) glint*=interior;
            float sparkle=0.0;
            // Sparse fine four-ray glints, placed just inside the joining edge.
            if(hash(n+757.0)>0.70) {
                vec2 point=mix(join,center,0.045);
                vec2 d=abs(source-point);
                sparkle=(1.0-smoothstep(0.45,1.15,min(d.x,d.y)))
                       *(1.0-smoothstep(2.0,4.5,max(d.x,d.y)))*0.78;
            }
            float accent=clamp(max(glint,sparkle)*pulse,0.0,0.8)*(closing?0.55:1.0);
            card.rgb=mix(card.rgb,mix(tint,pearl,0.86)*card.a,accent);
        }
        // A faint edge-local wave spreads from the last joining cell to its
        // settled neighbors. It never changes alpha or survives completion.
        if(!closing && age>=0.999) {
            float waveAge=(t-(lastLanding-0.035))/0.14;
            float radius=clamp(waveAge,0.0,1.0)*length(size)*0.45;
            float band=1.0-smoothstep(5.0,22.0,abs(length(source-rippleOrigin)-radius));
            float envelope=smoothstep(0.0,0.15,waveAge)*(1.0-smoothstep(0.65,1.0,waveAge));
            envelope*=1.0-smoothstep(0.95,0.985,t);
            float nearSeam=1.0-smoothstep(1.0,8.0,abs(edge));
            float ripple=band*envelope*nearSeam*0.055;
            card.rgb=mix(card.rgb,mix(tint,pearl,0.8)*card.a,ripple);
        }
        // Scale premultiplied RGB and alpha together. Restore the sampled
        // native alpha at landing; never replace it with an opaque alpha.
        float flightOpacity=mix(0.18,1.0,smoothstep(0.78,0.99,age));
        // Fade progressively during the fall, with slightly varied onset.
        // Every shard reaches exactly zero smoothly at the 240 ms endpoint.
        if(closing) flightOpacity=1.0-smoothstep(mix(0.15,0.28,hash(n+907.0)),1.0,t);
        card*=flightOpacity;
        result+=card*coverage;totalCoverage+=coverage;
    }
    fragColor=result/max(totalCoverage,1.0);
}
