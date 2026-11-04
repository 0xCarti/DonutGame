"""Offline gameplay composition QA from final FBXs and WorldBuilder placements.

This is NOT an in-engine screenshot. Camera position/target/FOV and all station
placements are read from WorldBuilder.cs. FBX native facing remains explicitly
testable until Unity can run. Render both the raw source-facing result and a
customer-facing composition preview; the latter changes only customer yaw.
"""
import bpy, math, re, json, sys
from pathlib import Path
from mathutils import Matrix,Vector

ROOT=Path(__file__).resolve().parents[2];PROJECT=ROOT/'unity/GoldenHour';ART=PROJECT/'Assets/Art';QA=ROOT/'playtest-reports/unity-assets'
QA.mkdir(exist_ok=True,parents=True)
SOURCE=(PROJECT/'Assets/Scripts/Presentation/WorldBuilder.cs').read_text()
REVISED='--revised' in sys.argv
MAT=json.loads((ART/'Textures/material_manifest.json').read_text())
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_x=1920;scene.render.resolution_y=1080;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
scene.view_settings.exposure=-.25
scene.world.use_nodes=True;bg=scene.world.node_tree.nodes.get('Background');bg.inputs['Color'].default_value=(.13,.18,.30,1);bg.inputs['Strength'].default_value=.55

def vals(s):return tuple(float(v.strip().removesuffix('f')) for v in s.split(','))
def U(p):return Vector((p[0],p[2],p[1]))

materials={}
for name,d in MAT.items():
    m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=d['color'];p.inputs['Metallic'].default_value=d['metallic'];p.inputs['Roughness'].default_value=d['roughness']
    for key,sock in [('albedo','Base Color'),('roughnessMap','Roughness'),('normal','Normal')]:
        fn=d.get(key)
        if not fn:continue
        node=m.node_tree.nodes.new('ShaderNodeTexImage');node.image=bpy.data.images.load(str(ART/'Textures'/fn),check_existing=True)
        if key!='albedo':node.image.colorspace_settings.name='Non-Color'
        if key=='normal':
            normal=m.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.22;m.node_tree.links.new(node.outputs['Color'],normal.inputs['Color']);m.node_tree.links.new(normal.outputs['Normal'],p.inputs['Normal'])
        elif key=='albedo':
            mix=m.node_tree.nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.inputs[2].default_value=d['color'];m.node_tree.links.new(node.outputs['Color'],mix.inputs[1]);m.node_tree.links.new(mix.outputs[0],p.inputs[sock])
            if d.get('alphaClip'):m.node_tree.links.new(node.outputs['Alpha'],p.inputs['Alpha']);m.surface_render_method='DITHERED'
        else:m.node_tree.links.new(node.outputs['Color'],p.inputs[sock])
    if name=='GH_Lamp':p.inputs['Emission Color'].default_value=(1,.46,.12,1);p.inputs['Emission Strength'].default_value=4
    materials[name]=m

def simplemat(name,col,rough=.7):
    m=bpy.data.materials.new(name);m.diffuse_color=(*col,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*col,1);p.inputs['Roughness'].default_value=rough;materials[name]=m;return m
simplemat('Ground',(.13,.105,.078));simplemat('Skyline',(.065,.085,.12))

def box(name,pos,size,mat):
    bpy.ops.mesh.primitive_cube_add(size=1,location=U(pos));o=bpy.context.object;o.name=name;o.dimensions=U(size);o.data.materials.append(materials[mat]);return o

def point(name,pos,watts,color,radius=.1):
    data=bpy.data.lights.new(name,'POINT');data.energy=watts;data.color=color;data.shadow_soft_size=radius;o=bpy.data.objects.new(name,data);scene.collection.objects.link(o);o.location=U(pos);return o

cache={};instances={};model_files={'fryer':'Fryer','counter':'Counter','tray':'Tray','scoop':'Scoop','bag':'Bag','bucket':'Bucket','shaker':'Shaker','shakerPowdered':'ShakerPowdered','extinguisher':'Extinguisher','bell':'ServiceBell','canopy':'Canopy','hangingSign':'HangingSign','pendant':'PendantLamp','sandwichBoard':'SandwichBoard','customer':'Customer_Milo','hands':'BakerHands','marketStall':'MarketStall','parkBench':'ParkBench','ferrisWheel':'FerrisWheel'}

