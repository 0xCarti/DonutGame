"""Golden Hour authored prop library. Run with Blender 4.5 --background --python.

All meshes are authored offline, bevelled, UV mapped and exported as FBX. Scale is
metres. Blender Z is vertical; exported FBX is Unity Y-up. A prop's origin is its
bottom contact point except the donut (centre) and moving machine components.
"""
import bpy, math, random, json, shutil, sys, hashlib
import numpy as np
from mathutils import Vector
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'unity/GoldenHour/Assets/Art/Props'
TEX = ROOT / 'unity/GoldenHour/Assets/Art/Textures'
SRC = ROOT / 'unity/GoldenHour/ArtSource'
QA = ROOT / 'playtest-reports/unity-assets'
for p in [OUT,TEX,SRC,QA]: p.mkdir(parents=True,exist_ok=True)

MINI_DONUT_DESCRIPTION = 'Gently irregular fried dough torus with a 5mm proof hole, darker crust and a light fried seam. Approximately 65mm diameter x 25.8mm high; centre pivot.'

def mini_donut_point(a,v):
    # Keep the proof hole open and the dome smooth. High-frequency radial and
    # vertical waves made the previous mesh read as a pleated dumpling.
    outer=(1+math.cos(v))*.5
    radius=.0175+.015*math.cos(v)
    radius+=(.00016*math.sin(3*a+.35)+.00010*math.cos(5*a-1.1))*outer
    radius+=.00006*math.sin(2*a+.4)*(1-outer)
    z=.0128*math.sin(v)*(1+.006*math.sin(3*a+.6))
    return (radius*math.cos(a),radius*math.sin(a),z)

if '--only-mini-donut' in sys.argv:
    def file_hash(path):return hashlib.sha256(path.read_bytes()).hexdigest()
    protected=[p for p in OUT.glob('*.fbx') if p.name!='MiniDonut.fbx']+[p for p in TEX.rglob('*') if p.is_file()]
    protected_hashes={str(p.relative_to(ROOT)):file_hash(p) for p in protected}
    manifest_path=OUT/'props_manifest.json'
    source_path=SRC/'GoldenHour_Props.blend'
    data=json.loads(manifest_path.read_text())
    other_entries={k:v for k,v in data.items() if k!='MiniDonut'}
    old_fbx_hash=file_hash(OUT/'MiniDonut.fbx')
    bpy.ops.wm.open_mainfile(filepath=str(source_path))
    donut=bpy.data.objects.get('MiniDonut_Body')
    if not donut or donut.type!='MESH' or len(donut.data.vertices)!=1280 or len(donut.data.polygons)!=1280:
        raise RuntimeError('MiniDonut_Body must retain the authored 64 x 20 torus topology.')
    if not donut.data.uv_layers:
        raise RuntimeError('MiniDonut must retain its authored UVs.')
    # Verify vertex ordering before changing coordinates, accepting both the old
    # and new shape so this narrow operation is safe to rerun.
    old_error=new_error=0
    for j in range(20):
        v=2*math.pi*j/20
        for i in range(64):
            a=2*math.pi*i/64
            wave=1+.035*math.sin(a*7)+.021*math.cos(a*11+v*3)
            radius=.0173+.0151*math.cos(v)*wave
            previous=Vector((radius*math.cos(a),radius*math.sin(a),.0125*math.sin(v)*(1+.04*math.sin(a*9))))
            vertex=donut.data.vertices[j*64+i]
            old_error=max(old_error,(vertex.co-previous).length)
            new_error=max(new_error,(vertex.co-Vector(mini_donut_point(a,v))).length)
    if min(old_error,new_error)>.000001:
        raise RuntimeError('Unexpected donut vertex order or source shape; no assets changed.')
    def mesh_signature(mesh,include_vertices=True):
        values=[]
        if include_vertices:values.append([tuple(v.co) for v in mesh.vertices])
        values.extend([[tuple(p.vertices) for p in mesh.polygons],[(p.material_index,p.use_smooth) for p in mesh.polygons],
                       [(layer.name,[tuple(loop.uv) for loop in layer.data]) for layer in mesh.uv_layers],
                       [m.name if m else None for m in mesh.materials]])
        return hashlib.sha256(repr(values).encode()).hexdigest()
    def other_objects_signature():
        return {o.name:(tuple(tuple(row) for row in o.matrix_world),mesh_signature(o.data) if o.type=='MESH' else o.type)
                for o in bpy.data.objects if o!=donut}
    other_objects=other_objects_signature()
    topology_uv_materials=mesh_signature(donut.data,False)
    states={o.name:(o.select_get(),o.hide_get(),o.hide_viewport,o.hide_render) for o in bpy.data.objects}
    previous_active=bpy.context.view_layer.objects.active
    for j in range(20):
        for i in range(64):donut.data.vertices[j*64+i].co=mini_donut_point(2*math.pi*i/64,2*math.pi*j/20)
    donut.data.update()
    assert mesh_signature(donut.data,False)==topology_uv_materials, 'Donut UVs, topology, or materials changed.'
    for o in bpy.context.view_layer.objects:o.select_set(False)
    donut.hide_set(False);donut.hide_viewport=False;donut.select_set(True);bpy.context.view_layer.objects.active=donut
    bpy.ops.export_scene.fbx(filepath=str(OUT/'MiniDonut.fbx'),use_selection=True,object_types={'MESH'},apply_unit_scale=True,apply_scale_options='FBX_SCALE_UNITS',axis_forward='-Z',axis_up='Y',bake_space_transform=True,use_mesh_modifiers=True,mesh_smooth_type='FACE',path_mode='STRIP',use_custom_props=True,add_leaf_bones=False,bake_anim=False)
    for name,(selected,hidden,viewport,render) in states.items():
        o=bpy.data.objects[name];o.hide_viewport=viewport;o.hide_render=render;o.select_set(selected);o.hide_set(hidden)
    bpy.context.view_layer.objects.active=previous_active
    assert other_objects_signature()==other_objects, 'An unrelated source object changed.'
    assert {o.name:(o.select_get(),o.hide_get(),o.hide_viewport,o.hide_render) for o in bpy.data.objects}==states, 'Source visibility or selection changed.'
    verts=[donut.matrix_world@v.co for v in donut.data.vertices]
    lo=[min(v[i] for v in verts) for i in range(3)];hi=[max(v[i] for v in verts) for i in range(3)]
    data['MiniDonut'].update(description=MINI_DONUT_DESCRIPTION,blenderBoundsMin=lo,blenderBoundsMax=hi,
        unitySize=[hi[0]-lo[0],hi[2]-lo[2],hi[1]-lo[1]],vertices=len(donut.data.vertices),
        triangles=sum(len(p.vertices)-2 for p in donut.data.polygons))
    assert {k:v for k,v in data.items() if k!='MiniDonut'}==other_entries
    manifest_path.write_text(json.dumps(data,indent=2))
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(source_path))
    changed=[name for name,digest in protected_hashes.items() if file_hash(ROOT/name)!=digest]
    if changed:raise RuntimeError('Protected assets changed: '+', '.join(changed))
    radii=[math.hypot(v.co.x,v.co.y) for v in donut.data.vertices[640:704]]
    report={'passed':True,'unitySizeMetres':data['MiniDonut']['unitySize'],
        'pinholeDiameterRangeMetres':[2*min(radii),2*max(radii)],'vertices':len(donut.data.vertices),
        'triangles':data['MiniDonut']['triangles'],'uvTopologyMaterialsUnchanged':True,
        'otherSourceObjectsUnchanged':len(other_objects),'otherFbxUnchanged':len([p for p in OUT.glob('*.fbx') if p.name!='MiniDonut.fbx']),
        'protectedFileCount':len(protected_hashes),'protectedSha256':protected_hashes,
        'previousFbxSha256':old_fbx_hash,'newFbxSha256':file_hash(OUT/'MiniDonut.fbx')}
    (QA/'mini-donut-refinement.json').write_text(json.dumps(report,indent=2))
    print('MINI_DONUT_REFINED',json.dumps({k:v for k,v in report.items() if k!='protectedSha256'}))
    sys.exit(0)

