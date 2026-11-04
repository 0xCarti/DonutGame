"""Golden Hour original character art. Blender 4.5+, no external assets.

Run: blender --background --python tools/unity/build_characters.py
All dimensions are metres. Blender front=-Y, Z up; exported Unity front=+Z, Y up.
"""
import bpy, math, json, random, zipfile, sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'unity/GoldenHour/Assets/Art/Characters'
OUT.mkdir(parents=True, exist_ok=True)
random.seed(42)

def reset():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for action in list(bpy.data.actions): bpy.data.actions.remove(action)
    s=bpy.context.scene
    s.render.engine='CYCLES'; s.cycles.samples=48
    s.render.resolution_x=1500; s.render.resolution_y=1500; s.render.resolution_percentage=100
    s.world.color=(.1,.1,.1)
    s.view_settings.view_transform='AgX'
    s.render.image_settings.file_format='PNG'
    s.render.film_transparent=False
    s.render.fps=30

def mat(name, color, roughness=.55, noise=0):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    nodes=m.node_tree.nodes; p=nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1); p.inputs['Roughness'].default_value=roughness
    if noise:
        n=nodes.new('ShaderNodeTexNoise'); n.inputs['Scale'].default_value=160
        n.inputs['Detail'].default_value=2
        b=nodes.new('ShaderNodeBump'); b.inputs['Strength'].default_value=noise; b.inputs['Distance'].default_value=.004
        m.node_tree.links.new(n.outputs['Fac'],b.inputs['Height']); m.node_tree.links.new(b.outputs['Normal'],p.inputs['Normal'])
    return m

def mesh(name, verts, faces, material):
    d=bpy.data.meshes.new(name); d.from_pydata(verts,[],faces); d.update()
    o=bpy.data.objects.new(name,d); bpy.context.collection.objects.link(o)
    if material: o.data.materials.append(material)
    for p in d.polygons:p.use_smooth=True
    return o

def uv(o):
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(65),island_margin=.025)
    bpy.ops.object.mode_set(mode='OBJECT')

def ellipsoid(name,loc,scale,material,segments=40,rings=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=loc)
    o=bpy.context.object;o.name=name;o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(material)
    for p in o.data.polygons:p.use_smooth=True
    return o

def tube(name,points,radii,material,n=16,ellipse=1):
    points=[Vector(p) for p in points];verts=[];faces=[]
    last_u=None
    for i,p in enumerate(points):
        tangent=(points[min(i+1,len(points)-1)]-points[max(i-1,0)]).normalized()
        if last_u is None:
            ref=Vector((0,0,1))
            if abs(tangent.dot(ref))>.96:ref=Vector((0,1,0))
            u=tangent.cross(ref).normalized()
        else:u=(last_u-tangent*last_u.dot(tangent)).normalized()
        v=tangent.cross(u).normalized();last_u=u
        for j in range(n):
            a=j*2*math.pi/n;verts.append(p+(u*math.cos(a)+v*math.sin(a)*ellipse)*radii[i])
    for i in range(len(points)-1):
        for j in range(n):
            a=i*n+j;b=i*n+(j+1)%n;faces.append((a,b,b+n,a+n))
    faces.append(tuple(reversed(range(n))));faces.append(tuple((len(points)-1)*n+j for j in range(n)))
    return mesh(name,verts,faces,material)

def loft(name,rows,material,n=64):
    # rows: z, radius-x, radius-y, y-centre
    verts=[];faces=[]
    for k,(z,rx,ry,cy) in enumerate(rows):
        for j in range(n):
            a=2*math.pi*j/n; verts.append((rx*math.sin(a),cy-ry*math.cos(a),z))
    for i in range(len(rows)-1):
        for j in range(n):
            a=i*n+j;b=i*n+(j+1)%n;faces.append((a,b,b+n,a+n))
    faces.append(tuple(reversed(range(n))));faces.append(tuple((len(rows)-1)*n+j for j in range(n)))
    return mesh(name,verts,faces,material)

def smooth_union(name,parts,voxel,material,smooth=4):
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=bpy.context.object;o.name=name
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    m=o.modifiers.new('Continuous sculpted surface','REMESH');m.mode='VOXEL';m.voxel_size=voxel;m.use_smooth_shade=True
    bpy.ops.object.modifier_apply(modifier=m.name)
    m=o.modifiers.new('Surface relaxation','SMOOTH');m.factor=.48;m.iterations=smooth
    bpy.ops.object.modifier_apply(modifier=m.name)
    o.data.materials.clear();o.data.materials.append(material)
    for p in o.data.polygons:p.use_smooth=True
    uv(o)
    return o

def make_rig(name,bones):
    bpy.ops.object.armature_add(enter_editmode=True,location=(0,0,0));o=bpy.context.object;o.name=name
    arm=o.data;arm.name=name+'_Skeleton';arm.edit_bones.remove(arm.edit_bones[0])
    for name,head,tail,parent in bones:
        b=arm.edit_bones.new(name);b.head=head;b.tail=tail
        if parent:b.parent=arm.edit_bones[parent]
        # Stable hinge axes are essential: Blender's default roll changes abruptly
        # around vertical axes and otherwise makes fingers splay when curled.
        b.align_roll(Vector((0,0,-1)) if o.name=='HandsRig' else Vector((0,1,0)))
    bpy.ops.object.mode_set(mode='OBJECT');o.show_in_front=True
    return o

def segment_distance(p,a,b):
    d=b-a;t=max(0,min(1,(p-a).dot(d)/max(d.length_squared,1e-8)))
    return (p-a-d*t).length