def model(key,name,pos,scale=(1,1,1),yaw=0):
    char=key in ['customer','hands'];fn=model_files[key];file=ART/('Characters' if char else 'Props')/(fn+'.fbx')
    before=set(bpy.data.objects);bpy.ops.import_scene.fbx(filepath=str(file));added=[o for o in bpy.data.objects if o not in before]
    parent=bpy.data.objects.new(name,None);scene.collection.objects.link(parent)
    for o in added:
        if o.parent not in added:o.parent=parent
        if o.type=='MESH':
            for i,m in enumerate(o.data.materials):
                if m:
                    base=re.sub(r'\.\d+$','',m.name)
                    if base in materials:o.data.materials[i]=materials[base]
        if o.type=='ARMATURE':
            act=next((a for a in bpy.data.actions if ('Hands_Idle' if key=='hands' else 'Customer_Idle') in a.name),None)
            if act:o.animation_data_create();o.animation_data.action=act
    parent.location=U(pos);parent.scale=U(scale);parent.rotation_euler.z=math.radians(yaw);instances[name]=parent
    return parent

positions={}
pattern=r'Model\(a\.(\w+),"([^"]+)",(?:new Vector3\(([^)]+)\)|Vector3.zero)\)'
for key,name,xyz in re.findall(pattern,SOURCE):
    if key=='hands' or key not in model_files:continue
    try:pos=vals(xyz) if xyz else (0,0,0)
    except ValueError:continue
    positions[name]={'asset':key,'unityPosition':pos}
    model(key,name,pos,yaw=180 if key=='customer' and not REVISED else 0)
if 'Paper bags' in instances:
    p=positions['Paper bags']['unityPosition']
    for i in range(1,4):model('bag','Folded bag '+str(i),(p[0]+i*.027,p[1],p[2]+i*.011),scale=(1,1,.22))

camera_pos=vals(re.search(r'Camera\.transform\.position = new Vector3\(([^)]+)\)',SOURCE)[1]);target=vals(re.search(r'LookRotation\(new Vector3\(([^)]+)\)',SOURCE)[1]);fov=float(re.search(r'Camera\.fieldOfView=(\d+)',SOURCE)[1])
if REVISED:camera_pos=(0,1.70,-1.40);target=(0,1.18,.15);fov=67
data=bpy.data.cameras.new('Exact WorldBuilder camera');camera=bpy.data.objects.new('Exact WorldBuilder camera',data);scene.collection.objects.link(camera);scene.camera=camera;camera.location=U(camera_pos);camera.rotation_euler=(U(target)-camera.location).to_track_quat('-Z','Y').to_euler();data.type='PERSP';data.sensor_fit='VERTICAL';data.sensor_height=24;data.lens=24/(2*math.tan(math.radians(fov)/2));data.clip_start=.035;data.clip_end=70

if (ART/'Characters/BakerHands.fbx').exists():
    hands=model('hands','Operator hands',(0,0,0));hands.matrix_world=camera.matrix_world@Matrix(((1,0,0,0),(0,0,1,0),(0,1,0,0),(0,0,0,1)))

box('Fairground',(0,-.08,5),(70,.15,70),'Ground')
matpos=vals(re.search(r'PackageSpot\.position=new Vector3\(([^)]+)\)',SOURCE)[1]);box('Packing mat',matpos,(.35,.009,.32),'GH_Teal')
for i in range(7):
    x=(i-3)*3.7
    if REVISED:model('marketStall','Authored market stall '+str(i),(x,0,7.5+i%2))
    else:
        box('Distant midway stall',(x,1.1,7.5+i%2),(2.6,2.2,1.7),'GH_Teal' if i%2==0 else 'GH_Red')
        for j in range(8):box('Stall awning stripe',(x-1.3+j*.37,2.3,6.8+i%2),(.37,.17,1.5),'GH_Cream' if j%2==0 else 'GH_Red')
    point('Stall lamp',(x,2,6.4+i%2),80,(1,.57,.26),.2)
    # World-space text uses Blender mesh lettering at the same transform.
    data=bpy.data.curves.new('Midway lettering','FONT');data.body=['LEMONADE','CANDY APPLES','THE MIDWAY','TICKETS','ARCADE','POPCORN','FUN & GAMES'][i];data.size=.13;data.align_x='CENTER';data.align_y='CENTER'
    o=bpy.data.objects.new(data.body,data);scene.collection.objects.link(o);o.location=U((x,1.98 if REVISED else 2.05,(6.95 if REVISED else 6.62)+i%2));o.rotation_euler=(math.pi/2,0,0);o.data.materials.append(materials['GH_Cream'])