if '--verify-only' in sys.argv:
    expected=json.loads((OUT/'props_manifest.json').read_text());report={};failures=[]
    for name,info in expected.items():
        bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
        bpy.ops.import_scene.fbx(filepath=str(OUT/(name+'.fbx')))
        objects=[o for o in bpy.context.scene.objects if o.type=='MESH'];verts=[o.matrix_world@v.co for o in objects for v in o.data.vertices]
        size=[max(v[i] for v in verts)-min(v[i] for v in verts) for i in range(3)]
        expected_size=[info['unitySize'][0],info['unitySize'][2],info['unitySize'][1]]
        errors=[abs(a-b) for a,b in zip(size,expected_size)]
        missing_uv=[o.name for o in objects if len(o.data.uv_layers)==0]
        missing_parts=[n for n in info['movingParts'] if not any(o.name==n or o.name.startswith(n+'.') for o in objects)]
        valid=not missing_uv and not missing_parts and max(errors)<.0001
        report[name]={'passed':valid,'meshCount':len(objects),'uvMappedMeshes':len(objects)-len(missing_uv),'dimensionErrorMetres':max(errors),'movingPartsMissing':missing_parts,'materials':sorted({m.name for o in objects for m in o.data.materials})}
        if not valid:failures.append(name)
    (QA/'props-fbx-roundtrip.json').write_text(json.dumps(report,indent=2))
    print('FBX_ROUNDTRIP',json.dumps({'passed':not failures,'models':len(report),'failed':failures}))
    sys.exit(1 if failures else 0)
random.seed(24)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for m in list(bpy.data.materials): bpy.data.materials.remove(m)
scene=bpy.context.scene
scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1
bpy.context.preferences.filepaths.save_version=0
M={}; manifest={}; props={}; groups={}; current=None

# Fine original brushed-metal maps. Unlike broad surface-detail overlays these
# encode restrained micron-scale grain, which reads correctly in close-up.
rng=np.random.default_rng(41);sz=1024
grain=rng.normal(0,1,(sz,1))*.45+rng.normal(0,1,(sz,sz))*.15
def save_map(name,rgb):
    rgba=np.ones((sz,sz,4),dtype=np.float32);rgba[:,:,:3]=np.clip(rgb,0,1)
    image=bpy.data.images.new(name,width=sz,height=sz,alpha=True);image.colorspace_settings.name='Non-Color';image.pixels.foreach_set(rgba.ravel());image.filepath_raw=str(TEX/name);image.file_format='PNG';image.save();bpy.data.images.remove(image)
save_map('brushed_steel_color.png',np.repeat((.74+grain*.012)[:,:,None],3,axis=2))
save_map('brushed_steel_roughness.png',np.repeat((.27+grain*.018)[:,:,None],3,axis=2))
norm=np.ones((sz,sz,3),dtype=np.float32)*.5;norm[:,:,1]+=(np.roll(grain,1,axis=0)-grain)*.018;norm[:,:,2]=1
save_map('brushed_steel_normal.png',norm)
# Original cylindrical crust map: small pores, uneven fry color, and a lighter
# proof seam on the outer equator. UV v follows the donut's cross-section.
yy,xx=np.mgrid[0:sz,0:sz];uu=xx/sz*2*math.pi;vv=yy/sz*2*math.pi
seam=np.exp(-(np.sin(vv)/.19)**2)*np.clip(np.cos(vv),0,1)
freckle=rng.normal(0,1,(sz,sz))*.018+.012*np.sin(uu*17+np.sin(vv*9))
crust=np.stack([.75+freckle+.08*seam,.385+freckle*.65+.13*seam,.102+freckle*.3+.065*seam],axis=2)
save_map('donut_crust_color.png',crust)
save_map('donut_crust_roughness.png',np.repeat((.62+freckle*.8)[:,:,None],3,axis=2))

def material(name,color,metal=0,rough=.5,texture=None,normal=None,roughmap=None):
    m=bpy.data.materials.new('GH_'+name); m.use_nodes=True
    m.diffuse_color=(*color,1); m.metallic=metal; m.roughness=rough
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
    for fn,socket,typ in [(texture,'Base Color','color'),(normal,'Normal','normal'),(roughmap,'Roughness','roughness')]:
        if fn:
            n=m.node_tree.nodes.new('ShaderNodeTexImage'); n.image=bpy.data.images.load(str(TEX/fn),check_existing=True)
            if typ!='color': n.image.colorspace_settings.name='Non-Color'
            if typ=='normal':
                nm=m.node_tree.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.22
                m.node_tree.links.new(n.outputs['Color'],nm.inputs['Color']);m.node_tree.links.new(nm.outputs['Normal'],p.inputs[socket])
            elif typ=='color' and (fn.startswith('detail_') or fn.startswith('brushed_')):
                mix=m.node_tree.nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.inputs[2].default_value=(*color,1)
                m.node_tree.links.new(n.outputs['Color'],mix.inputs[1]);m.node_tree.links.new(mix.outputs[0],p.inputs[socket])
            else: m.node_tree.links.new(n.outputs['Color'],p.inputs[socket])
            if typ=='color' and name=='BrandSeal':
                m.node_tree.links.new(n.outputs['Alpha'],p.inputs['Alpha']);m.surface_render_method='DITHERED'
    M[name]=m
    shader_tint=(1,1,1) if texture and not (texture.startswith('detail_') or texture.startswith('brushed_')) else color
    manifest[m.name]={'color':list(shader_tint)+[1],'metallic':metal,'roughness':rough,'albedo':texture,'normal':normal,'roughnessMap':roughmap,'alphaClip':name=='BrandSeal'}
    return m

material('Steel',(.55,.61,.62),.88,.27,'brushed_steel_color.png','brushed_steel_normal.png','brushed_steel_roughness.png')
material('SteelDark',(.14,.18,.18),.85,.32)
material('Rubber',(.019,.025,.024),.0,.8)
material('Brass',(.66,.39,.12),.72,.28)
material('Teal',(.025,.17,.18),.2,.33)
material('Cream',(.88,.79,.57),.05,.58)
material('Red',(.42,.035,.035),.08,.38)
material('Wood',(.45,.2,.08),0,.5,'counter_wood_color.png','counter_wood_normal.png','counter_wood_roughness.png')
material('Paper',(.59,.33,.12),0,.8,'kraft_paper_color.png','kraft_paper_normal.png','kraft_paper_roughness.png')
material('Dough',(1,1,1),0,.62,'donut_crust_color.png','detail_dough_normal.png','donut_crust_roughness.png')
material('Oil',(.24,.10,.015),.3,.1)
material('Batter',(.88,.65,.34),0,.44)
material('CanvasCream',(.84,.76,.56),0,.85,'detail_canvas_color.png','detail_canvas_normal.png','detail_canvas_roughness.png')
material('CanvasRed',(.38,.045,.04),0,.86)
material('LabelCinnamon',(1,1,1),0,.65,'shaker_cinnamon.png')
material('LabelPowdered',(1,1,1),0,.65,'shaker_powdered.png')
material('BrandSeal',(1,1,1),0,.75,'brand_seal.png')
material('CounterSign',(1,1,1),0,.45,'counter_sign.png')
material('Warning',(.97,.48,.04),.1,.45)
material('Lamp',(.95,.65,.25),.2,.18)
emit=M['Lamp'].node_tree.nodes.get('Principled BSDF');emit.inputs['Emission Color'].default_value=(1,.46,.12,1);emit.inputs['Emission Strength'].default_value=2