def skin(o,rig,bone_names=None,rigid=None):
    o.parent=rig
    if rigid:
        g=o.vertex_groups.new(name=rigid);g.add(list(range(len(o.data.vertices))),1,'REPLACE')
    else:
        bones=[b for b in rig.data.bones if b.name in bone_names]
        groups={b.name:o.vertex_groups.new(name=b.name) for b in bones}
        for v in o.data.vertices:
            p=o.matrix_world@v.co
            dist=sorted([(segment_distance(p,b.head_local,b.tail_local),b.name) for b in bones])[:3]
            weights=[1/max(d,.005)**5 for d,n in dist];total=sum(weights)
            for (d,n),w in zip(dist,weights):
                if w/total>.015:groups[n].add([v.index],w/total,'REPLACE')
    m=o.modifiers.new('Skin deformation','ARMATURE');m.object=rig

def bind_rigid(objects,rig,bone):
    for o in objects:skin(o,rig,rigid=bone);uv(o)

def skin_glove(o,rig,side):
    """Anatomical weights: rigid metacarpals, soft hinge zones, isolated digits."""
    o.parent=rig
    names=[f'Hand.{side}',f'Forearm.{side}']+[f'{d}.{i:02d}.{side}' for d in ['Thumb','Index','Middle','Ring','Pinky'] for i in range(1,4)]
    groups={n:o.vertex_groups.new(name=n) for n in names}
    sg=-1 if side=='L' else 1
    for v in o.data.vertices:
        p=o.matrix_world@v.co;x=p.x*sg;weights={}
        if p.y>-.450:
            a=max(0,min(1,(-p.y-.416)/.034));weights={f'Hand.{side}':a,f'Forearm.{side}':1-a}
        else:
            digit='Thumb' if x<.169 and p.y>-.551 else None
            if digit is None and p.y<-.528:
                digit=min(['Index','Middle','Ring','Pinky'],key=lambda d:segment_distance(p,rig.data.bones[f'{d}.01.{side}'].head_local,rig.data.bones[f'{d}.03.{side}'].tail_local))
            if digit is None:weights={f'Hand.{side}':1}
            else:
                bns=[rig.data.bones[f'{digit}.{i:02d}.{side}'] for i in range(1,4)]
                dist=[segment_distance(p,b.head_local,b.tail_local) for b in bns]
                w=[1/max(d,.004)**4 for d in dist];total=sum(w)
                if digit=='Thumb':blend=max(0,min(1,(.174-x)/.022))
                else:blend=max(0,min(1,(-p.y-.528)/.018))
                weights={b.name:a/total*blend for b,a in zip(bns,w)};weights[f'Hand.{side}']=1-blend
        for n,w in weights.items():
            if w>.001:groups[n].add([v.index],w,'REPLACE')
    m=o.modifiers.new('Anatomical glove skin','ARMATURE');m.object=rig

def make_action(rig,name,frames,poses):
    bpy.context.view_layer.objects.active=rig
    rig.animation_data_create();action=bpy.data.actions.new(name);rig.animation_data.action=action
    for f,pose in zip(frames,poses):
        for b in rig.pose.bones:
            b.rotation_mode='XYZ';b.rotation_euler=(0,0,0);b.location=(0,0,0)
        for name,val in pose.items():
            if name=='__root_location':rig.pose.bones['Root'].location=val
            elif name in rig.pose.bones:rig.pose.bones[name].rotation_euler=tuple(math.radians(x) for x in val)
        for b in rig.pose.bones:
            b.keyframe_insert('rotation_euler',frame=f);b.keyframe_insert('location',frame=f)
    action.use_fake_user=True
    for fc in action.fcurves:
        for kp in fc.keyframe_points:kp.interpolation='BEZIER'
    return action

def consolidate(objects,name):
    """One renderer with shared material slots, retaining all named skin groups."""
    for o in objects:
        bpy.context.view_layer.objects.active=o
        for modifier in list(o.modifiers):
            if modifier.type!='ARMATURE':bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join()
    result=bpy.context.object;result.name=name
    return [result]

def export(rig,objects,filename,rest_action):
    bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True)
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=rig
    rig.animation_data.action=bpy.data.actions.get(rest_action);bpy.context.scene.frame_set(1)
    bpy.ops.export_scene.fbx(filepath=str(OUT/filename),use_selection=True,object_types={'ARMATURE','MESH','EMPTY'},
        apply_unit_scale=True,apply_scale_options='FBX_SCALE_UNITS',axis_forward='-Z',axis_up='Y',
        add_leaf_bones=False,bake_anim=True,bake_anim_use_all_bones=True,bake_anim_use_nla_strips=False,
        bake_anim_use_all_actions=True,bake_anim_force_startend_keying=True,bake_anim_step=1,bake_anim_simplify_factor=.1,
        mesh_smooth_type='FACE',use_mesh_modifiers=True,path_mode='AUTO')
    source=OUT/filename.replace('.fbx','.blend')
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    # Unity auto-imports raw .blend files via an installed Blender; zip the source
    # so the portable Blender workflow and supplied FBX are deterministic.
    with zipfile.ZipFile(OUT/filename.replace('.fbx','.source.zip'),'w',zipfile.ZIP_DEFLATED) as z:z.write(source,source.name)
    source.unlink()
    backup=source.with_suffix('.blend1')
    if backup.exists():backup.unlink()

def lighting_camera(location,target,ortho,res=(1500,1500)):
    s=bpy.context.scene;s.render.resolution_x=res[0];s.render.resolution_y=res[1]
    world=bpy.data.worlds.new('Soft warm studio');world.use_nodes=True
    world.node_tree.nodes['Background'].inputs[0].default_value=(.16,.19,.24,1);world.node_tree.nodes['Background'].inputs[1].default_value=.45;s.world=world
    for name,loc,power,color,size in [('Large warm key',(-3,-4,4),550,(1,.83,.66),4),('Cool fill',(3,-2,2.3),260,(.68,.83,1),3),('Rim',(0,3,3),650,(1,.69,.36),3)]:
        d=bpy.data.lights.new(name,'AREA');d.energy=power;d.color=color;d.shape='DISK';d.size=size
        o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
    d=bpy.data.cameras.new('Art QA camera');o=bpy.data.objects.new('Art QA camera',d);bpy.context.collection.objects.link(o)
    o.location=location;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=ortho;s.camera=o
    return o

