using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using GoldenHour.Presentation;

namespace GoldenHour.Editor
{
    public sealed class GoldenHourImporter : AssetPostprocessor
    {
        void OnPreprocessTexture()
        {
            var t=(TextureImporter)assetImporter;
            t.maxTextureSize=2048;t.anisoLevel=8;t.mipmapEnabled=true;t.textureCompression=TextureImporterCompression.CompressedHQ;
            if(assetPath.Contains("_normal")){t.textureType=TextureImporterType.NormalMap;t.convertToNormalmap=false;}
            if(assetPath.Contains("_roughness")||assetPath.Contains("_metallic_smoothness")){t.sRGBTexture=false;}
            if(assetPath.Contains("label")||assetPath.Contains("seal")){t.alphaIsTransparency=true;}
            if(assetPath.EndsWith("oil_flame.png",StringComparison.OrdinalIgnoreCase)){t.alphaIsTransparency=true;t.wrapMode=TextureWrapMode.Clamp;}
        }
        void OnPreprocessModel()
        {
            var m=(ModelImporter)assetImporter;
            m.globalScale=1;m.useFileScale=true;m.importBlendShapes=true;
            m.materialImportMode=ModelImporterMaterialImportMode.ImportStandard;
            m.importNormals=ModelImporterNormals.Import;m.importTangents=ModelImporterTangents.CalculateMikk;
            m.meshCompression=ModelImporterMeshCompression.Off;m.isReadable=false;
            if(assetPath.Contains("Characters")){m.importAnimation=true;m.animationType=ModelImporterAnimationType.Legacy;m.generateAnimations=ModelImporterGenerateAnimations.GenerateAnimations;m.optimizeGameObjects=false;}
            else m.importAnimation=false;
        }
    }
    public static class GoldenHourBuild
    {
        const string Generated="Assets/Generated";
        [Serializable]class MaterialList { public MaterialDefinition[] materials; }
        [Serializable]class MaterialDefinition { public string name,albedo,normal,roughnessMap,metallicSmoothnessMap; public float[] color;public float metallic,roughness;public bool alphaClip; }
        [MenuItem("Golden Hour/Rebuild fairground and Windows player")]
        public static void Build()
        {
            Configure();
            AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);
            Directory.CreateDirectory(Generated+"/Materials");Directory.CreateDirectory(Generated+"/Prefabs");
            AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);
            MakeMaterials();
            var a=ScriptableObject.CreateInstance<StandAssets>();
            a.fryer=Prefab("Fryer");a.counter=Prefab("Counter");a.tray=Prefab("Tray");a.scoop=Prefab("Scoop");
            a.bag=Prefab("Bag");a.bucket=Prefab("Bucket");a.shaker=Prefab("Shaker");a.shakerPowdered=Prefab("ShakerPowdered");a.donut=Prefab("MiniDonut");
            a.extinguisher=Prefab("Extinguisher");a.bell=Prefab("ServiceBell");a.canopy=Prefab("Canopy");a.hangingSign=Prefab("HangingSign");a.pendant=Prefab("PendantLamp");a.sandwichBoard=Prefab("SandwichBoard");
            a.marketStall=Prefab("MarketStall");a.parkBench=Prefab("ParkBench");a.ferrisWheel=Prefab("FerrisWheel");
            a.customer=Prefab("Customer_Milo",true);a.hands=Prefab("BakerHands",true);
            a.steel=Material("GH_Steel",new Color(.55f,.61f,.62f),.88f,.73f);
            a.wood=Material("GH_Wood",new Color(.50f,.25f,.09f));a.cream=Material("GH_Cream",new Color(.88f,.79f,.57f));
            a.red=Material("GH_Red",new Color(.42f,.035f,.035f));a.teal=Material("GH_Teal",new Color(.025f,.17f,.18f));
            a.gold=Material("GH_Brass",new Color(.66f,.39f,.12f),.72f,.72f);a.oil=Material("GH_Oil",new Color(.21f,.095f,.013f),.1f,.9f);
            a.glass=Material("GH_Glass",new Color(.65f,.8f,.9f),.1f,.95f);a.ground=Material("GH_Ground",new Color(.22f,.18f,.13f));a.canvas=Material("GH_Canvas",new Color(.9f,.8f,.6f));
            a.glow=Material("GH_Bulb",new Color(1,.7f,.3f));a.glow.EnableKeyword("_EMISSION");a.glow.SetColor("_EmissionColor",new Color(1,.55f,.15f)*3);
            a.font=AssetDatabase.LoadAssetAtPath<Font>("Assets/AudioAndBrand/Fredoka-Medium.ttf");
            a.keyArt=AssetDatabase.LoadAssetAtPath<Texture2D>("Assets/AudioAndBrand/title_keyart.png");a.seal=Texture("brand_seal.png");a.sign=Texture("counter_sign.png");
            a.flame=Texture("oil_flame.png");a.particle=new Material(Shader.Find("Universal Render Pipeline/Particles/Unlit"));
            a.particle.SetFloat("_Surface",1);a.particle.SetFloat("_Blend",0);a.particle.SetFloat("_AlphaClip",0);
            a.particle.SetInt("_SrcBlend",(int)BlendMode.SrcAlpha);a.particle.SetInt("_DstBlend",(int)BlendMode.OneMinusSrcAlpha);
            a.particle.SetInt("_SrcBlendAlpha",(int)BlendMode.One);a.particle.SetInt("_DstBlendAlpha",(int)BlendMode.OneMinusSrcAlpha);
            a.particle.SetInt("_ZWrite",0);a.particle.SetOverrideTag("RenderType","Transparent");a.particle.renderQueue=3000;
            a.particle.EnableKeyword("_SURFACE_TYPE_TRANSPARENT");
            a.particle.DisableKeyword("_ALPHAPREMULTIPLY_ON");a.particle.DisableKeyword("_ALPHAMODULATE_ON");a.particle.DisableKeyword("_ALPHATEST_ON");
            Save(a.particle,Generated+"/Materials/GH_Particles.mat");
            a.sky=new Material(Shader.Find("GoldenHour/DuskSky"));Save(a.sky,Generated+"/Materials/GH_DuskSky.mat");
            a.sounds=AssetDatabase.FindAssets("t:AudioClip",new[]{"Assets/AudioAndBrand"}).Select(AssetDatabase.GUIDToAssetPath).Select(p=>AssetDatabase.LoadAssetAtPath<AudioClip>(p)).ToArray();
            Save(a,Generated+"/StandAssets.asset");
            var scene=EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,NewSceneMode.Single);
            // The workstation is assembled at runtime; keep its fog variant in the player.
            RenderSettings.fog=true;RenderSettings.fogMode=FogMode.Exponential;
            RenderSettings.fogDensity=.022f;RenderSettings.fogColor=new Color(.17f,.20f,.28f);
            var game=new GameObject("Golden Hour");game.AddComponent<StandController>().assets=a;
            Directory.CreateDirectory("Assets/Scenes");EditorSceneManager.SaveScene(scene,"Assets/Scenes/Fairground.unity");
            EditorBuildSettings.scenes=new[]{new EditorBuildSettingsScene("Assets/Scenes/Fairground.unity",true)};
            AssetDatabase.SaveAssets();
            string output=Path.GetFullPath(Path.Combine(Application.dataPath,"../../..","builds/unity/windows/GoldenHour.exe"));Directory.CreateDirectory(Path.GetDirectoryName(output));
            var report=BuildPipeline.BuildPlayer(new BuildPlayerOptions{scenes=new[]{"Assets/Scenes/Fairground.unity"},locationPathName=output,target=BuildTarget.StandaloneWindows64,options=BuildOptions.None});
            Debug.Log("GH_BUILD "+report.summary.result+" bytes="+report.summary.totalSize+" path="+output);
            if(report.summary.result!=BuildResult.Succeeded)throw new Exception("Windows build failed: "+report.summary.result);
        }
        static void Configure()
        {
            Directory.CreateDirectory(Generated);
            AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);
            PlayerSettings.companyName="Golden Hour Studio";PlayerSettings.productName="Golden Hour Unity";PlayerSettings.bundleVersion="0.1.0";
            PlayerSettings.colorSpace=ColorSpace.Linear;PlayerSettings.defaultScreenWidth=1920;PlayerSettings.defaultScreenHeight=1080;
            PlayerSettings.fullScreenMode=FullScreenMode.FullScreenWindow;PlayerSettings.resizableWindow=true;PlayerSettings.runInBackground=false;
            PlayerSettings.SetScriptingBackend(UnityEditor.Build.NamedBuildTarget.Standalone,ScriptingImplementation.Mono2x);
            PlayerSettings.SetUseDefaultGraphicsAPIs(BuildTarget.StandaloneWindows64,false);PlayerSettings.SetGraphicsAPIs(BuildTarget.StandaloneWindows64,new[]{GraphicsDeviceType.Direct3D11});
            QualitySettings.antiAliasing=4;QualitySettings.anisotropicFiltering=AnisotropicFiltering.ForceEnable;QualitySettings.shadowDistance=35;QualitySettings.shadowResolution=UnityEngine.ShadowResolution.High;QualitySettings.vSyncCount=1;
            var renderer=ScriptableObject.CreateInstance<UniversalRendererData>();
            renderer.postProcessData=AssetDatabase.LoadAssetAtPath<PostProcessData>("Packages/com.unity.render-pipelines.universal/Runtime/Data/PostProcessData.asset");
            if(!renderer.postProcessData)throw new Exception("URP post-processing resources are missing. Resolve the Universal RP package before building.");
            Save(renderer,Generated+"/GoldenRenderer.asset");
            var pipeline=UniversalRenderPipelineAsset.Create(renderer);pipeline.msaaSampleCount=4;pipeline.renderScale=1;pipeline.supportsHDR=true;pipeline.shadowDistance=35;pipeline.mainLightShadowmapResolution=2048;pipeline.maxAdditionalLightsCount=8;
            Save(pipeline,Generated+"/GoldenPipeline.asset");GraphicsSettings.defaultRenderPipeline=pipeline;QualitySettings.renderPipeline=pipeline;
            Physics.defaultSolverIterations=10;Physics.defaultSolverVelocityIterations=4;Physics.gravity=new Vector3(0,-9.81f,0);
        }
        static void MakeMaterials()
        {
            string path="Assets/Art/Textures/unity_materials.json";
            if(!File.Exists(path))return;
            var defs=JsonUtility.FromJson<MaterialList>(File.ReadAllText(path));
            foreach(var d in defs.materials)
            {
                var c=d.color??new[]{1f,1f,1f,1f};var m=Material(d.name,new Color(c[0],c[1],c[2],c.Length>3?c[3]:1),d.metallic,1-d.roughness);
                m.SetColor("_BaseColor",new Color(c[0],c[1],c[2],c.Length>3?c[3]:1));
                m.SetFloat("_Metallic",d.metallic);m.SetFloat("_Smoothness",1-d.roughness);
                if(!string.IsNullOrEmpty(d.albedo))m.SetTexture("_BaseMap",Texture(d.albedo));
                if(!string.IsNullOrEmpty(d.normal)){m.SetTexture("_BumpMap",Texture(d.normal));m.SetFloat("_BumpScale",.5f);m.EnableKeyword("_NORMALMAP");}
                if(!string.IsNullOrEmpty(d.metallicSmoothnessMap)){m.SetTexture("_MetallicGlossMap",Texture(d.metallicSmoothnessMap));m.EnableKeyword("_METALLICSPECGLOSSMAP");m.SetFloat("_Smoothness",1);}
                if(d.alphaClip){m.SetFloat("_AlphaClip",1);m.SetFloat("_Cutoff",.15f);m.EnableKeyword("_ALPHATEST_ON");m.renderQueue=2450;}
                m.EnableKeyword("_EMISSION");m.SetColor("_EmissionColor",Color.black);EditorUtility.SetDirty(m);
            }
        }
        static Texture2D Texture(string name){return AssetDatabase.FindAssets(Path.GetFileNameWithoutExtension(name)+" t:Texture2D",new[]{"Assets/Art"}).Select(AssetDatabase.GUIDToAssetPath).Where(p=>Path.GetFileName(p)==name).Select(AssetDatabase.LoadAssetAtPath<Texture2D>).FirstOrDefault();}
        static Material Material(string name,Color color,float metal=0,float smooth=.35f)
        {
            string path=Generated+"/Materials/"+name+".mat";var m=AssetDatabase.LoadAssetAtPath<Material>(path);
            if(!m){m=new Material(Shader.Find("Universal Render Pipeline/Lit"));m.name=name;m.color=color;m.SetFloat("_Metallic",metal);m.SetFloat("_Smoothness",smooth);m.EnableKeyword("_EMISSION");m.SetColor("_EmissionColor",Color.black);Save(m,path);}return m;
        }
        static GameObject Prefab(string name,bool character=false)
        {
            string path="Assets/Art/"+(character?"Characters/":"Props/")+name+".fbx";
            var source=AssetDatabase.LoadAssetAtPath<GameObject>(path);if(!source)throw new Exception("Missing authored asset: "+path);
            var instance=(GameObject)PrefabUtility.InstantiatePrefab(source);instance.name=name;
            foreach(var r in instance.GetComponentsInChildren<Renderer>(true))
            {
                var mats=r.sharedMaterials;for(int i=0;i<mats.Length;i++)
                {
                    if(!mats[i])continue;string key=mats[i].name;var mat=AssetDatabase.LoadAssetAtPath<Material>(Generated+"/Materials/"+key+".mat");
                    if(!mat){Color c=mats[i].HasProperty("_Color")?mats[i].color:new Color(.6f,.5f,.4f);mat=Material(key,c);}
                    mats[i]=mat;
                }
                r.sharedMaterials=mats;r.shadowCastingMode=ShadowCastingMode.On;r.receiveShadows=true;
            }
            if(character)
            {
                var driver=instance.AddComponent<CharacterAnimationDriver>();var clips=AssetDatabase.LoadAllAssetsAtPath(path).OfType<AnimationClip>().Where(c=>!c.name.StartsWith("__preview__")).ToArray();
                var serialized=new SerializedObject(driver);var property=serialized.FindProperty("clips");property.arraySize=clips.Length;for(int i=0;i<clips.Length;i++)property.GetArrayElementAtIndex(i).objectReferenceValue=clips[i];
                serialized.FindProperty("isHands").boolValue=name=="BakerHands";serialized.ApplyModifiedPropertiesWithoutUndo();
                Debug.Log("GH_RIG "+name+" clips="+clips.Length+" skinned="+instance.GetComponentsInChildren<SkinnedMeshRenderer>().Length);
            }
            var prefab=PrefabUtility.SaveAsPrefabAsset(instance,Generated+"/Prefabs/"+name+".prefab");UnityEngine.Object.DestroyImmediate(instance);return prefab;
        }
        static void Save(UnityEngine.Object asset,string path){var old=AssetDatabase.LoadAssetAtPath<UnityEngine.Object>(path);if(old)AssetDatabase.DeleteAsset(path);AssetDatabase.CreateAsset(asset,path);}
    }
}