def begin(name):
    global current
    current=name; groups[name]=[]

def track(o,name,mat):
    o.name=name
    if mat: o.data.materials.append(M[mat])
    if current:groups[current].append(o)
    return o

def active(o):
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o

def bevel(o,w=.005,segments=3):
    mod=o.modifiers.new('Manufactured edge radii','BEVEL');mod.width=w;mod.segments=segments
    mod.affect='EDGES'
    mod=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL');mod.keep_sharp=True;mod.weight=50
    return o

def cube(n,loc,size,mat,bev=.003,rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=track(bpy.context.object,n,mat);o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if rot:o.rotation_euler=rot
    if bev:bevel(o,bev)
    return o

def uv(o):
    if o.type=='MESH' and not o.data.uv_layers:
        active(o);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.015);bpy.ops.object.mode_set(mode='OBJECT')

def mesh(n,verts,faces,mat,uvs=None,smooth=False):
    data=bpy.data.meshes.new(n);data.from_pydata(verts,[],faces);data.update();o=bpy.data.objects.new(n,data);bpy.context.collection.objects.link(o);track(o,n,mat)
    if uvs:
        lay=data.uv_layers.new(name='UVMap')
        for poly,coords in zip(data.polygons,uvs):
            for li,co in zip(poly.loop_indices,coords):lay.data[li].uv=co
    for p in data.polygons:p.use_smooth=smooth
    return o

def lathe(n,profile,mat,loc=(0,0,0),segments=64,cap=False):
    vs=[];fs=[];tex=[]
    for r,z in profile:
        for i in range(segments):
            a=i*2*math.pi/segments;vs.append((r*math.cos(a)+loc[0],r*math.sin(a)+loc[1],z+loc[2]))
    for j in range(len(profile)-1):
        for i in range(segments):
            k=(i+1)%segments;fs.append((j*segments+i,j*segments+k,(j+1)*segments+k,(j+1)*segments+i))
            tex.append(((i/segments,j/(len(profile)-1)),((i+1)/segments,j/(len(profile)-1)),((i+1)/segments,(j+1)/(len(profile)-1)),(i/segments,(j+1)/(len(profile)-1))))
    if cap:
        fs.extend([tuple(reversed(range(segments))),tuple((len(profile)-1)*segments+i for i in range(segments))]);tex.extend([tuple((.5+.5*math.cos(i*2*math.pi/segments),.5+.5*math.sin(i*2*math.pi/segments)) for i in reversed(range(segments))),tuple((.5+.5*math.cos(i*2*math.pi/segments),.5+.5*math.sin(i*2*math.pi/segments)) for i in range(segments))])
    return mesh(n,vs,fs,mat,tex,True)

def cylinder(n,loc,r,depth,mat,axis='Z',vertices=48,bev=.002):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=loc);o=track(bpy.context.object,n,mat)
    if axis=='X':o.rotation_euler.y=math.pi/2
    if axis=='Y':o.rotation_euler.x=math.pi/2
    for p in o.data.polygons:p.use_smooth=True
    if bev:bevel(o,bev,3)
    return o

def sphere(n,loc,scale,mat,segments=32,rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1,location=loc);o=track(bpy.context.object,n,mat);o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for p in o.data.polygons:p.use_smooth=True
    return o

def torus(n,loc,major,minor,mat,axis='Z'):
    bpy.ops.mesh.primitive_torus_add(major_radius=major,minor_radius=minor,major_segments=64,minor_segments=12,location=loc);o=track(bpy.context.object,n,mat)
    if axis=='Y':o.rotation_euler.x=math.pi/2
    if axis=='X':o.rotation_euler.y=math.pi/2
    for p in o.data.polygons:p.use_smooth=True
    return o

def tube(n,points,r,mat,res=4):
    c=bpy.data.curves.new(n,'CURVE');c.dimensions='3D';c.bevel_depth=r;c.bevel_resolution=res;c.resolution_u=16
    s=c.splines.new('BEZIER');s.bezier_points.add(len(points)-1)
    for p,v in zip(s.bezier_points,points):p.co=v;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
    o=bpy.data.objects.new(n,c);bpy.context.collection.objects.link(o);track(o,n,mat)
    active(o);bpy.ops.object.convert(target='MESH');return o

def rod(n,a,b,r,mat):
    d=Vector(b)-Vector(a);o=cylinder(n,(Vector(a)+Vector(b))/2,r,d.length,mat,bev=.001);o.rotation_euler=d.to_track_quat('Z','Y').to_euler();return o

def screw(loc,axis='Y',r=.006):
    cylinder('Cross head screw',loc,r,.003,'SteelDark',axis,24,.001)
    x,y,z=loc
    if axis=='Y':
        cube('Screw slot',(x,y-.002,z),(r*1.3,.001,r*.18),'Rubber',0);cube('Screw slot',(x,y-.002,z),(r*.18,.001,r*1.3),'Rubber',0)
    else:cube('Screw slot',(x,y,z+.002),(r*1.3,r*.18,.001),'Rubber',0)

def label(n,center,w,h,mat,axis='Y'):
    x,y,z=center
    if axis=='Y':vs=[(x-w/2,y,z-h/2),(x+w/2,y,z-h/2),(x+w/2,y,z+h/2),(x-w/2,y,z+h/2)]
    else:vs=[(x-w/2,y-h/2,z),(x+w/2,y-h/2,z),(x+w/2,y+h/2,z),(x-w/2,y+h/2,z)]
    return mesh(n,vs,[(0,1,2,3)],mat,[[(0,0),(1,0),(1,1),(0,1)]])

def text(n,body,loc,size,mat,rot=(math.pi/2,0,0),align='CENTER'):
    data=bpy.data.curves.new(n,'FONT');data.body=body;data.size=size;data.align_x=align;data.align_y='CENTER';data.extrude=.0001;data.bevel_depth=0;data.resolution_u=4
    ob=bpy.data.objects.new(n,data);bpy.context.collection.objects.link(ob);ob.location=loc;ob.rotation_euler=rot;track(ob,n,mat);active(ob);bpy.ops.object.convert(target='MESH');return ob

def moving(ob,name,origin):
    active(ob);bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    ob.name=name
    ob['moving_part']=name
    active(ob);scene.cursor.location=origin;bpy.ops.object.origin_set(type='ORIGIN_CURSOR');scene.cursor.location=(0,0,0)
    return ob

def rounded_rect_loop(w,d,r,z,n=10):
    pts=[]
    for cx,cy,start in [(w/2-r,d/2-r,0),(-w/2+r,d/2-r,90),(-w/2+r,-d/2+r,180),(w/2-r,-d/2+r,270)]:
        for i in range(n):
            a=math.radians(start+i*90/(n-1));pts.append((cx+r*math.cos(a),cy+r*math.sin(a),z))
    return pts

def pan(n,w,d,h,mat,loc=(0,0,0),thick=.003,r=.035):
    profiles=[(w-.025,d-.025,r*.6,thick),(w-.016,d-.016,r*.8,h*.75),(w,d,r,h),(w,d,r,h+.003),(w-.008,d-.008,r-.004,h+.004),(w-.014,d-.014,r-.007,h-.004),(w-.03,d-.03,r*.55,.008)]
    loops=[rounded_rect_loop(a,b,c,z) for a,b,c,z in profiles];v=[(x+loc[0],y+loc[1],z+loc[2]) for loop in loops for x,y,z in loop];k=len(loops[0]);f=[]
    for j in range(len(loops)-1):
        for i in range(k):f.append((j*k+i,j*k+(i+1)%k,(j+1)*k+(i+1)%k,(j+1)*k+i))
    # The visible interior floor points upward (important for Unity backface culling).
    f.append(tuple((len(loops)-1)*k+i for i in range(k)))
    o=mesh(n,v,f,mat,smooth=True);uv(o);return o

