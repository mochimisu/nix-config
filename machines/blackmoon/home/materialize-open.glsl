#version 320 es
// @duration @duration@
precision highp float;
in vec2 v_texcoord;
in vec2 v_windowcoord;
uniform sampler2D tex;
uniform float progress;
uniform float seed;
uniform vec4 window_rect;
uniform vec2 surface_size;
uniform int output_transform;
out vec4 fragColor;
const bool closing = @closing@;
const vec3 ink = @sekaiInk@;
const vec3 teal = @sekaiTeal@;
const vec3 mint = @sekaiMint@;
const vec3 lavender = @sekaiLavender@;
const vec3 pink = @sekaiPink@;
const vec3 pearl = @sekaiSurface@;
float hash(float n) { return fract(sin(n * 127.1 + seed * 19.19) * 43758.5453); }
// Shared jittered vertices and edge midpoints tile diamonds and corner shards exactly.
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
// Offset a convex vertex inward, then measure distance to that inset polygon.
// Expanding it by a disk gives genuinely circular silhouette corners.
vec2 insetVertex(vec2 prev,vec2 v,vec2 next,float amount) {
    vec2 e0=normalize(v-prev),e1=normalize(next-v);
    vec2 n0=vec2(-e0.y,e0.x),n1=vec2(-e1.y,e1.x);
    return v+(n0+n1)*(amount/max(0.02,1.0+dot(n0,n1)));
}
float segmentDistance2(vec2 a,vec2 b,vec2 p) {
    vec2 e=b-a,q=p-a;
    q-=e*clamp(dot(q,e)/max(dot(e,e),0.0001),0.0,1.0);
    return dot(q,q);
}
float starFive(vec2 p) {
    float dist2=100.0;
    bool inside=false;
    vec2 a=vec2(1.0,0.0);
    for(int j=1;j<=10;++j) {
        float angle=float(j)*0.62831853;
        float radius=(j%2==0)?1.0:0.44;
        vec2 b=vec2(cos(angle),sin(angle))*radius;
        dist2=min(dist2,segmentDistance2(a,b,p));
        if((a.y>p.y)!=(b.y>p.y)) {
            if(p.x<(b.x-a.x)*(p.y-a.y)/(b.y-a.y)+a.x) inside=!inside;
        }
        a=b;
    }
    return (inside?-1.0:1.0)*sqrt(dist2)-0.002;
}
float mahouDistance(vec2 q,float kind) {
    if(kind<0.5) return starFive(q);
    if(kind<1.5) return max(length(q)-1.0,0.91-length(q-vec2(0.34,-0.04)))-0.002;
    if(kind<2.5) return max(length(q-vec2(0.0,0.65)),length(q+vec2(0.0,0.65)))-1.152;
    return pow(pow(abs(q.x),0.64)+pow(abs(q.y),0.64),1.0/0.64)-1.001;
}
// Untinted focal content; balanced pastel companions across both directions.
vec3 motifPigment(float n,float vertical,bool focal) {
    float choice=mod(n+floor(n/4.0),4.0);
    if(choice<0.5) return mix(mint,pearl,0.22);
    if(choice<1.5) return vec3(0.72,0.84,0.95); // powder blue
    if(choice<2.5) return mix(pink,pearl,0.48);
    return mix(lavender,pearl,0.42);
}
float kiraGlint(vec2 delta,float radius) {
    vec2 d=abs(delta)/max(radius,0.001);
    return 1.0-smoothstep(0.86,1.06,sqrt(d.x)+sqrt(d.y));
}
vec4 starAssembly(vec2 uv,vec2 size,float t,vec4 original) {
    vec2 p=(uv-0.5)*size;
    float unit=min(size.x,size.y);
    // One strong spring punch, overshoot, and visible settle in the first half.
    float phase=clamp(t/0.48,0.0,1.0),u=phase-1.0;
    float spring=1.0+4.4*u*u*u+3.4*u*u;
    float radius=unit*0.50*max(spring,0.001);
    float turn=-1.5707963+0.15*sin(phase*6.2831853)*(1.0-phase);
    vec2 central=mat2(cos(turn),-sin(turn),sin(turn),cos(turn))*p;
    // Small circular dilation of an inset silhouette rounds tips, not the motif.
    float roundPx=min(3.0,radius*0.06),coreRadius=max(radius-roundPx,0.001);
    float field=starFive(central/coreRadius)*coreRadius-roundPx;
    float coverage=1.0-smoothstep(-0.6,0.6,field);
    float heroCoverage=coverage;
    float restore=smoothstep(0.58,0.97,t),pigmentLife=1.0-restore;
    float veilAlpha=0.0,veilWeight=0.0;
    vec3 veilPigment=vec3(0.0);
    float layers=coverage;
    float border=1.0-smoothstep(11.0,18.0,abs(field));
    float glints=0.0;
    for(int j=0;j<24;++j) {
        float n=float(j),birth=0.12+hash(n+1401.0)*0.20;
        if(t<=birth) continue;
        float launch=smoothstep(birth,birth+0.22,t);
        float land=smoothstep(birth+0.22,birth+0.40,t);
        float theta=n*2.39996323+hash(n+1409.0)*0.17;
        vec2 direction=vec2(cos(theta),sin(theta));
        // Shoot out from the star, arc to the boundary, then return inward.
        float reach=mix(0.12,1.13,launch)-0.19*land;
        vec2 center=direction*size*0.5*reach;
        center+=vec2(-direction.y,direction.x)*unit*0.06*sin(launch*3.14159265);
        float r=unit*mix(0.055,0.105,hash(n+1423.0));
        float smallRound=min(2.2,r*0.07),coreR=max(r-smallRound,1.0);
        vec2 q=p-center;
        float spin=hash(n+1433.0)*6.2831853+(1.0-land)*mix(-0.8,0.8,hash(n+1439.0));
        q=mat2(cos(spin),-sin(spin),sin(spin),cos(spin))*q/coreR;
        float kind=mod(n,4.0);
        if(kind>2.5) q.x*=1.7;
        // Each landed motif expands its reveal from the perimeter inward.
        // Union removes internal seams automatically where shapes meet.
        float fill=smoothstep(birth+0.37,0.97,t)*length(size)*0.62;
        float edge=mahouDistance(q,kind)*coreR-smallRound-fill;
        float fade=smoothstep(birth,birth+0.10,t);
        float layer=(1.0-smoothstep(-0.6,0.6,edge))*fade;
        coverage=1.0-(1.0-coverage)*(1.0-layer);
        float glassAlpha=layer*mix(mix(0.34,0.48,hash(n+1487.0)),1.0,restore);
        veilAlpha=1.0-(1.0-veilAlpha)*(1.0-glassAlpha);
        veilPigment+=motifPigment(n,uv.y,false)*glassAlpha;
        veilWeight+=glassAlpha;
        layers+=layer;
        border=max(border,(1.0-smoothstep(11.0,18.0,abs(edge)))*fade);
        // Sparse pearl four-point flashes while companions arrive, then gone.
        if(mod(n,4.0)<0.5) {
            float age=t-birth-0.20;
            float flash=smoothstep(0.0,0.035,age)*(1.0-smoothstep(0.055,0.13,age));
            vec2 point=center+vec2(-0.22,-0.30)*r;
            glints=max(glints,kiraGlint(p-point,mix(6.0,9.0,hash(n+1501.0)))*flash);
        }
        field=min(field,edge);
    }
    float edgeLife=1.0-smoothstep(0.75,0.95,t);
    float contact=1.0-smoothstep(1.0,2.4,layers);
    float inkLine=border*edgeLife*contact;
    float pearlLine=(1.0-smoothstep(3.2,4.8,abs(abs(field)-10.0)))*edgeLife*contact;
    float heroFlash=smoothstep(0.15,0.21,t)*(1.0-smoothstep(0.26,0.34,t));
    glints=max(glints,kiraGlint(p-vec2(-0.22,-0.30)*radius,10.0)*heroFlash);
    // The main star sits above the light veils. All alphas remain fractions
    // of native alpha; overlap stays bounded without additive over-brightness.
    vec3 heroRGB=original.rgb;
    vec3 veilRGB=mix(original.rgb,(veilPigment/max(veilWeight,0.00001))*original.a,0.72*pigmentLife);
    float heroAlpha=heroCoverage*mix(0.98,1.0,restore);
    vec4 color=vec4(heroRGB*heroAlpha+veilRGB*veilAlpha*(1.0-heroAlpha),
                    original.a*(heroAlpha+veilAlpha*(1.0-heroAlpha)));
    vec3 edgePastel=mix(veilPigment/max(veilWeight,0.00001),mix(mint,pearl,0.70),heroCoverage);
    color.rgb=mix(color.rgb,mix(ink,edgePastel,0.66)*color.a,inkLine*0.90);
    color.rgb=mix(color.rgb,pearl*color.a,pearlLine*0.96);
    color.rgb=mix(color.rgb,pearl*color.a,glints*edgeLife*0.96);
    return color;
}
// Snapshot UVs use panel orientation; live client UVs use the window's own
// orientation. The plugin supplies the actual Wayland output transform.
vec2 panelToWindow(vec2 p) {
    if(output_transform==1) return vec2(1.0-p.y,p.x);
    if(output_transform==2) return 1.0-p;
    if(output_transform==3) return vec2(p.y,1.0-p.x);
    if(output_transform==4) return vec2(1.0-p.x,p.y);
    if(output_transform==5) return vec2(1.0-p.y,1.0-p.x);
    if(output_transform==6) return vec2(p.x,1.0-p.y);
    if(output_transform==7) return p.yx;
    return p;
}
vec2 windowToPanel(vec2 p) {
    if(output_transform==1) return vec2(p.y,1.0-p.x);
    if(output_transform==3) return vec2(1.0-p.y,p.x);
    return panelToWindow(p); // Other transforms are their own inverse.
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
    if(!closing) {
        // window_rect is the client's real source crop, captured before the
        // plugin's intermediate pass clears the renderer UVs. No screen origin,
        // framebuffer position, or output dimensions enter this composition.
        if(all(greaterThan(surface_size,vec2(1.0)))) size=surface_size;
        fragColor=starAssembly(v_windowcoord,size,t,original);return;
    }
    uv=panelToWindow(uv);
    if((output_transform%2)==1) size=size.yx;
    vec2 grid=size.x>=size.y?vec2(4.0,3.0):vec2(3.0,4.0);
    vec2 pixel=uv*size;
    vec2 screenRight=vec2(1.0,0.0),screenDown=vec2(0.0,1.0);
    if(closing && (any(lessThan(uv,vec2(0.0))) || any(greaterThan(uv,vec2(1.0))))) {fragColor=vec4(0.0);return;}
    float lastLanding=0.0;
    vec2 rippleOrigin=size*0.5;
    if(!closing) for(int k=0;k<60;++k) {
        float key=float(k),cell=floor(key/5.0);
        float landing=hash(key+37.0)*0.14+mix(0.49,0.73,hash(key+71.0));
        if(landing>lastLanding) {
            lastLanding=landing;
            rippleOrigin=(vec2(mod(cell,grid.x),floor(cell/grid.x))+0.5)/grid*size;
        }
    }
    vec4 result=vec4(0.0);
    float totalCoverage=0.0;
    vec4 plainResult=vec4(0.0);
    float contactCoverage=0.0;
    for(int i=0;i<12;++i) {
        float n=float(i),cell=n,part=mod(n,3.0);
        vec2 index=vec2(mod(cell,grid.x),floor(cell/grid.x));
        vec2 a=vertex(index,grid)*size;
        vec2 b=vertex(index+vec2(1,0),grid)*size;
        vec2 c=vertex(index+vec2(1,1),grid)*size;
        vec2 d=vertex(index+vec2(0,1),grid)*size;
        // Each shared cell becomes one broad kite and four smaller corner
        // facets. Shared midpoints keep complete coverage without cracks.
        vec2 ab=(a+b)*0.5,bc=(b+c)*0.5,cd=(c+d)*0.5,da=(d+a)*0.5;
        bool quad=part<0.5;
        vec2 v0,v1,v2,v3=da;
        if(quad) {v0=ab;v1=bc;v2=cd;}
        else if(part<1.5) {v0=a;v1=ab;v2=da;}
        else if(part<2.5) {v0=b;v1=bc;v2=ab;}
        else if(part<3.5) {v0=c;v1=cd;v2=bc;}
        else {v0=d;v1=da;v2=cd;}
        vec2 center=quad?(v0+v1+v2+v3)*0.25:(v0+v1+v2)/3.0;
        float placement=n*2.39996323+0.3;
        center=size*0.5+vec2(cos(placement),sin(placement))*size*0.43*sqrt((n+0.5)/12.0);
        vec2 shapeSize=size/grid*mix(0.38,0.46,hash(n+1019.0));
        shapeSize*=vec2(mix(0.75,1.15,hash(n+1021.0)),mix(0.8,1.2,hash(n+1031.0)));
        float motif=mod(n,4.0);
        if(motif>2.5) shapeSize*=vec2(0.62,1.14);
        else if(motif>1.5) shapeSize*=vec2(1.10,0.78);
        float birth=closing?0.0:hash(n+37.0)*0.14;
        float duration=closing?1.0:mix(0.49,0.73,hash(n+71.0));
        float age=clamp((t-birth)/duration,0.0,1.0);
        if(!closing && t<=birth) continue;
        float departure=age;
        if(closing) age=1.0-age;
        float remaining=pow(1.0-age,closing?mix(1.35,1.7,hash(n+101.0)):mix(1.7,3.0,hash(n+101.0)));
        // Stagger release by 0–18 ms and let each shard accelerate differently.
        // All finish their varied fall by 200 ms as the progressive fade continues.
        // A light two-beat release, still inside the approved 0–18 ms range.
        float closeDelay=(hash(n+811.0)<0.55?mix(0.0,5.0,hash(n+817.0))
                                             :mix(13.0,18.0,hash(n+817.0)))/240.0;
        float closeEnd=mix(180.0,200.0,hash(n+829.0))/240.0;
        float closePhase=clamp((t-closeDelay)/(closeEnd-closeDelay),0.0,1.0);
        if(closing) remaining=pow(closePhase,mix(0.95,1.85,hash(n+101.0)));
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
        if(quad) bound=max(bound,length(v3-center)+2.0);
        bound=max(shapeSize.x,shapeSize.y)*1.25+8.0;
        if(dot(delta,delta)>bound*bound) continue;
        float angle=mix(-0.75,0.75,hash(n+239.0))*remaining;
        if(closing) angle=mix(-1.0,1.0,hash(n+239.0))*min(0.17,18.0/bound)
                          *pow(closePhase,mix(0.7,1.5,hash(n+877.0)))
                          +min(0.018,2.0/bound)*sin(closePhase*6.2831853)
                           *sin(closePhase*3.14159265)*mix(-1.0,1.0,hash(n+883.0));
        vec2 source=center+mat2(cos(angle),-sin(angle),sin(angle),cos(angle))*delta;
        float edge=max(max(edgeDistance(v0,v1,source),edgeDistance(v1,v2,source)),edgeDistance(v2,v0,source));
        if(quad) edge=max(max(edgeDistance(v0,v1,source),edgeDistance(v1,v2,source)),max(edgeDistance(v2,v3,source),edgeDistance(v3,v0,source)));
        float seamLife=closing?smoothstep(0.0,0.12,t):(1.0-smoothstep(0.80,0.98,t));
        {
            float turn=motif>1.5?mix(-0.45,0.45,hash(n+1033.0)):hash(n+1033.0)*6.2831853;
            float roundPx=min(2.8,min(shapeSize.x,shapeSize.y)*0.06);
            vec2 coreSize=max(shapeSize-vec2(roundPx),vec2(1.0));
            vec2 q=mat2(cos(turn),-sin(turn),sin(turn),cos(turn))*(source-center)/coreSize;
            float kind=mod(n,4.0),shape;
            if(kind<0.5) {
                // Preserve five distinct points with a small circular tip radius.
                shape=starFive(q);
            } else if(kind<1.5) {
                // Offset circular subtraction keeps a clearly open crescent.
                shape=max(length(q)-1.0,0.91-length(q-vec2(0.34,-0.04)))-0.002;
            } else if(kind<2.5) {
                // A lens intersection makes a tapered petal with two distinct tips.
                shape=max(length(q-vec2(0.0,0.65)),length(q+vec2(0.0,0.65)))-1.15-0.002;
            } else {
                // Concave four-point glimmer, not a soft four-lobed blob.
                shape=pow(pow(abs(q.x),0.64)+pow(abs(q.y),0.64),1.0/0.64)-1.0;
                shape-=0.001;
            }
            edge=shape*min(coreSize.x,coreSize.y)-roundPx;
        }
        float coverage=1.0-smoothstep(-0.55,0.55,edge);
        if(coverage<=0.0) continue;
        vec4 card=texture(tex,window_rect.xy+windowToPanel(clamp(source/size,0.0,1.0))*extent);
        vec4 plainCard=card;
        // Chunky pastel outline plus broad pearl inset: readable on both
        // dark and bright desktop backgrounds, without a broad glass glow.
        float keyline=(1.0-smoothstep(11.0,18.0,abs(edge)))*seamLife;
        float rim=(1.0-smoothstep(3.2,4.8,abs(abs(edge)-10.0)))*seamLife;
        bool focal=mod(n,4.0)<0.5;
        vec3 tint=motifPigment(n,source.y/size.y,focal);
        card.rgb=mix(card.rgb,tint*card.a,(focal?0.0:0.72)*seamLife);
        card.rgb=mix(card.rgb,mix(ink,focal?mix(mint,pearl,0.70):tint,0.66)*card.a,keyline*0.90);
        card.rgb=mix(card.rgb,pearl*card.a,rim*0.96);
        // One short local accent only after this piece reaches its final pose.
        float landed=closing?t-birth:t-birth-duration;
        float pulse=smoothstep(0.0,0.014,landed)*(1.0-smoothstep(0.035,0.105,landed));
        // Soft glints twinkle during the fall, not only on the departure frame.
        if(closing) {
            float twinkleStart=mix(0.18,0.36,hash(n+919.0));
            float twinkleAge=t-twinkleStart;
            pulse=smoothstep(0.0,0.07,twinkleAge)*(1.0-smoothstep(0.10,0.27,twinkleAge));
        }
        if(pulse>0.0) {
            float sweep=smoothstep(0.0,0.105,landed);
            vec2 join=mix(v0,v1,closing?mix(0.25,0.75,hash(n+719.0)):mix(0.12,0.88,sweep));
            vec2 seam=v1-v0;
            float along=dot(source-join,normalize(seam));
            float line=1.0-smoothstep(0.7,2.4,abs(edge));
            float interior=step(2.0,source.x)*step(2.0,source.y)*step(source.x,size.x-2.0)*step(source.y,size.y-2.0);
            float glint=line*(1.0-smoothstep(7.0,20.0,abs(along)))*(closing?0.52:0.32);
            if(!closing) glint*=interior;
            float sparkle=0.0;
            // Sparse fine four-ray glints, placed just inside the joining edge.
            if(quad || hash(n+757.0)>0.62) {
                vec2 point=mix(join,center,0.14);
                vec2 d=abs(source-point);
                float ray=mix(6.0,12.0,hash(n+953.0));
                // Concave four-point glint, with a soft pearl core.
                float star=sqrt(d.x/ray)+sqrt(d.y/ray);
                sparkle=(1.0-smoothstep(0.86,1.10,star))*0.88;
                if(closing) {
                    // Tiny companion pearl; sparse and attached to the shard.
                    vec2 companion=source-point-vec2(7.0,-5.0);
                    sparkle=max(sparkle,(1.0-smoothstep(0.5,1.4,length(companion)))*0.45);
                }
            }
            float accent=clamp(max(glint,sparkle)*pulse,0.0,0.8)*(closing?0.72:1.0);
            card.rgb=mix(card.rgb,mix(tint,pearl,0.86)*card.a,accent);
        }
        // Scale premultiplied RGB and alpha together. Restore the sampled
        // native alpha at landing; never replace it with an opaque alpha.
        float flightOpacity=mix(0.74,1.0,smoothstep(0.78,0.99,age));
        // Fade progressively during the fall, with slightly varied onset.
        // Every shard reaches exactly zero smoothly at the 240 ms endpoint.
        if(closing) flightOpacity=(1.0-smoothstep(mix(0.15,0.28,hash(n+907.0)),1.0,t))
                                *mix(1.0,focal?0.98:mix(0.34,0.48,hash(n+1487.0)),seamLife);
        // Keep flying interiors translucent, but let the rounded luminous
        // edges read clearly until the whole assembly settles.
        if(!closing) {
            plainResult+=plainCard*flightOpacity*coverage;
            // Count only pieces converging on their final location here.
            // Overlapping neighbors dissolve local edges without a global grid timer.
            contactCoverage+=coverage*(1.0-smoothstep(5.0,35.0,length(offset)));
            flightOpacity=mix(flightOpacity,max(flightOpacity,0.68),rim);
        }
        card*=flightOpacity;
        result+=card*coverage;totalCoverage+=coverage;
    }
    fragColor=result/max(totalCoverage,1.0);
    if(closing) fragColor=mix(original,fragColor,smoothstep(0.0,0.12,t));
    // All pieces land by 0.87. Restore complete native content as the last
    // bevels disappear, including subpixel gaps where three facets meet.
    if(!closing) {
        float contact=smoothstep(0.65,1.60,contactCoverage);
        fragColor=mix(fragColor,plainResult/max(totalCoverage,1.0),contact);
        float assembled=smoothstep(1.2,2.2,contactCoverage)*smoothstep(0.65,0.85,t);
        assembled=max(assembled,smoothstep(0.88,0.98,t));
        fragColor=mix(fragColor,original,assembled);
    }
}