if REVISED:
    if not any(p['asset']=='ferrisWheel' for p in positions.values()):model('ferrisWheel','Authored ferris wheel',(-8,0,15))
    if not any(p['asset']=='parkBench' for p in positions.values()):model('parkBench','Authored park bench',(-3.2,0,3.7),yaw=15)
for i in range(24):
    angle=i*math.pi/12;p=Vector((math.cos(angle)*4.3,math.sin(angle)*4.3,0));centre=Vector((-8,6,15))
    if not REVISED:
        spoke=box('Ferris wheel spoke',centre+p*.5,(.055,4.3,.055),'GH_Cream');spoke.rotation_euler.y=angle-math.pi/2
        box('Ferris wheel gondola',centre+p,(.45,.55,.4),'GH_Red' if i%2==0 else 'GH_Teal');box('Ferris wheel light',centre+p-Vector((0,0,.23)),(.09,.09,.09),'GH_Lamp')
    x=-13+i*1.1;box('Midway string light',(x,4-math.sin(i*.14)*.6,5),(.07,.07,.07),'GH_Lamp')
for i in range(19):
    x=-1.90+i*.21;y=2.43-.15*(1-x*x/3.61)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=.02,location=U((x,y,-.15)));bpy.context.object.data.materials.append(materials['GH_Lamp'])
    if i%4==0:point('Festoon practical',(x,y,-.15),9,(1,.57,.18))

sun_data=bpy.data.lights.new('Warm dusk sun','SUN');sun_data.energy=2;sun_data.color=(1,.73,.47);sun_data.angle=.12;sun=bpy.data.objects.new('Warm dusk sun',sun_data);scene.collection.objects.link(sun);sun.rotation_euler=(math.radians(30),math.radians(-35),math.radians(-28))
point('Counter softbox',(0,2.3,-.5),145,(1,.83,.62),.65)

# Representative ready stock shows spacing and scale; these are authored FBXs.
before=set(bpy.data.objects);bpy.ops.import_scene.fbx(filepath=str(ART/'Props/MiniDonut.fbx'));donut=next(o for o in bpy.data.objects if o not in before and o.type=='MESH')
for i,m in enumerate(donut.data.materials):donut.data.materials[i]=materials[re.sub(r'\.\d+$','',m.name)]
traypos=positions['Catch tray']['unityPosition']
for i in range(15):
    o=donut if i==0 else donut.copy()
    if i:scene.collection.objects.link(o)
    o.location=U((traypos[0]+(i%5-2)*.075,traypos[1]+.027,traypos[2]+(i//5-1)*.075));o.rotation_euler.z=i*.41

scene.frame_set(1)
report={'camera':{'position':camera_pos,'target':target,'verticalFov':fov,'resolution':[1920,1080]},'placements':positions,'limitation':'Offline Blender FBX roundtrip. Unity import handedness and material/light matching are not engine verified. Raw render preserves customer yaw180; facing preview changes only customer yaw0.','sourceFile':'Assets/Scripts/Presentation/WorldBuilder.cs'}
if REVISED:
    report['limitation']='Non-Unity offline preview. Parent-requested revised camera, authored market stalls/ferris wheel and native-facing customer. Unity FBX facing, shading and interaction remain unverified.'
(QA/('workstation-revised-contract.json' if REVISED else 'workstation-preview-contract.json')).write_text(json.dumps(report,indent=2))
if REVISED:
    scene.render.filepath=str(QA/'workstation-revised-nonunity.png');bpy.ops.render.render(write_still=True)
else:
    scene.render.filepath=str(QA/'workstation-raw-transforms.png');bpy.ops.render.render(write_still=True)
    if 'Fairgoer' in instances:instances['Fairgoer'].rotation_euler.z=0
    scene.render.filepath=str(QA/'workstation-facing-preview.png');bpy.ops.render.render(write_still=True)
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(QA/('workstation-revised.blend' if REVISED else 'workstation-preview.blend')))
print('WORKSTATION_PREVIEW_COMPLETE',json.dumps(report['camera']))