def export(name,desc):
    objs=groups[name]
    # Apply modelling modifiers and convert all authored parts to meshes.
    for o in objs:
        active(o)
        for mod in list(o.modifiers):
            try:bpy.ops.object.modifier_apply(modifier=mod.name)
            except RuntimeError:pass
        uv(o)
    # Combine static parts to a single multimat mesh; moving parts retain pivots.
    static=[o for o in objs if not o.get('moving_part')]
    moving_parts=[o for o in objs if o.get('moving_part')]
    active(static[0])
    for o in static:o.select_set(True)
    bpy.ops.object.join();body=bpy.context.object;body.name=name+'_Body'
    scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    final=[body]+moving_parts
    for o in final:
        o.data.validate();o.data.update()
    bpy.ops.object.select_all(action='DESELECT')
    for o in final:o.select_set(True)
    bpy.context.view_layer.objects.active=body
    bpy.ops.export_scene.fbx(filepath=str(OUT/(name+'.fbx')),use_selection=True,object_types={'MESH'},apply_unit_scale=True,apply_scale_options='FBX_SCALE_UNITS',axis_forward='-Z',axis_up='Y',bake_space_transform=True,use_mesh_modifiers=True,mesh_smooth_type='FACE',path_mode='STRIP',use_custom_props=True,add_leaf_bones=False,bake_anim=False)
    verts=[o.matrix_world@v.co for o in final for v in o.data.vertices]
    lo=[min(v[i] for v in verts) for i in range(3)];hi=[max(v[i] for v in verts) for i in range(3)]
    props[name]={'description':desc,'blenderBoundsMin':lo,'blenderBoundsMax':hi,'unitySize':[hi[0]-lo[0],hi[2]-lo[2],hi[1]-lo[1]],'vertices':sum(len(o.data.vertices) for o in final),'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in final),'materials':sorted({m.name for o in final for m in o.data.materials}),'movingParts':[o.name for o in final if o.get('moving_part')]}
    groups[name]=final
    for o in final:o.hide_render=True;o.hide_set(True)
    print('PROP_EXPORTED',name,json.dumps(props[name]))

# ---- Long-channel continuous mini donut fryer, based on the user's reference. ----
begin('Fryer')
for x in [-.65,.59]:
    for y in [-.175,.175]:
        cylinder('Adjustable rubber foot',(x,y,.022),.024,.044,'Rubber');cylinder('Threaded foot stem',(x,y,.047),.011,.025,'SteelDark')
cube('Lower stainless casing',(0,0,.125),(1.46,.43,.16),'Steel',.014)
pan('Rolled lip open frying channel',1.45,.42,.12,'Steel',loc=(0,0,.14),r=.045)
cube('Oil surface',(0,0,.222),(1.38,.344,.009),'Oil',.025)
for y in [-.222,.222]:cube('Rolled long rim',(0,y,.262),(1.48,.016,.019),'Steel',.007)
for x in [-.73,.73]:cube('End rim',(x,0,.262),(.015,.44,.019),'Steel',.006)
# Drain valve and curved supply / power cables.
cylinder('Drain valve body',(-.54,-.232,.112),.022,.035,'Brass','Y');rod('Drain handle',(-.59,-.254,.13),(-.49,-.254,.13),.007,'Red')
tube('Power cable',[(-.58,.215,.1),(-.72,.27,.06),(-.81,.2,.018),(-.74,.09,.012)],.008,'Rubber')
for x in [-.64,-.31,.04,.39,.66]:screw((x,-.217,.17))
# Motor housing behind hopper with stamped ventilation ribs.
cube('Drive enclosure',(-.57,.035,.36),(.27,.37,.18),'Steel',.014)
for z in [.32,.35,.38]:cube('Stamped vent recess',(-.586,-.156,z),(.17,.006,.013),'SteelDark',.004)
cube('Control panel bezel',(-.555,-.24,.352),(.244,.09,.19),'SteelDark',.009)
cube('Cream enamel control face',(-.555,-.288,.352),(.226,.007,.172),'Cream',.006)
text('Fryer manufacturer plate','GOLDEN HOUR',(-.555,-.294,.416),.018,'Teal')
text('Temperature label','OIL TEMPERATURE',(-.555,-.294,.388),.011,'Teal')
cylinder('Thermostat dial bezel',(-.6,-.3,.346),.031,.009,'Brass','Y')
heat_parts=[cylinder('Thermostat knob',(-.6,-.312,.346),.021,.023,'Rubber','Y'),cube('Dial index',(-.6,-.325,.361),(.003,.003,.014),'Cream',.001)]
groups[current]=[o for o in groups[current] if o not in heat_parts];active(heat_parts[0])
for o in heat_parts:o.select_set(True)
bpy.ops.object.join();heat_knob=bpy.context.object;groups[current].append(heat_knob);moving(heat_knob,'HeatDial',(-.6,-.312,.346))
cylinder('Speed dial bezel',(-.49,-.30,.346),.027,.009,'Brass','Y')
speed_parts=[cylinder('Conveyor speed knob',(-.49,-.312,.346),.019,.023,'Teal','Y'),cube('Speed dial index',(-.49,-.325,.359),(.003,.003,.012),'Cream',.001)]
groups[current]=[o for o in groups[current] if o not in speed_parts];active(speed_parts[0])
for o in speed_parts:o.select_set(True)
bpy.ops.object.join();speed_knob=bpy.context.object;groups[current].append(speed_knob);moving(speed_knob,'SpeedDial',(-.49,-.312,.346))
for i in range(11):
    a=math.radians(-50+i*28);x=-.6+math.sin(a)*.039;z=.346+math.cos(a)*.039
    cube('Engraved thermostat tick',(x,-.295,z),(.002,.001,.005),'Teal',0,rot=(0,a,0))
for x,mat in [(-.514,'Red'),(-.468,'Teal')]:
    cylinder('Power button surround',(x,-.299,.301),.008,.008,'Steel','Y');cylinder('Power button',(x,-.307,.301),.005,.012,mat,'Y')
text('Control labels','HEAT         SPEED',(-.55,-.294,.31),.009,'Teal')
for x in [-.657,-.453]:
    for z in [.282,.422]:screw((x,-.295,z),r=.004)
# Hopper conical shell with actual wall thickness and visible dough fill.
hx=-.51;hy=.015
lathe('Hopper drawn stainless steel',[(.036,.4),(.041,.425),(.055,.44),(.137,.60),(.145,.625),(.145,.79),(.15,.796),(.15,.806),(.144,.81),(.138,.8),(.138,.628),(.13,.61),(.049,.443),(.031,.423)],'Steel',(hx,hy,0),80)
torus('Hopper rolled rim',(hx,hy,.805),.146,.006,'Steel')
lathe('Visible batter in hopper',[(0,.738),(.134,.738),(.135,.74)],'Batter',(hx,hy,0),64)
rod('Hopper support left',(-.70,.13,.43),(-.70,.13,.80),.012,'Steel')
rod('Hopper bridge',(-.70,.13,.80),(-.51,.13,.80),.012,'Steel')
cube('Cutter drive motor',(-.51,.12,.87),(.13,.12,.13),'Steel',.009)
cylinder('Drive motor rear vent',(-.51,.183,.87),.048,.009,'SteelDark','Y')
for i in range(7):cube('Motor cooling grille',(-.51+(i-3)*.011,.189,.87),(.004,.003,.071-abs(i-3)*.009),'Rubber',.001)
plunger=rod('Plunger',(-.51,.015,.405),(-.51,.015,.88),.009,'SteelDark');moving(plunger,'Plunger',(-.51,.015,.4))
cylinder('Cutter ring',(-.51,.015,.40),.034,.027,'Steel')
# Thin channel guide rails, flipper fingers and axle.
for y in [-.129,.129]:rod('Oil lane guide',(-.34,y,.239),(.42,y,.239),.003,'Steel')
flips=[]
flips.append(cylinder('Flipper axle',(.025,0,.267),.008,.38,'SteelDark','Y'))
for y in [-.105,-.035,.035,.105]:
    flips.append(cube('Flipper finger',(.025,y,.262),(.142,.015,.009),'Steel',.003,rot=(0,.14,0)))
active(flips[0])
for o in flips:o.select_set(True)
groups[current]=[o for o in groups[current] if o not in flips]
bpy.ops.object.join();flipper=bpy.context.object;flipper.name='Flipper';groups[current].append(flipper);moving(flipper,'Flipper',(.025,0,.267))
# Inclined conveyor, with two rails and stamped crosswise cleats.
theta=math.radians(-23)
conv=cube('Conveyor',(.54,0,.31),(.34,.255,.014),'SteelDark',.005,rot=(0,theta,0));moving(conv,'Conveyor',(.39,0,.245))
for y in [-.143,.143]:
    rod('Conveyor side rail',(.38,y,.25),(.72,y,.394),.012,'Steel')
    rod('Conveyor guard upright',(.72,y,.39),(.72,y,.5),.006,'SteelDark')
rod('Conveyor guard cross bar',(.72,-.143,.5),(.72,.143,.5),.006,'SteelDark')
for i in range(13):
    x=.39+i*.025;z=.259+i*.0106
    cube('Conveyor perforated cleat',(x,0,z),(.009,.25,.008),'Steel',.002,rot=(0,theta,0))
for x,z in [(.38,.252),(.72,.395)]:cylinder('Conveyor roller',(x,0,z),.017,.29,'Steel','Y')
cube('Output slide',(.795,0,.36),(.19,.27,.009),'Steel',.004,rot=(0,.42,0))
for y in [-.135,.135]:cube('Chute folded side',(.795,y,.377),(.19,.009,.038),'Steel',.003,rot=(0,.42,0))
cube('Safety hot surface decal',(.20,-.221,.122),(.13,.001,.047),'Cream',.001)
text('Hot caution label','CAUTION  HOT',(.20,-.223,.122),.014,'Red')
export('Fryer','Continuous mini donut fryer: open channel, batter hopper, control face, flipper and rising conveyor. Metres; bottom at zero. Plunger vertical; Flipper local X axis after FBX conversion should be inspected in importer.')

# ---- Counter, including genuinely recessed waste opening. ----
begin('Counter')
cube('Operator front panel',(0,-.351,.435),(3.48,.035,.82),'Teal',.012)
for x in [-1.722,1.722]:cube('Counter end panel',(x,0,.435),(.036,.73,.82),'Teal',.009)
cube('Interior cabinet bottom',(0,0,.045),(3.48,.73,.035),'Teal',.006)
cube('Rear customer panel',(0,.38,.44),(3.51,.035,.82),'Teal',.009)
for x in [-1.72,-.86,0,.86,1.72]:cube('Raised panel stile',(x,.406,.44),(.035,.025,.81),'Brass',.004)
for z in [.065,.82]:cube('Raised panel rail',(0,.408,z),(3.48,.028,.026),'Brass',.004)
for x in [-1.55,1.55]:
    for y in [-.3,.3]:cube('Counter foot',(x,y,.028),(.17,.14,.056),'Rubber',.01)
# Worktop with square opening rather than dark surface graphic.
cube('Main butcher block',(-.275,0,.883),(3.05,.87,.05),'Wood',.014)
cube('Waste outer worktop',(1.76,0,.883),(.08,.87,.05),'Wood',.012)
cube('Waste rear worktop',(1.48,.30,.883),(.48,.27,.05),'Wood',.012)
cube('Waste front worktop',(1.48,-.30,.883),(.48,.27,.05),'Wood',.012)
pan('Inset waste collar',.42,.30,.025,'Steel',loc=(1.485,0,.884),r=.035)
# Remove pan bottom to reveal depth.
o=groups[current][-1];active(o);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='DESELECT');bpy.ops.object.mode_set(mode='OBJECT');o.data.polygons[-1].select=True;bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.delete(type='ONLY_FACE');bpy.ops.object.mode_set(mode='OBJECT')
cube('Waste well floor',(1.485,0,.64),(.385,.265,.01),'Rubber',.006)
for y in [-.135,.135]:cube('Waste well lining',(1.485,y,.765),(.385,.008,.25),'SteelDark',.002)
for x in [1.29,1.68]:cube('Waste well lining',(x,0,.765),(.008,.27,.25),'SteelDark',.002)
for x in [-1.65,-1.1,-.55,0,.55,1.10]:cube('Butcher block seam',(x,0,.909),(.0012,.825,.0004),'SteelDark',0)
cube('Counter protective front rail',(0,-.44,.865),(3.6,.017,.035),'Brass',.005)
# Real panel frames and fasteners.
for x in [-1.12,0,1.12]:
    cube('Operator drawer face',(x,-.374,.72),(1.05,.025,.20),'Teal',.008)
    rod('Drawer handle left',(x-.12,-.4,.72),(x-.12,-.43,.72),.006,'Brass');rod('Drawer pull',(x-.12,-.43,.72),(x+.12,-.43,.72),.008,'Brass');rod('Drawer handle right',(x+.12,-.43,.72),(x+.12,-.4,.72),.006,'Brass')