def render(name):
    bpy.context.scene.render.filepath=str(OUT/name);bpy.ops.render.render(write_still=True)

def hands():
    reset();s=bpy.context.scene
    glove=mat('Glove • warm ivory nitrile',(.88,.82,.66),.46,.1)
    shirt=mat('Sleeve • deep lagoon cotton',(.025,.19,.19),.83,.13)
    cuffmat=mat('Ribbed cuff',(.019,.115,.12),.87,.2)
    seam=mat('Raised glove seam',(.72,.67,.54),.58)
    bones=[('Root',(0,0,0),(0,0,.1),None)];objects=[];bone_lists={};finger_coords={}
    for side,sign in [('L',-1),('R',1)]:
        p=lambda x,y,z:(sign*x,y,z)
        shoulder=p(.24,.13,-.15);elbow=p(.285,-.13,-.37);wrist=p(.205,-.435,-.245);palm=p(.205,-.495,-.245)
        bones.extend([(f'UpperArm.{side}',shoulder,elbow,'Root'),(f'Forearm.{side}',elbow,wrist,f'UpperArm.{side}'),(f'Hand.{side}',wrist,p(.205,-.535,-.245),f'Forearm.{side}')])
        parts=[ellipsoid('Palm mass',palm,(.044,.064,.022),glove),tube('Wrist mass',[p(.205,-.41,-.245),wrist,p(.205,-.48,-.245)],[.027,.028,.035],glove,24,.8)]
        finger_names=[]
        for digit,x,ln in [('Index',.176,.080),('Middle',.198,.088),('Ring',.220,.082),('Pinky',.240,.063)]:
            start=Vector(p(x,-.536,-.245));spread=(x-.205)*.11
            pts=[start,start+Vector((sign*spread,-ln*.44,-.003)),start+Vector((sign*spread*1.3,-ln*.75,-.010)),start+Vector((sign*spread*1.5,-ln,-.020))]
            rad=.0095 if digit!='Pinky' else .0084
            parts.append(tube(digit+' continuous finger',pts,[rad*1.05,rad,rad*.84,rad*.56],glove,16))
            parts.append(ellipsoid(digit+' rounded fingertip',pts[-1],(rad*.56,rad*.65,rad*.56),glove,20,12))
            for k in range(3):
                name=f'{digit}.{k+1:02d}.{side}';parent=f'Hand.{side}' if k==0 else f'{digit}.{k:02d}.{side}'
                bones.append((name,pts[k],pts[k+1],parent));finger_names.append(name)
            finger_coords[side,digit]=pts
        pts=[Vector(p(.175,-.47,-.25)),Vector(p(.151,-.493,-.257)),Vector(p(.135,-.516,-.27)),Vector(p(.133,-.540,-.281))]
        parts.append(tube('Opposable thumb',pts,[.018,.014,.011,.008],glove,20));parts.append(ellipsoid('Thumb tip',pts[-1],(.008,.009,.008),glove,20,12))
        for k in range(3):
            name=f'Thumb.{k+1:02d}.{side}';bones.append((name,pts[k],pts[k+1],f'Hand.{side}' if k==0 else f'Thumb.{k:02d}.{side}'));finger_names.append(name)
        bones.append((f'Grip.{side}',p(.205,-.497,-.267),p(.205,-.547,-.267),f'Hand.{side}'))
        h=smooth_union('Continuous glove '+side,parts,.0023,glove,5);objects.append(h);bone_lists[h.name]=[f'Hand.{side}',f'Forearm.{side}']+finger_names
        # Sewn sleeves follow elbow with enough rings for natural articulation.
        pts=[Vector(shoulder).lerp(Vector(elbow),t) for t in [0,.15,.35,.55,.75,1]]+[Vector(elbow).lerp(Vector(wrist),t) for t in [.15,.32,.5,.65,.8,.9]]
        radii=[.077,.072,.067,.062,.059,.058,.055,.051,.047,.043,.037,.034]
        sleeve=tube('Tailored sleeve '+side,pts,radii,shirt,32,.9);uv(sleeve);objects.append(sleeve);bone_lists[sleeve.name]=[f'UpperArm.{side}',f'Forearm.{side}']
        end=Vector(elbow).lerp(Vector(wrist),.87);end2=Vector(elbow).lerp(Vector(wrist),.98)
        cuff=tube('Knitted cuff '+side,[end,end.lerp(end2,.15),end.lerp(end2,.85),end2],[.036,.036,.032,.031],cuffmat,32,.9);uv(cuff);objects.append(cuff);bone_lists[cuff.name]=[f'Forearm.{side}']
    rig=make_rig('HandsRig',bones)
    for o in objects:
        if o.name.startswith('Continuous glove'):skin_glove(o,rig,o.name[-1])
        else:skin(o,rig,bone_lists[o.name])
    objects=consolidate(objects,'BakerHands_Skinned')
    def curl(amount,side='R'):
        p={}
        for d in ['Index','Middle','Ring','Pinky']:
            for k in range(1,4):p[f'{d}.{k:02d}.{side}']=(amount*(.7 if k==1 else 1),0,0)
        for k in range(1,4):p[f'Thumb.{k:02d}.{side}']=(amount*.30,0,-amount*(.5 if k==1 else .22))
        return p
    idle={**curl(12,'R'),**curl(10,'L')}
    make_action(rig,'Hands_Idle',[1,46,91],[idle,{**idle,'Hand.R':(2,0,-2),'Hand.L':(-2,0,2)},idle])
    for clip,mid,duration in [
        ('Reach',{'UpperArm.R':(-12,1,-6),'Forearm.R':(18,0,0),'Hand.R':(-8,0,0),**curl(3)},.48),
        ('Grip',{'Hand.R':(0,0,0),**curl(64)},.35),
        ('Scoop',{'UpperArm.R':(-6,0,-12),'Forearm.R':(12,0,-5),'Hand.R':(28,-12,0),**curl(59)},.65),
        ('Pour',{'UpperArm.R':(4,0,-10),'Forearm.R':(15,0,0),'Hand.R':(-5,-57,0),**curl(62)},.7),
        ('Shake',{'Forearm.R':(13,0,0),'Hand.R':(22,0,0),**curl(65)},.32),
        ('Handoff',{'UpperArm.R':(-16,0,-5),'Forearm.R':(24,0,0),'Hand.R':(-6,0,0),**curl(18)},.65),
        ('PunchRapid',{'UpperArm.R':(-22,0,-10),'Forearm.R':(35,0,0),'Hand.R':(0,0,0),**curl(87)},.25)]:
        n=max(8,round(duration*30));make_action(rig,'Hands_'+clip,[1,round(n*.44),n],[idle,{**idle,**mid},idle])
    make_action(rig,'Hands_GripHold',[1,31],[{**idle,**curl(64)},{**idle,**curl(64)}])
    make_action(rig,'Hands_GripHoldLeft',[1,31],[{**idle,**curl(60,'L')},{**idle,**curl(60,'L')}])
    make_action(rig,'Hands_GripHoldBoth',[1,31],[{**idle,**curl(64),**curl(60,'L')},{**idle,**curl(64),**curl(60,'L')}])
    export(rig,objects,'BakerHands.fbx','Hands_Idle')
    rig.animation_data.action=bpy.data.actions['Hands_Idle'];s.frame_set(1)
    cam=lighting_camera((.9,-1.65,.73),(0,-.29,-.22),1.16,(1600,1200));render('QA_BakerHands.png')
    cam.location=(.38,-1.12,.1);cam.rotation_euler=(Vector((.205,-.52,-.25))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=.27
    s.render.resolution_x=1400;s.render.resolution_y=1400;render('QA_Glove_Detail.png')
    rig.animation_data.action=bpy.data.actions['Hands_GripHold'];s.frame_set(15);render('QA_Glove_Grip.png')
    return {'file':'BakerHands.fbx','mesh_vertices':sum(len(o.data.vertices) for o in objects),'bones':[b[0] for b in bones], 'clips':[a.name for a in bpy.data.actions]}

def customer():
    reset();s=bpy.context.scene
    skinmat=mat('Skin • warm terracotta',(.54,.285,.17),.57,.06)
    lipsmat=mat('Lips • muted rose',(.36,.126,.09),.56)
    shadowmat=mat('Mouth and nostril shadow',(.07,.026,.018),.9)
    hairmat=mat('Hair • espresso brown',(.039,.019,.012),.74,.065)
    browmat=mat('Brows • warm brown',(.063,.027,.016),.9)
    eyemat=mat('Eyes • ivory',(.89,.86,.77),.25)
    irismat=mat('Iris • hazel',(.13,.075,.026),.36)
    pupilmat=mat('Pupil',(.009,.006,.004),.23)
    gleammat=mat('Eye catchlight',(.95,.99,1),.08)
    jacket=mat('Overshirt • burnt saffron',(.55,.19,.047),.88,.16)
    jacketdark=mat('Overshirt seams',(.27,.075,.023),.9)
    tee=mat('T-shirt • oat milk',(.64,.58,.44),.89,.12)
    denim=mat('Trousers • midnight indigo',(.032,.056,.083),.88,.14)
    sole=mat('Sneaker sole • chalk',(.65,.65,.58),.83)
    shoe=mat('Sneaker canvas • charcoal',(.047,.059,.057),.87,.12)
    metal=mat('Buttons • horn',(.063,.044,.024),.37)
    # A lightly relaxed A-pose, fingers are all separate rigged continuous geometry.
    bones=[('Root',(0,0,0),(0,0,.12),None),('Hips',(0,0,.89),(0,0,1.04),'Root'),('Spine',(0,0,1.04),(0,0,1.24),'Hips'),('Chest',(0,0,1.24),(0,0,1.43),'Spine'),('Neck',(0,0,1.43),(0,0,1.54),'Chest'),('Head',(0,0,1.54),(0,0,1.76),'Neck')]
    for side,sg in [('L',-1),('R',1)]:
        p=lambda x,y,z:(x*sg,y,z)
        bones.extend([(f'Shoulder.{side}',p(.03,0,1.43),p(.185,0,1.43),'Chest'),(f'UpperArm.{side}',p(.185,0,1.43),p(.265,-.015,1.17),f'Shoulder.{side}'),(f'Forearm.{side}',p(.265,-.015,1.17),p(.295,-.06,.975),f'UpperArm.{side}'),(f'Hand.{side}',p(.295,-.06,.975),p(.302,-.07,.89),f'Forearm.{side}'),(f'Thigh.{side}',p(.10,0,.91),p(.11,-.015,.52),'Hips'),(f'Shin.{side}',p(.11,-.015,.52),p(.12,0,.12),f'Thigh.{side}'),(f'Foot.{side}',p(.12,0,.12),p(.12,-.14,.055),f'Shin.{side}')])
    objects=[];bindings={};rigid={}
    torso=loft('Tailored overshirt torso',[(.93,.16,.09,0),(.96,.178,.103,0),(1.06,.177,.105,0),(1.16,.165,.105,0),(1.27,.183,.113,0),(1.35,.189,.10,0),(1.39,.178,.091,0),(1.42,.132,.078,0),(1.438,.077,.065,0)],jacket)
    objects.append(torso);bindings[torso.name]=['Hips','Spine','Chest']
    # Front placket and real sewn pocket shapes, all body weighted.
    for z in [1.01,1.105,1.20,1.295,1.38]:
        o=ellipsoid('Horn button',(0,-.111,z),(.009,.004,.009),metal,20,12);objects.append(o);bindings[o.name]=['Spine','Chest']
    placket=mesh('Centre shirt placket',[(-.018,-.111,.955),(.018,-.111,.955),(.018,-.116,1.4),(-.018,-.116,1.4)],[(0,1,2,3)],jacket);objects.append(placket);bindings[placket.name]=['Spine','Chest']
    for sign in [-1,1]:
        x=sign*.108
        o=mesh('Chest patch pocket '+str(sign),[(x-.04,-.113,1.20),(x+.04,-.113,1.20),(x+.04,-.113,1.292),(x-.04,-.113,1.292)],[(0,1,2,3)],jacket);objects.append(o);bindings[o.name]=['Chest','Spine']
        line=tube('Pocket topstitch '+str(sign),[(x-.037,-.115,1.29),(x+.037,-.115,1.29)],[.0015,.0015],jacketdark,8);objects.append(line);bindings[line.name]=['Chest']
    # V-shaped collar leaves laid on the chest, with visible folded thickness.
    for sg in [-1,1]:
        verts=[(sg*.025,-.078,1.454),(sg*.086,-.071,1.45),(sg*.105,-.102,1.382),(sg*.055,-.124,1.35),(sg*.016,-.10,1.414)]
        o=mesh('Folded camp collar '+str(sg),verts,[(0,1,2,3,4)],jacket);sol=o.modifiers.new('Fold thickness','SOLIDIFY');sol.thickness=.004;objects.append(o);bindings[o.name]=['Chest']
    insert=loft('T-shirt neckline',[(1.39,.055,.068,0),(1.444,.052,.060,0),(1.451,.049,.055,0)],tee,40);objects.append(insert);rigid[insert.name]='Chest'
    neck=loft('Neck',[(1.43,.047,.046,.005),(1.49,.046,.045,.008),(1.55,.057,.052,.008)],skinmat,48);objects.append(neck);bindings[neck.name]=['Neck','Head']
    for side,sg in [('L',-1),('R',1)]:
        p=lambda x,y,z:(x*sg,y,z)
        sleeve=tube('Overshirt articulated sleeve '+side,[p(.158,0,1.368),p(.205,0,1.333),p(.234,-.005,1.27),p(.26,-.015,1.20),p(.272,-.025,1.13),p(.282,-.04,1.065),p(.287,-.045,1.035)],[.062,.068,.064,.06,.055,.049,.048],jacket,24,.94);objects.append(sleeve);bindings[sleeve.name]=[f'Shoulder.{side}',f'UpperArm.{side}',f'Forearm.{side}']
        cuff=tube('Folded sleeve cuff '+side,[p(.284,-.04,1.075),p(.288,-.046,1.045),p(.289,-.047,1.035)],[.051,.050,.048],jacketdark,32);objects.append(cuff);rigid[cuff.name]=f'Forearm.{side}'
        handparts=[tube('Wrist '+side,[p(.285,-.045,1.055),p(.295,-.06,.977),p(.301,-.068,.929)],[.031,.027,.034],skinmat,20),ellipsoid('Palm '+side,p(.3,-.07,.925),(.038,.023,.052),skinmat)]
        fingerbones=[]
        for digit,x,ln in [('Index',.273,.067),('Middle',.294,.073),('Ring',.314,.068),('Pinky',.332,.052)]:
            pts=[Vector(p(x,-.07,.89)),Vector(p(x,-.071,.89-ln*.44)),Vector(p(x,-.08,.89-ln*.76)),Vector(p(x,-.087,.89-ln))]
            rad=.0085 if digit!='Pinky' else .007
            handparts.append(tube(digit+side,pts,[rad,rad*.9,rad*.78,rad*.54],skinmat,12));handparts.append(ellipsoid(digit+'tip'+side,pts[-1],(rad*.58,rad*.58,rad*.58),skinmat,16,10))
            for k in range(3):
                n=f'{digit}.{k+1:02d}.{side}';bones.append((n,pts[k],pts[k+1],f'Hand.{side}' if k==0 else f'{digit}.{k:02d}.{side}'));fingerbones.append(n)
        pts=[Vector(p(.273,-.07,.95)),Vector(p(.252,-.075,.929)),Vector(p(.244,-.087,.904)),Vector(p(.25,-.094,.885))]
        handparts.append(tube('Customer thumb '+side,pts,[.015,.012,.009,.007],skinmat,16))
        for k in range(3):
            n=f'Thumb.{k+1:02d}.{side}';bones.append((n,pts[k],pts[k+1],f'Hand.{side}' if k==0 else f'Thumb.{k:02d}.{side}'));fingerbones.append(n)
        o=smooth_union('Continuous customer hand '+side,handparts,.0032,skinmat);objects.append(o);bindings[o.name]=[f'Forearm.{side}',f'Hand.{side}']+fingerbones
        leg=tube('Tapered trouser '+side,[p(.091,.005,.96),p(.10,0,.87),p(.107,0,.72),p(.111,-.015,.55),p(.113,-.01,.48),p(.118,0,.31),p(.12,0,.11)],[.093,.09,.079,.064,.063,.055,.049],denim,32,.96);objects.append(leg);bindings[leg.name]=['Hips',f'Thigh.{side}',f'Shin.{side}']
        so=ellipsoid('Sneaker sole '+side,p(.12,-.055,.044),(.064,.128,.034),sole,24,16);objects.append(so);rigid[so.name]=f'Foot.{side}'
        sh=ellipsoid('Canvas sneaker '+side,p(.12,-.045,.081),(.059,.115,.051),shoe,24,16);objects.append(sh);rigid[sh.name]=f'Foot.{side}'
        for i in range(4):
            z=.125-i*.003;y=-.047-i*.013
            lace=tube('Shoe lace '+side+str(i),[p(.09,y,z),p(.15,y-.008,z)],[.002,.002],sole,8);objects.append(lace);rigid[lace.name]=f'Foot.{side}'
    # Continuous sculpted head: controlled section rings and smooth analytic facial planes.
    rows=[(1.493,.026,.032,-.003),(1.505,.046,.043,-.006),(1.523,.063,.054,-.002),(1.545,.075,.061,.003),(1.568,.083,.067,.006),(1.592,.087,.071,.009),(1.616,.088,.073,.013),(1.64,.087,.073,.016),(1.664,.085,.074,.018),(1.69,.081,.073,.021),(1.715,.073,.067,.022),(1.737,.058,.056,.022),(1.752,.037,.037,.022),(1.758,.008,.008,.022)]
    verts=[];faces=[];N=96
    # Interpolate more rows for smooth nose, cheek and lip sculpting.
    dense=[]
    for a,b in zip(rows[:-1],rows[1:]):
        for k in range(4):dense.append(tuple(x+(y-x)*k/4 for x,y in zip(a,b)))
    dense.append(rows[-1])
    for z,rx,ry,cy in dense:
        for j in range(N):
            a=2*math.pi*j/N;x=rx*math.sin(a);y=cy-ry*math.cos(a);front=max(0,math.cos(a))**12
            # Bridge, alar wings and tip are built directly into the face surface.
            nose=.020*math.exp(-(x/.014)**2-((z-1.603)/.034)**2)+.026*math.exp(-(x/.019)**2-((z-1.579)/.013)**2)
            cheeks=.007*(math.exp(-((x-.046)/.027)**2)+math.exp(-((x+.046)/.027)**2))*math.exp(-((z-1.58)/.026)**2)
            muzzle=.009*math.exp(-(x/.033)**2-((z-1.55)/.021)**2)
            brow=.008*(math.exp(-((x-.032)/.028)**2)+math.exp(-((x+.032)/.028)**2))*math.exp(-((z-1.635)/.012)**2)
            sockets=.008*(math.exp(-((x-.035)/.020)**2)+math.exp(-((x+.035)/.020)**2))*math.exp(-((z-1.613)/.012)**2)
            y-=front*(nose+cheeks+muzzle+brow-sockets)
            cranial_z=1.66+(z-1.66)*.8 if z>1.66 else z
            verts.append((x,y,cranial_z))
    for i in range(len(dense)-1):
        for j in range(N):
            a=i*N+j;b=i*N+(j+1)%N;faces.append((a,b,b+N,a+N))
    faces.append(tuple(reversed(range(N))));faces.append(tuple((len(dense)-1)*N+j for j in range(N)))
    head=mesh('Sculpted continuous face and cranium',verts,faces,skinmat)
    objects.append(head);rigid[head.name]='Head'
    # Eyes are inset behind anatomically shaped lids, with subtle upward gaze.
    for sg in [-1,1]:
        x=sg*.0345
        eye=ellipsoid('Inset eyeball '+str(sg),(x,-.0547,1.6145),(.018,.012,.0082),eyemat,40,20);objects.append(eye);rigid[eye.name]='Head'
        iris=ellipsoid('Hazel iris '+str(sg),(x+sg*.0006,-.0666,1.615),(.0062,.0018,.0067),irismat,32,20);objects.append(iris);rigid[iris.name]='Head'
        pupil=ellipsoid('Pupil '+str(sg),(x+sg*.0006,-.0682,1.615),(.0028,.0007,.0032),pupilmat,28,16);objects.append(pupil);rigid[pupil.name]='Head'
        gleam=ellipsoid('Eye glint '+str(sg),(x-.0015,-.069,1.618),(.0013,.0005,.0013),gleammat,16,12);objects.append(gleam);rigid[gleam.name]='Head'
        for upper in [True,False]:
            pts=[]
            for k in range(17):
                t=k/16*math.pi;xx=x-.018*math.cos(t);zz=1.613+(math.sin(t)*(.0097 if upper else -.0065));yy=-.0595-.0055*math.sin(t)
                pts.append((xx,yy,zz))
            lid=tube(('Upper eyelid ' if upper else 'Lower eyelid ')+str(sg),pts,[.0019 if upper else .0016]*len(pts),skinmat,8);objects.append(lid);rigid[lid.name]='Head'
        pts=[]
        for k in range(13):
            t=k/12;pts.append((sg*(.015+.043*t),-.061+.012*t*t,1.635+.007*math.sin(math.pi*t)-.003*t))
        brow=tube('Tapered expressive eyebrow '+str(sg),pts,[.0012+.0017*math.sin(math.pi*k/12) for k in range(13)],browmat,10,.65);objects.append(brow);rigid[brow.name]='Head'
        nostril=ellipsoid('Nostril '+str(sg),(sg*.0105,-.084,1.574),(.0045,.0018,.0025),shadowmat,24,12);objects.append(nostril);rigid[nostril.name]='Head'
        ear=ellipsoid('Ear '+str(sg),(sg*.084,.005,1.596),(.014,.012,.024),skinmat,28,18);objects.append(ear);rigid[ear.name]='Head'
        inner=ellipsoid('Ear concha '+str(sg),(sg*.093,-.004,1.598),(.0045,.003,.010),lipsmat,20,12);objects.append(inner);rigid[inner.name]='Head'
        tragus=ellipsoid('Ear tragus '+str(sg),(sg*.090,-.009,1.593),(.004,.003,.006),skinmat,16,12);objects.append(tragus);rigid[tragus.name]='Head'
    # Soft closed smile: lip silhouette curves up at its ends, no pasted-on black line.
    mouthpts=[];upperpts=[];lowerpts=[]
    for k in range(25):
        x=-.027+k*.054/24;t=x/.027;z=1.547+.004*t*t;y=-.071+.009*t*t
        mouthpts.append((x,y-.0005,z));upperpts.append((x,y,z+.0024*(1-t*t)));lowerpts.append((x,y+.0005,z-.0027*(1-t*t)))
    for name,pts,r,ma in [('Smile crease',mouthpts,.00065,shadowmat),('Upper lip',upperpts,.0017,lipsmat),('Lower lip',lowerpts,.002,lipsmat)]:
        o=tube(name,pts,[r*(.25+.75*math.sin(math.pi*k/24)) for k in range(25)],ma,10,.62);objects.append(o);rigid[o.name]='Head'
    # Tailored hair cap with asymmetric swept silhouette; no intersecting sphere curls.
    hv=[];hf=[];rings=15;seg=64
    for i in range(rings):
        t=i/(rings-1)
        for j in range(seg):
            a=2*math.pi*j/seg
            front=max(0,math.cos(a));edge=1.615+.061*front+.008*math.sin(a)
            # True ellipsoid scalp, cropped along a natural asymmetric hairline.
            phi=(1-t)*math.acos(max(-1,min(1,(edge-1.658)/.117)))
            rx=.091*math.sin(phi);ry=.080*math.sin(phi);z=1.658+.117*math.cos(phi)
            x=rx*math.sin(a)+.005*math.cos(phi);y=.020-ry*math.cos(a)
            wave=.0018*math.sin(a*17+t*5)*math.sin(phi)
            z=1.645+(z-1.645)*.8 if z>1.645 else z
            hv.append((x+wave*math.sin(a),y-wave*math.cos(a),z))
    for i in range(rings-1):
        for j in range(seg):
            a=i*seg+j;b=i*seg+(j+1)%seg;hf.append((a,b,b+seg,a+seg))
    hair=mesh('Sculpted side swept hair',hv,hf,hairmat);objects.append(hair);rigid[hair.name]='Head'
    # Swept grooves catch the light as controlled ribbon-like locks over the cap.
    for k in range(12):
        a=-1.23+k*.19;pts=[]
        for j in range(14):
            t=j/13;aa=a+1.05*t
            edge=1.615+.061*max(0,math.cos(aa))+.008*math.sin(aa)
            phi=(1-t*.57)*math.acos(max(-1,min(1,(edge-1.658)/.117)))
            z=1.658+.118*math.cos(phi);z=1.645+(z-1.645)*.8 if z>1.645 else z
            pts.append((.092*math.sin(phi)*math.sin(aa)+.005*math.cos(phi),.020-.081*math.sin(phi)*math.cos(aa),z))
        o=tube('Swept hair lock '+str(k),pts,[.0007+.0006*math.sin(math.pi*j/13) for j in range(14)],hairmat,8,.55);objects.append(o);rigid[o.name]='Head'
    shells=[o for o in objects if o.name=='Tailored overshirt torso' or o.name.startswith('Overshirt articulated sleeve')]
    objects=[o for o in objects if o not in shells]
    for sg in [-1,1]:
        shells.append(ellipsoid('Rounded shoulder bridge '+str(sg),(sg*.145,0,1.38),(.086,.055,.052),jacket,28,18))
    shell=smooth_union('Continuous tailored overshirt',shells,.0065,jacket,8);objects.append(shell)
    # A soft shoulder envelope removes the high points created by capped sleeve
    # sweeps while retaining a naturally sloping neck-to-deltoid silhouette.
    for v in shell.data.vertices:
        ceiling=1.44-max(0,abs(v.co.x)-.08)*.30
        delta=ceiling-v.co.z
        v.co.z=ceiling-math.log1p(math.exp(min(200,delta*120)))/120
    soften=shell.modifiers.new('Rounded shoulder seam','SMOOTH');soften.factor=.42;soften.iterations=3
    bpy.context.view_layer.objects.active=shell
    bpy.ops.object.modifier_apply(modifier=soften.name)
    dec=shell.modifiers.new('Garment mesh reduction','DECIMATE');dec.ratio=.64
    bpy.ops.object.modifier_apply(modifier=dec.name)
    bindings[shell.name]=['Hips','Spine','Chest','Shoulder.L','UpperArm.L','Forearm.L','Shoulder.R','UpperArm.R','Forearm.R']
    rig=make_rig('CustomerRig',bones)
    for o in objects:
        uv(o)
        if o.name in rigid:skin(o,rig,rigid=rigid[o.name])
        else:skin(o,rig,bindings[o.name])
    objects=consolidate(objects,'Milo_Skinned')
    idle={'UpperArm.L':(0,-3,-2),'UpperArm.R':(0,3,2),'Head':(0,0,-2)}
    make_action(rig,'Customer_Idle',[1,46,91],[idle,{**idle,'Chest':(1.5,0,1),'Head':(-1,1,1)},idle])
    make_action(rig,'Customer_Order',[1,14,31,48],[idle,{**idle,'UpperArm.R':(-19,-3,-12),'Forearm.R':(-50,0,-5),'Hand.R':(12,0,0),'Head':(4,0,-2)},{**idle,'Forearm.R':(-45,0,3),'Hand.R':(-8,0,0),'Head':(0,0,2)},idle])
    make_action(rig,'Customer_Receive',[1,17,35,55],[idle,{**idle,'UpperArm.R':(-28,0,-6),'Forearm.R':(-48,0,0),'Hand.R':(8,0,0)}, {**idle,'UpperArm.R':(-22,0,-5),'Forearm.R':(-58,0,0),'Head':(8,0,0)},idle])
    make_action(rig,'Customer_Happy',[1,12,24,43,61],[idle,{**idle,'Chest':(-3,0,0),'Head':(8,0,0),'Forearm.R':(-32,0,0)}, {**idle,'Head':(-5,0,0),'Forearm.R':(-40,0,0)}, {**idle,'Head':(4,0,0)},idle])
    make_action(rig,'Customer_Impatient',[1,22,45,67,91],[idle,{**idle,'Head':(1,0,7),'Chest':(0,0,-3),'Foot.R':(8,0,0)}, {**idle,'Head':(-2,0,-4),'Foot.R':(0,0,0)}, {**idle,'Head':(1,0,4),'Foot.R':(9,0,0)},idle])
    make_action(rig,'Customer_ComicRecoil',[1,4,9,17,29,45],[idle,{'Chest':(-16,0,-5),'Neck':(-13,0,0),'Head':(-12,0,8),'UpperArm.L':(24,0,22),'UpperArm.R':(24,0,-22),'Forearm.L':(-30,0,0),'Forearm.R':(-30,0,0),'__root_location':(0,.10,.035)}, {'Chest':(-10,0,-3),'Head':(-6,0,3),'Thigh.L':(-15,0,0),'Thigh.R':(-15,0,0),'Shin.L':(25,0,0),'Shin.R':(25,0,0),'__root_location':(0,.22,.10)}, {'Chest':(8,0,0),'Thigh.L':(-16,0,0),'Thigh.R':(-16,0,0),'Shin.L':(23,0,0),'Shin.R':(23,0,0),'__root_location':(0,.27,0)}, {'Head':(5,0,-9),'__root_location':(0,.15,0)},idle])
    export(rig,objects,'Customer_Milo.fbx','Customer_Idle')
    rig.animation_data.action=bpy.data.actions['Customer_Idle'];s.frame_set(1)
    ground=mat('Studio background',(.13,.17,.18),.9)
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,0));bpy.context.object.data.materials.append(ground)
    cam=lighting_camera((2,-5,2.4),(0,0,.9),2.12,(1200,1600));render('QA_Customer_Full.png')
    cam.location=(.35,-1.5,1.72);cam.rotation_euler=(Vector((0,-.015,1.614))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=.43
    s.render.resolution_x=1400;s.render.resolution_y=1400;render('QA_Customer_Portrait.png')
    rig.animation_data.action=bpy.data.actions['Customer_Order'];s.frame_set(16)
    cam.location=(2,-5,2.4);cam.rotation_euler=(Vector((0,0,1.08))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=1.65
    render('QA_Customer_Order.png')
    return {'file':'Customer_Milo.fbx','height_metres':1.75,'mesh_vertices':sum(len(o.data.vertices) for o in objects),'bones':[b[0] for b in bones],'clips':[a.name for a in bpy.data.actions]}

def verify_export():
    report={}
    for filename in ['BakerHands.fbx','Customer_Milo.fbx']:
        reset();bpy.ops.import_scene.fbx(filepath=str(OUT/filename),use_anim=True)
        meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
        rigs=[o for o in bpy.context.scene.objects if o.type=='ARMATURE']
        points=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
        data={'mesh_count':len(meshes),'armatures':len(rigs),'bones':sum(len(o.data.bones) for o in rigs),
              'vertices':sum(len(o.data.vertices) for o in meshes),'materials':sum(len(o.data.materials) for o in meshes),
              'uv_meshes':sum(bool(o.data.uv_layers) for o in meshes),
              'unweighted_vertices':sum(not v.groups for o in meshes for v in o.data.vertices),
              'nonfinite_vertices':sum(not all(math.isfinite(x) for x in p) for p in points),
              'max_weights_per_vertex':max(len(v.groups) for o in meshes for v in o.data.vertices),
              'bounds_blender':{'min':[min(p[i] for p in points) for i in range(3)],'max':[max(p[i] for p in points) for i in range(3)]},
              'clips':[{'name':a.name,'frames':list(a.frame_range)} for a in bpy.data.actions]}
        assert data['mesh_count']==1 and data['armatures']==1, data
        assert data['unweighted_vertices']==0 and data['nonfinite_vertices']==0, data
        assert data['uv_meshes']==1 and data['max_weights_per_vertex']<=4, data
        assert len(data['clips'])>=6,data
        report[filename]=data
    (OUT/'fbx_roundtrip_verification.json').write_text(json.dumps(report,indent=2))
    print('FBX_ROUNDTRIP_VERIFIED '+json.dumps(report))

if __name__=='__main__' and '--verify-only' in sys.argv:
    verify_export()
elif __name__=='__main__':
    result=json.loads((OUT/'character_manifest.json').read_text()) if (OUT/'character_manifest.json').exists() else {}
    result.update({'license':'Original procedural artwork created for Golden Hour; no third-party assets.','axes':'Source Blender -Y forward, Z up. FBX export -Z forward/Y up, bake_space_transform=False. 1 unit = 1 metre. Verify imported root yaw in Unity; grip frame is derived from the hand geometry.'})
    if '--customer-only' not in sys.argv:result['hands']=hands()
    if '--hands-only' not in sys.argv:result['customer']=customer()
    (OUT/'character_manifest.json').write_text(json.dumps(result,indent=2))
    (OUT/'LICENSE.txt').write_text('Golden Hour character assets\n\nOriginal artwork authored procedurally in tools/unity/build_characters.py for this project.\nNo third-party meshes, textures, animations, or characters were used.\nMay be used, modified, redistributed, and commercially published with Golden Hour.\nBlender is a creation tool and does not impose its software license on generated artwork.\n')
    print('CHARACTERS_COMPLETE '+json.dumps(result))
