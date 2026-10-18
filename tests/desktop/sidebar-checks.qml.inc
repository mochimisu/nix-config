
            TestCase {
                id: tests
                when: false
                function qtest_fail(message, frame) { throw new Error(message); }
                function verify(ok) { if (!ok) throw new Error("Verification failed: " + new Error().stack); }
                function equal(a,b) { if (a !== b) throw new Error("Expected " + b + ", got " + a); }
                function label(item, value) {
                    if (item.text !== undefined && String(item.text) === value) return item;
                    for (const child of item.children || []) { const found = label(child,value); if (found) return found; }
                    return null;
                }
                function buttons(item, result) {
                    if (item.objectName === "menuButton") result.push(item);
                    for (const child of item.children || []) buttons(child,result);
                }
                function clickLabel(value, expected) {
                    console.log("click",value);
                    const t=label(controlCenterColumn,value); verify(!!t);
                    const b=t.parent;
                    const p=b.mapToItem(controlCenterColumn,0,0);
                    controlsViewport.contentY=Math.max(0,p.y+b.height-controlsViewport.height);
                    mouseClick(b,b.width/2,b.height/2);
                    equal(root.calls.pop(),expected);
                }
                function revealClock() {
                    const p=clockBlock.mapToItem(railColumn,0,0);
                    railViewport.contentY=Math.max(0,p.y+clockBlock.height-railViewport.height);
                }
                function runChecks() {
                    root.networkState = {eth:"wired", ssid:null};
                    compare(root.trayIconSource("image://icon/nm-stage01-connecting01", "nm-applet"), "image://icon/network-wired");
                    root.networkState = {eth:null, ssid:"test"};
                    compare(root.trayIconSource("image://icon/nm-stage01-connecting01", "nm-applet"), "image://icon/network-wireless");
                    root.networkState = {eth:null, ssid:null};
                    compare(root.trayIconSource("image://icon/nm-stage01-connecting01", "nm-applet"), "image://icon/nm-stage01-connecting01");
                    root.networkState = {eth:"wired", ssid:null};
                    compare(root.trayIconSource("image://icon/custom", "another-app"), "image://icon/custom");

                    console.log("geometry/workspaces");
                    equal(root.sidebarWidth,22);
                    equal(railViewport.width,22);
                    verify(workspaceModule.height >= topSection.implicitHeight);
                    const ws=label(topSection,root.themed ? "1" : "-1-"); verify(!!ws);
                    equal(ws.parent.width,22); verify(ws.parent.height >= 18);
                    mouseClick(ws.parent,11,ws.parent.height/2); equal(root.calls.pop(),"workspace:1");
                    controlCenterPopup.visible=false; audioPopup.visible=false;
                    console.log("clock toggle");
                    revealClock(); mouseClick(clockBlock,11,clockBlock.height/2);
                    equal(controlCenterPopup.visible,true); wait(50);
                    console.log("menu bounds");
                    const list=[];buttons(controlCenterColumn,list);
                    equal(list.length,10);
                    for (const b of list) {
                        verify(b.width >= 40);verify(b.height >= (root.themed ? 32 : 28));
                        const p=b.mapToItem(controlCenterColumn,0,0);
                        verify(p.x >= 0 && p.x+b.width <= controlCenterColumn.width+0.1);
                    }
                    for (const [value,expected] of [["mute","mute"],["-","volume:-5"],["+","volume:5"],["bright -","brightness:-5"],["bright +","brightness:5"],["BAL","profile"],["wifi on","wifi"],["lock","lock"],["suspend","suspend"],["shutdown","shutdown"]]) clickLabel(value,expected);
                    console.log("audio toggle");
                    const volume=label(statusColumn,"42%").parent.parent;
                    const vp=volume.mapToItem(railColumn,0,0);
                    railViewport.contentY=Math.max(0,vp.y+volume.height-railViewport.height);
                    mouseClick(volume,11,volume.height/2);equal(audioPopup.visible,true);wait(50);
                    const headphones=label(sinksColumn,"Headphones").parent;
                    mouseClick(headphones,headphones.width/2,headphones.height/2);
                    equal(root.calls.pop(),"sink:2");equal(audioPopup.visible,false);
                    if (!root.themed) return;
                    // Very short viewport: preserve access through scrolling, not shrinking targets.
                    console.log("stress 220px");
                    if (panel.height <= 220) verify(railViewport.contentHeight > railViewport.height);
                    revealClock();controlCenterPopup.visible=false;
                    mouseClick(clockBlock,11,clockBlock.height/2);equal(controlCenterPopup.visible,true);wait(50);
                    verify(controlCenterPopup.height <= panel.height-16);
                    clickLabel("shutdown","shutdown");
                    root.fixtureSinks=Array.from({length:40},(_,i)=>({id:i+1,description:"Output "+(i+1),isSink:true,isStream:false,audio:{volume:.42,muted:false}}));
                    audioPopup.visible=true;wait(70);
                    verify(audioPopup.height <= panel.height-16);
                    verify(audioViewport.contentHeight > audioViewport.height);
                    audioViewport.contentY=audioViewport.contentHeight-audioViewport.height;
                    const last=label(sinksColumn,"Output 40").parent;
                    mouseClick(last,last.width/2,last.height/2);equal(root.calls.pop(),"sink:40");
                }
            }