export('Counter','3.6m butcher block service counter. Top Y=.908m. Teal panelled base, brass trim, drawers, recessed waste opening at local X=1.485m.')

begin('Tray');pan('Rolled stainless bakery tray',.46,.32,.045,'Steel',r=.032)
for x in [-.224,.224]:cube('Tray grip flange',(x,0,.027),(.018,.13,.012),'Steel',.005)
export('Tray','Rolled-edge bakery tray, floor pivot; .46 x .32 metres.')

# ---- Scoop: genuine concave curved bowl, taper, rolled lip, riveted wooden handle. ----
begin('Scoop')
vs=[];fs=[]
for j in range(13):
    y=-.10+j*.015
    for i in range(21):
        a=math.pi+i*math.pi/20;r=.052*(1-.13*j/12)
        vs.append((r*math.cos(a),y,.051+r*math.sin(a)))
for j in range(12):
    for i in range(20):k=j*21+i;fs.append((k,k+1,k+22,k+21))
o=mesh('Concave pressed scoop',vs,fs,'Steel',smooth=True);s=o.modifiers.new('Pressed metal thickness','SOLIDIFY');s.thickness=.002;bevel(o,.0015,3)
tube('Scoop rolled lip',[(.052*math.cos(math.pi+i*math.pi/12),-.10,.051+.052*math.sin(math.pi+i*math.pi/12)) for i in range(13)],.0022,'Steel')
mesh('Scoop back wall',[(-.045,.08,.051),(0,.08,.004),(.045,.08,.051),(.028,.08,.064),(-.028,.08,.064)],[(0,1,2,3,4)],'Steel')
rod('Handle steel neck',(0,.07,.048),(0,.125,.066),.009,'Steel')
o=cylinder('Oiled wooden scoop handle',(0,.172,.075),.014,.12,'Wood','Y',48,.008);o.rotation_euler.x=math.pi/2-.12
torus('Handle brass ferrule',(0,.118,.068),.013,.003,'Brass','Y')
cylinder('Handle rivet',(0,.178,.088),.003,.003,'Steel',vertices=24,bev=.0005)
export('Scoop','Concave sheet-metal scoop with rolled lip and oiled wood handle. Bowl points toward -Z in Unity; grip near +Z.')

