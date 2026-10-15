"""Compare generated homes, allowing only this extraction's explicit equivalent changes."""
import argparse
import json
from pathlib import Path
import re


def files(generation):
    root=generation/'home-files'
    return {str(p.relative_to(root)):p for p in root.rglob('*') if p.is_symlink() or p.is_file()}


def normalize_sidebar(s, host):
    flag=re.search(r'readonly property bool mediaFeedbackEnabled: (true|false)',s)
    if flag:assert flag[1] == ('true' if host=='blackmoon' else 'false'), 'Media routing changed'
    s=re.sub(r'    readonly property string hostName: "[^"\n]+"\n','',s)
    s=re.sub(r'    readonly property bool mediaFeedbackEnabled: (true|false)\n','',s)
    blocked=["AD102 High Definition Audio Controller Digital Stereo (HDMI)","USB Audio Front Headphones","USB Audio Speakers","RZ19-0229 Gaming Microphone Analog Stereo"] if host=='blackmoon' else []
    s=re.sub(r'    readonly property var blockedAudioDescriptions: hostName === "blackmoon" \? \[.*?\] : \[\]\n',
             '    readonly property var blockedAudioDescriptions: '+json.dumps(blocked,separators=(',',':'))+'\n',s,flags=re.S)
    return s.replace('root.mediaFeedbackEnabled','root.themed')


def normalize_hypr(s):
    # The opt-in moves one binding and one non-overlapping rule in the module merge.
    binding=re.findall(r'^hl.bind\("SUPER \+ ALT \+ space".*\n',s,re.M)
    rule=re.findall(r'hl.layer_rule\(\{\n  \["blur"\] = true,\n  \["ignore_alpha"\] = 0,\n  \["match"\] = \{\n    \["namespace"\] = "\^\(notifications\)\$"\n  \},\n  \["name"\] = "blackmoon-notification-blur"\n\}\)\n',s)
    for chunk in binding+rule:s=s.replace(chunk,'')
    return s, binding, rule


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('before',type=Path);ap.add_argument('after',type=Path);ap.add_argument('--host',required=True)
    a=ap.parse_args();before=files(a.before);after=files(a.after);assert before.keys()==after.keys(),'Managed file set changed'
    same=0;equivalent=[]
    for rel,p in before.items():
        q=after[rel]
        if p.is_dir() or q.is_dir():assert p.resolve()==q.resolve(),rel;continue
        x,y=p.read_bytes(),q.read_bytes()
        if x==y:same+=1;continue
        x,y=x.decode(),y.decode()
        if rel=='.config/quickshell/sidebar/shell.qml':assert normalize_sidebar(x,a.host)==normalize_sidebar(y,a.host),rel
        elif rel=='.config/hypr/hyprland.lua':assert normalize_hypr(x)==normalize_hypr(y),rel
        elif rel=='.config/fontconfig/conf.d/10-hm-fonts.conf':
            normalize=lambda v: re.sub(r'/nix/store/[a-z0-9]+-home-manager-path','PROFILE',v)
            assert normalize(x)==normalize(y),rel
            # Changing package order may change the profile hash; all installed targets must match.
            roots=[Path(re.search(r'/nix/store/[a-z0-9]+-home-manager-path',v)[0]) for v in [x,y]]
            targets=lambda root:{str(p.relative_to(root)):str(p.resolve()) for p in root.rglob('*') if p.is_symlink()}
            assert targets(roots[0])==targets(roots[1]),'Profile target membership changed'
        else:raise AssertionError('Unexpected generated difference: '+rel)
        equivalent.append(rel)
    print(json.dumps({'host':a.host,'byteIdenticalFiles':same,'equivalentChanges':equivalent,'managedFileSetUnchanged':True},indent=2))


if __name__=='__main__':main()