# ---- Brown paper bag: open mouth, gussets, folded rim, uneven creases. ----
begin('Bag')
levels=[(.0,.088,.049),(.014,.094,.055),(.08,.095,.057),(.19,.102,.06),(.275,.097,.054),(.291,.102,.057)]
vs=[]
for j,(z,w,d) in enumerate(levels):
    # Eight corners and inward side gusset centres, distinct from a box.
    ring=[(-w,-d),(-w*.5,-d*.95),(w*.5,-d*.98),(w,-d),(w*.73,0),(w,d),(w*.5,d*.95),(-w*.5,d*.98),(-w,d),(-w*.73,0)]
    for i,(x,y) in enumerate(ring):vs.append((x,y,z+(0 if j==0 else math.sin(i*2.1+j)*.0022)))
fs=[]
for j in range(len(levels)-1):
    for i in range(10):fs.append((j*10+i,j*10+(i+1)%10,(j+1)*10+(i+1)%10,(j+1)*10+i))
fs.append(tuple(reversed(range(10))));bag=mesh('Folded kraft bag',vs,fs,'Paper');s=bag.modifiers.new('Paper wall thickness','SOLIDIFY');s.thickness=.0008;bevel(bag,.001,2)
# Rolled upper edge following actual irregular mouth.
for i in range(10):
    a=vs[50+i];b=vs[50+(i+1)%10];rod('Folded open paper rim',a,b,.0015,'Paper')
# Glue seam and triangular bottom gusset folds.
cube('Back glued overlap',(.034,.058,.131),(.012,.001,.242),'Paper',.0004)
for side in [-1,1]:
    mesh('Bottom folded gusset',[(side*.089,-.049,.015),(side*.09,.049,.015),(side*.069,0,.054)],[(0,1,2)],'Paper')
label('Golden Hour bag seal',(0,-.0595,.14),.085,.085,'BrandSeal')
export('Bag','Open gusseted kraft bag with folded rim, paper thickness, bottom folds and printed brand seal. Bottom pivot; .20 x .12 x .29m.')

begin('Bucket')
lathe('Tapered paper bucket',[(.105,.004),(.108,.008),(.137,.226),(.14,.23),(.14,.237),(.135,.24),(.132,.235),(.129,.227),(.101,.014),(0,.014)],'Cream',segments=80)
for z,r in [(.006,.106),(.232,.137)]:torus('Bucket rolled rim',(0,0,z),r,.004,'Cream')
lathe('Printed claret stripe lower',[(.1134,.041),(.1202,.091)],'Red',segments=80)
lathe('Printed claret stripe upper',[(.1289,.157),(.1361,.211)],'Red',segments=80)
# Printed seal follows the tapered cylinder instead of cutting through it.
v=[];f=[];tex=[]
for j,z in enumerate([.086,.174]):
    radius=.108+(.137-.108)*(z-.008)/(.226-.008)+.0013
    for i in range(25):
        a=-math.pi/2+(i/24-.5)*.74;v.append((radius*math.cos(a),radius*math.sin(a),z))
for i in range(24):f.append((i,i+1,26+i,25+i));tex.append(((i/24,0),((i+1)/24,0),((i+1)/24,1),(i/24,1)))
mesh('Bucket brand medallion',v,f,'BrandSeal',tex,True)
export('Bucket','Open tapered paper sharing bucket with rolled lip, interior, burgundy printed bands and seal. .28m diameter x .24m high.')

def shaker(name,labelmat):
    begin(name)
    lathe('Tin shaker body',[(0,.004),(.037,.004),(.041,.007),(.042,.012),(.042,.135),(.04,.143),(.038,.147)],'Steel',segments=64)
    torus('Tin bottom seam',(0,0,.009),.04,.0025,'Steel')
    lathe('Perforated shaker cap',[(.039,.14),(.044,.143),(.045,.147),(.045,.161),(.042,.169),(0,.172)],'SteelDark',segments=64)
    torus('Cap rolled seam',(0,0,.147),.044,.002,'Steel')
    for i in range(32):
        a=2*math.pi*i/32;cube('Cap grip flute',(.0445*math.cos(a),.0445*math.sin(a),.153),(.002,.002,.01),'Steel',.0006)
    for j in [-1,0,1]:
        for i in [-1,0,1]:
            if abs(i)+abs(j)<3:cylinder('Cap perforation',(i*.014,j*.014,.171),.003,.0013,'Rubber',vertices=16,bev=0)
    # A curved printed label wraps 160 degrees around the front of the cylinder.
    verts=[];faces=[];coords=[]
    for row,z in enumerate([.025,.133]):
        for i in range(33):
            a=math.radians(-170+i*160/32);verts.append((.0427*math.cos(a),.0427*math.sin(a),z))
    for i in range(32):faces.append((i,i+1,34+i,33+i));coords.append(((i/32,0),((i+1)/32,0),((i+1)/32,1),(i/32,1)))
    mesh('Printed sugar label',verts,faces,labelmat,coords,True)
    export(name,'Curved printed label, rolled steel canister and ridged perforated cap. .09m diameter x .172m high.')
shaker('Shaker','LabelCinnamon');shaker('ShakerPowdered','LabelPowdered')

begin('MiniDonut')
verts=[];faces=[];coords=[]
for j in range(20):
    v=2*math.pi*j/20
    for i in range(64):
        a=2*math.pi*i/64
        verts.append(mini_donut_point(a,v))
for j in range(20):
    for i in range(64):faces.append((j*64+i,j*64+(i+1)%64,((j+1)%20)*64+(i+1)%64,((j+1)%20)*64+i));coords.append(((i/64,j/20),((i+1)/64,j/20),((i+1)/64,(j+1)/20),(i/64,(j+1)/20)))
mesh('Proofed irregular mini donut',verts,faces,'Dough',coords,True)
export('MiniDonut',MINI_DONUT_DESCRIPTION)

begin('Extinguisher')
lathe('Red cylinder tank',[(0,.005),(.052,.005),(.061,.016),(.064,.04),(.064,.235),(.059,.258),(.045,.274),(.02,.28)],'Red',segments=64)
torus('Tank base boot',(0,0,.024),.061,.005,'Rubber')
cylinder('Extinguisher valve',(0,0,.297),.016,.04,'Brass')
cube('Valve hand grip',(0,-.005,.325),(.033,.102,.012),'SteelDark',.006,rot=(.12,0,0))
cube('Safety lever',(0,.005,.342),(.028,.09,.009),'Red',.004,rot=(-.12,0,0))
cylinder('Pressure gauge',(0,-.028,.30),.019,.012,'Brass','Y')
cylinder('Gauge glass',(0,-.035,.30),.015,.002,'Cream','Y');rod('Gauge pointer',(0,-.037,.30),(.009,-.037,.308),.001,'Rubber')
tube('Hose',[(.02,.015,.31),(.085,.012,.30),(.092,.003,.21),(.074,-.008,.08)],.007,'Rubber')
cylinder('Hose nozzle',(.072,-.008,.071),.012,.045,'SteelDark')
cube('Instruction label',(0,-.064,.163),(.075,.001,.11),'Cream',.002)
text('Extinguisher label','FIRE', (0,-.066,.195),.024,'Red')
text('Extinguisher label','PULL / AIM\nSQUEEZE\nSWEEP',(0,-.066,.151),.009,'Teal')
export('Extinguisher','Red safety extinguisher with pressure gauge, trigger assembly and flexible hose.')

begin('ServiceBell')
lathe('Bell rubber base',[(0,.003),(.06,.003),(.065,.008),(.065,.014),(.06,.019),(0,.019)],'Rubber',segments=64)
lathe('Brass service bell dome',[(.059,.018),(.059,.023),(.055,.026),(.052,.035),(.044,.05),(.03,.061),(.014,.066),(0,.066)],'Brass',segments=64)
cylinder('Bell button stem',(0,0,.075),.005,.024,'Steel')
bell=sphere('BellButton',(0,0,.089),(.016,.016,.006),'Brass');moving(bell,'BellButton',(0,0,.089))
torus('Bell engraved ring',(0,0,.025),.055,.001,'SteelDark')
export('ServiceBell','Polished brass service bell with separate BellButton moving mesh.')

# ---- Matching stall canopy, lamps, bunting, sandwich board and stanchion. ----
begin('Canopy')
for x in [-1.85,1.85]:
    for y in [-.58,.64]:
        rod('Canopy steel upright',(x,y,0),(x,y,2.65),.025,'Teal')
        cylinder('Pole foot',(x,y,.018),.065,.036,'SteelDark')
for y in [-.58,.64]:rod('Canopy crossrail',(-1.85,y,2.55),(1.85,y,2.55),.025,'Teal')
rod('Canopy ridge',(-1.93,.03,2.91),(1.93,.03,2.91),.024,'Teal')
for i in range(16):
    x0=-2+i*.25;x1=x0+.25
    for sign in [-1,1]:
        roof=mesh('Sewn canvas roof stripe',[(x0,.03,2.93),(x1,.03,2.93),(x1,.03+sign*.80,2.59),(x0,.03+sign*.80,2.59)],[(0,1,2,3)],'CanvasCream' if i%2 else 'CanvasRed',[[(0,1),(1,1),(1,0),(0,0)]])
        skin=roof.modifiers.new('Canvas cloth thickness','SOLIDIFY');skin.thickness=.003
    # Scalloped valance has real curved profile.
    v=[(x0,-.77,2.595),(x1,-.77,2.595)]
    for j in range(13):
        t=j/12;v.append((x1-t*.25,-.77,2.50-.055*math.sin(t*math.pi)))
    valance=mesh('Scalloped canvas valance',v,[tuple(range(len(v)))],'CanvasCream' if i%2 else 'CanvasRed');skin=valance.modifiers.new('Valance cloth thickness','SOLIDIFY');skin.thickness=.003
for x in [-1.85,1.85]:
    rod('Roof brace',(x,-.58,2.55),(x,.03,2.91),.018,'Teal');rod('Roof brace',(x,.64,2.55),(x,.03,2.91),.018,'Teal')
tube('Warm festoon cable',[(-1.84,-.71,2.45),(-.92,-.71,2.36),(0,-.71,2.33),(.92,-.71,2.36),(1.84,-.71,2.45)],.004,'Rubber')
for i in range(15):
    x=-1.75+i*.25;z=2.33+.12*(x/1.84)**2
    cylinder('Bulb socket',(x,-.71,z-.012),.014,.025,'Rubber')
    sphere('Warm festoon bulb',(x,-.71,z-.045),(.022,.022,.03),'Lamp',24,12)
export('Canopy','4m striped canvas canopy with sewn scalloped valance, poles and warm festoon bulbs. Floor origin. Roof peak 2.93m; integrate once over counter.')

begin('HangingSign')
cube('Solid painted sign back',(0,0,.34),(1.48,.06,.62),'Teal',.028)
for x in [-.745,.745]:cube('Brass sign vertical frame',(x,-.036,.34),(.018,.012,.63),'Brass',.004)
for z in [.025,.655]:cube('Brass sign horizontal frame',(0,-.036,z),(1.5,.012,.018),'Brass',.004)
label('Original Golden Hour sign art',(0,-.037,.34),1.44,.48,'CounterSign')
for x in [-.55,.55]:
    rod('Sign hanger',(x,0,.65),(x,0,.86),.007,'SteelDark');torus('Sign hanger eye',(x,0,.67),.015,.004,'Brass','Y')
export('HangingSign','Gold framed original Golden Hour sign with hanging rods. Face toward local Blender -Y / Unity front.')

begin('PendantLamp')
lathe('Enamel pendant shade',[(.025,.24),(.04,.23),(.065,.20),(.15,.12),(.18,.10),(.185,.085),(.18,.078),(.171,.083),(.145,.116),(.058,.204),(.024,.228)],'Teal',segments=64)
lathe('Cream pendant reflector',[(.17,.083),(.144,.115),(.058,.203),(.024,.224)],'Cream',segments=64)
torus('Pendant brass rim',(0,0,.085),.182,.004,'Brass')
sphere('Pendant glowing globe',(0,0,.13),(.04,.04,.045),'Lamp')
tube('Pendant cord',[(0,0,.24),(0,0,.49)],.006,'Rubber')
export('PendantLamp','Spun enamel shade with cream inner reflector, brass rim, bulb and suspension cord.')

begin('SandwichBoard')
for y,ang in [(-.11,-.14),(.11,.14)]:
    cube('A frame chalk panel',(0,y,.45),(.46,.03,.72),'Teal',.01,rot=(ang,0,0))
    for x in [-.26,.26]:cube('A frame timber side',(x,y,.4),(.045,.045,.8),'Wood',.008,rot=(ang,0,0))
    for z in [.12,.79]:cube('A frame timber rail',(0,y+math.sin(ang)*(z-.45),z),(.54,.045,.044),'Wood',.007)
rod('Board top hinge',(-.28,0,.79),(.28,0,.79),.014,'Brass')
text('Chalk HOT text','HOT & FRESH',(0,-.167,.68),.046,'Cream')
text('Chalk DONUTS text','MINI\nDONUTS',(0,-.18,.51),.074,'Cream')
text('Chalk menu price','6 for $5',(0,-.207,.30),.043,'Cream')
text('Chalk menu footer','MADE WITH JOY',(0,-.22,.20),.021,'Cream')
export('SandwichBoard','Timber A-frame sidewalk chalkboard with legible chalk lettering and hinges.')

begin('MarketStall')
# Open serving window, a timber carcass and a separately modelled cloth roof.
cube('Market stall base',(0,.20,.40),(2.6,1.20,.78),'Teal',.015)
cube('Market serving ledge',(0,-.46,.835),(2.78,.36,.07),'Wood',.018)
for x in [-1.31,1.31]:
    cube('Market side panel',(x,.12,1.30),(.06,1.2,1.83),'Wood',.009)
    for y in [-.47,.77]:rod('Market corner post',(x,y,.03),(x,y,2.39),.031,'Teal')
cube('Market rear wall',(0,.77,1.49),(2.62,.04,1.7),'Teal',.008)
for z in [.10,.73]:cube('Market counter trim',(0,-.416,z),(2.62,.027,.04),'Brass',.004)
for x in [-1.25,-.63,0,.63,1.25]:cube('Market raised stile',(x,-.42,.42),(.026,.024,.64),'Wood',.005)
for z in [1.14,1.55]:cube('Market rear shelf',(0,.47,z),(2.40,.43,.035),'Wood',.008)
for i in range(7):
    x=-.96+i*.32
    lathe('Preserve display jar',[(0,1.17),(.072,1.17),(.078,1.19),(.078,1.34),(.065,1.36),(.065,1.39),(0,1.39)],'Cream' if i%2 else 'Red',(x,.42,0),24)
    cylinder('Jar metal screw lid',(x,.42,1.39),.071,.025,'Brass',vertices=24)
for i in range(9):
    x=-1.35+i*.30
    roof=mesh('Stall sewn roof stripe',[(x,-.72,2.30),(x+.30,-.72,2.30),(x+.30,.14,2.64),(x,.14,2.64),(x,.97,2.30),(x+.30,.97,2.30)],[(0,1,2,3),(3,2,5,4)],'CanvasCream' if i%2 else 'CanvasRed')
    mod=roof.modifiers.new('Canvas thickness','SOLIDIFY');mod.thickness=.004
    v=[(x,-.72,2.30),(x+.30,-.72,2.30)]+[(x+.30-j*.025,-.72,2.16-.06*math.sin(j/12*math.pi)) for j in range(13)]
    val=mesh('Market scalloped valance',v,[tuple(range(len(v)))],'CanvasCream' if i%2 else 'CanvasRed');mod=val.modifiers.new('Canvas thickness','SOLIDIFY');mod.thickness=.004
cube('Market name board',(0,-.51,1.98),(1.95,.05,.30),'Teal',.025)
for x in [-.99,.99]:cube('Market sign frame',(x,-.542,1.98),(.018,.012,.31),'Brass',.003)
for z in [1.82,2.14]:cube('Market sign frame',(0,-.542,z),(2,.012,.016),'Brass',.003)
tube('Market hanging light cable',[(-1.23,-.59,2.11),(0,-.59,2.02),(1.23,-.59,2.11)],.004,'Rubber')
for i in range(9):
    x=-1.12+i*.28;z=2.02+.09*(x/1.23)**2
    sphere('Market warm bulb',(x,-.59,z-.035),(.022,.022,.031),'Lamp',16,8)
export('MarketStall','Open-window fairground stall with pitched sewn canvas roof, scalloped valance, raised timber panels, shelves, jars, name board and warm string lights. Ground pivot; about2.78m wide x1.69m deep x2.64m high.')

begin('ParkBench')
for x in [-.60,.60]:
    tube('Cast metal bench leg',[(x,-.25,.02),(x,-.21,.37),(x,.21,.39),(x,.28,.02)],.024,'SteelDark')
    tube('Bench back support',[(x,.18,.31),(x,.28,.60),(x,.32,.85)],.022,'SteelDark')
for y in [-.20,-.066,.066,.20]:cube('Bench seat oak slat',(0,y,.43),(1.5,.12,.045),'Wood',.008)
for z in [.59,.73,.87]:cube('Bench back oak slat',(0,.29+(z-.59)*.14,z),(1.5,.035,.11),'Wood',.008,rot=(-.14,0,0))
for x in [-.60,.60]:
    for y in [-.20,.20]:screw((x,y,.455),'Z',.005)
export('ParkBench','Fairground bench with rounded oak slats, curved metal legs and back support.1.5m wide; grounded origin.')

begin('FerrisWheel')
hub=(0,0,6)
for y in [-.42,.42]:
    torus('Ferris wheel steel rim',(0,y,6),4.3,.055,'Cream','Y')
    torus('Ferris wheel rim trim',(0,y,6),4.18,.020,'Brass','Y')
    for x in [-2.4,2.4]:rod('Ferris wheel A-frame support',(x,y*2.4,.05),(0,y,6),.13,'Teal')
    for i in range(16):
        a=i*math.pi/8;rod('Ferris wheel spoke',(0,y,6),(4.3*math.cos(a),y,6+4.3*math.sin(a)),.026,'Cream')
cylinder('Ferris wheel main axle',hub,.24,1.4,'Brass','Y')
for i in range(12):
    a=i*math.pi/6;x=4.3*math.cos(a);z=6+4.3*math.sin(a)
    rod('Gondola pivot axle',(x,-.5,z),(x,.5,z),.032,'SteelDark')
    for y in [-.45,.45]:rod('Gondola suspension',(x,y,z),(x,y,z-.62),.02,'SteelDark')
    pan('Gondola painted basket',.72,.85,.42,'Red' if i%2 else 'Teal',loc=(x,0,z-.86),r=.10)
    cube('Gondola upholstered seat',(x,0,z-.67),(.56,.65,.10),'Cream',.04)
    sphere('Ferris warm rim light',(x,-.49,z),(.075,.04,.075),'Lamp',16,8)
export('FerrisWheel','Fairground wheel with dual tubular rims, tension spokes, A-frame supports and twelve freely hanging baskets. Ground origin, hubY6m, outer radius4.3m.')

# ---- Source, manifest and offline render contact sheet. ----
(TEX/'material_manifest.json').write_text(json.dumps(manifest,indent=2))
(OUT/'props_manifest.json').write_text(json.dumps(props,indent=2))
for texture_image in bpy.data.images:
    if texture_image.source=='FILE' and texture_image.filepath:
        texture_image.filepath='//../Assets/Art/Textures/'+Path(texture_image.filepath).name
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'GoldenHour_Props.blend'))
if '--skip-renders' in sys.argv:sys.exit(0)
for o in bpy.data.objects:o.hide_render=True
scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=True
scene.render.resolution_x=1600;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.world.color=(.22,.22,.22)
world=scene.world;world.use_nodes=True;world.node_tree.nodes.get('Background').inputs[0].default_value=(.18,.21,.25,1);world.node_tree.nodes.get('Background').inputs[1].default_value=.7
scene.view_settings.view_transform='AgX'

def light(name,loc,power,size,color):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size;data.color=color
    o=bpy.data.objects.new(name,data);scene.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,.3))-o.location).to_track_quat('-Z','Y').to_euler()
    return o

current=None
ground=cube('QA ground',(0,0,-.06),(200,200,.10),'Cream',0);ground.hide_render=False
light('Large warm key',(-3,-4,6),850,5,(1,.80,.59));light('Soft cool fill',(4,-1,3),650,4,(.60,.78,1));light('Rim light',(1,3,5),1100,3,(1,.77,.45))
data=bpy.data.cameras.new('Asset QA camera');camera=bpy.data.objects.new('Asset QA camera',data);scene.collection.objects.link(camera);scene.camera=camera;data.type='ORTHO'

def render(name,visible,pos,target,scale):
    for obs in groups.values():
        for o in obs:o.hide_render=True
    for asset,offset in visible:
        for o in groups[asset]:o.hide_render=False;o.location+=Vector(offset)
    camera.location=pos;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();data.ortho_scale=scale
    scene.render.filepath=str(QA/name);bpy.ops.render.render(write_still=True)
    for asset,offset in visible:
        for o in groups[asset]:o.location-=Vector(offset)

if '--only-ferris' in sys.argv:
    render('props-ferris-wheel.png',[('FerrisWheel',(0,0,0))],(14,-23,12),(0,0,5.3),17)
    sys.exit(0)
render('props-fryer.png',[('Fryer',(0,0,0))],(2.5,-3,2),(0,0,.40),2.0)
render('props-serving.png',[('Bag',(-.5,.1,0)),('Bucket',(-.2,.08,0)),('Shaker',(.10,.08,0)),('ShakerPowdered',(.22,.08,0)),('Scoop',(.12,-.22,.02)),('Tray',(.53,.02,0)),('MiniDonut',(.53,.02,.022)),('ServiceBell',(-.3,-.22,0))],(1.6,-2.7,2.0),(0,0,.12),1.45)
render('props-stall.png',[('Counter',(0,0,0)),('Canopy',(0,0,0)),('Fryer',(-.6,.05,.91)),('Tray',(.63,0,.91)),('Bag',(.25,-.25,.91)),('Bucket',(.9,.15,.91)),('Shaker',(.4,.25,.91)),('ShakerPowdered',(.52,.25,.91)),('HangingSign',(0,.66,1.72)),('SandwichBoard',(2.1,.70,0))],(5,-6,4),(0,0,1.45),5.3)
render('props-market-stall.png',[('MarketStall',(0,0,0)),('ParkBench',(2.3,.1,0))],(5,-7,4),(1,0,1.25),5.3)
render('props-ferris-wheel.png',[('FerrisWheel',(0,0,0))],(14,-23,12),(0,0,5.3),17)
print('ALL_PROPS_COMPLETE',len(props))
