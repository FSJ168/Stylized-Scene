Shader "MyShader/Foliage"
{
    Properties
    {
        [HideInInspector]_EmissionColor("Emission Color",Color)=(1,1,1,1)
        [Header(Maps)][Space(10)][MainTexture]_Albedo("Albedo",2D)="white"{}
        _SmoothnessTexture("Smoothness",2D)="white"{}

        [Header(Settings)][Space(5)]_MainColor("Main Color",Color)=(1,1,1,0)
        _Smoothness("Smoothness",Range(0,1))=0
        _AlphaCutoff("Alpha Cutoff",Range(0,1))=0.35
        _TranslucencyInt("Translucency Int",Range(0,100))=1

        [Header(Second Color Settings)][Space(5)][Toggle(_COLOR2ENABLE_ON)]_Color2Enable("Enable",Float)=0
        _SecondColor("Second Color",Color)=(0,0,0,0)
        [KeywordEnum(World_Position,UV_Based)]_SecondColorOverlayType("Overlay Type",Float)=0
        _SecondColorOffset("Offset",Float)=0
        _SecondColorFade("Fade",Range(-1,1))=0.5
        _WorldScale("World Scale",Float)=1

        [Header(Wind Settings)][Space(5)][Toggle(_ENABLEWIND_ON)]_EnableWind("Enable",Float)=1
        _WindForce("Force",Range(0,1))=0.3
        _WindWavesScale("Waves Scale",Range(0,1))=0.25
        _WindSpeed("Speed",Range(0,1))=0.5
        [Toggle(_ANCHORTHEFOLIAGEBASE_ON)]_Anchorthefoliagebase("Anchor the foliage base",Float)=0

        [HideInInspector][ToggleOff]_SpecularHighlights("Specular Highlights",Float)=1
        [HideInInspector][ToggleOff]_EnvironmentReflections("Environment Reflections",Float)=1
        [HideInInspector][ToggleOff]_ReceiveShadows("Receive Shadows",Float)=1
        [HideInInspector]_QueueOffset("_QueueOffset",Float)=0
        [HideInInspector]_QueueControl("_QueueControl",Float)=-1
        [HideInInspector][NoScaleOffset]unity_Lightmaps("unity_Lightmaps",2DArray)=""{}
        [HideInInspector][NoScaleOffset]unity_LightmapsInd("unity_LightmapsInd",2DArray)=""{}
        [HideInInspector][NoScaleOffset]unity_ShadowMasks("unity_ShadowMasks",2DArray)=""{}
    }

    SubShader
    {
        Tags{"RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry" "UniversalMaterialType"="Lit"}
        Cull Off
        ZWrite On
        ZTest LEqual

        HLSLINCLUDE
        #pragma target 4.5
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainColor;
        float4 _Albedo_ST;
        float4 _SecondColor;
        float4 _SmoothnessTexture_ST;
        float _WindSpeed;
        float _WindWavesScale;
        float _WindForce;
        float _WorldScale;
        float _SecondColorOffset;
        float _SecondColorFade;
        float _TranslucencyInt;
        float _Smoothness;
        float _AlphaCutoff;
        CBUFFER_END

        TEXTURE2D(_Albedo);
        SAMPLER(sampler_Albedo);
        TEXTURE2D(_SmoothnessTexture);
        SAMPLER(sampler_SmoothnessTexture);

        float4 _SelectionID;
        int _ObjectId;
        int _PassValue;
        float3 _LightDirection;
        float3 _LightPosition;

        struct Attributes
        {
            float4 positionOS:POSITION;
            float3 normalOS:NORMAL;
            float4 tangentOS:TANGENT;
            float2 uv:TEXCOORD0;
            float2 lightmapUV:TEXCOORD1;
            float2 dynamicLightmapUV:TEXCOORD2;
            UNITY_VERTEX_INPUT_INSTANCE_ID
        };

        struct LitVaryings
        {
            float4 positionCS:SV_POSITION;
            float3 positionWS:TEXCOORD0;
            half3 normalWS:TEXCOORD1;
            float2 uv:TEXCOORD2;
            float4 lightmapUVOrVertexSH:TEXCOORD3;
            half4 fogFactorAndVertexLight:TEXCOORD4;
            float4 shadowCoord:TEXCOORD5;
            #if defined(DYNAMICLIGHTMAP_ON)
            float2 dynamicLightmapUV:TEXCOORD6;
            #endif
            UNITY_VERTEX_INPUT_INSTANCE_ID
            UNITY_VERTEX_OUTPUT_STEREO
        };

        struct SimpleVaryings
        {
            float4 positionCS:SV_POSITION;
            float3 positionWS:TEXCOORD0;
            half3 normalWS:TEXCOORD1;
            float2 uv:TEXCOORD2;
            UNITY_VERTEX_INPUT_INSTANCE_ID
            UNITY_VERTEX_OUTPUT_STEREO
        };

        //ASE原始Simplex 3D噪声
        float3 Mod289(float3 x){return x-floor(x/289.0)*289.0;}
        float4 Mod289(float4 x){return x-floor(x/289.0)*289.0;}
        float4 Permute(float4 x){return Mod289((x*34.0+1.0)*x);}
        float4 TaylorInvSqrt(float4 r){return 1.79284291400159-r*0.85373472095314;}

        float SimplexNoise(float3 v)
        {
            const float2 C=float2(1.0/6.0,1.0/3.0);
            float3 i=floor(v+dot(v,C.yyy));
            float3 x0=v-i+dot(i,C.xxx);
            float3 g=step(x0.yzx,x0.xyz);
            float3 l=1.0-g;
            float3 i1=min(g.xyz,l.zxy);
            float3 i2=max(g.xyz,l.zxy);
            float3 x1=x0-i1+C.xxx;
            float3 x2=x0-i2+C.yyy;
            float3 x3=x0-0.5;
            i=Mod289(i);
            float4 p=Permute(Permute(Permute(i.z+float4(0.0,i1.z,i2.z,1.0))+i.y+float4(0.0,i1.y,i2.y,1.0))+i.x+float4(0.0,i1.x,i2.x,1.0));
            float4 j=p-49.0*floor(p/49.0);
            float4 x_=floor(j/7.0);
            float4 y_=floor(j-7.0*x_);
            float4 x=(x_*2.0+0.5)/7.0-1.0;
            float4 y=(y_*2.0+0.5)/7.0-1.0;
            float4 h=1.0-abs(x)-abs(y);
            float4 b0=float4(x.xy,y.xy);
            float4 b1=float4(x.zw,y.zw);
            float4 s0=floor(b0)*2.0+1.0;
            float4 s1=floor(b1)*2.0+1.0;
            float4 sh=-step(h,0.0);
            float4 a0=b0.xzyw+s0.xzyw*sh.xxyy;
            float4 a1=b1.xzyw+s1.xzyw*sh.zzww;
            float3 g0=float3(a0.xy,h.x);
            float3 g1=float3(a0.zw,h.y);
            float3 g2=float3(a1.xy,h.z);
            float3 g3=float3(a1.zw,h.w);
            float4 norm=TaylorInvSqrt(float4(dot(g0,g0),dot(g1,g1),dot(g2,g2),dot(g3,g3)));
            g0*=norm.x;
            g1*=norm.y;
            g2*=norm.z;
            g3*=norm.w;
            float4 m=max(0.6-float4(dot(x0,x0),dot(x1,x1),dot(x2,x2),dot(x3,x3)),0.0);
            m*=m;
            m*=m;
            float4 px=float4(dot(x0,g0),dot(x1,g1),dot(x2,g2),dot(x3,g3));
            return 42.0*dot(m,px);
        }

        //风摆统一用于所有Pass，避免阴影和深度与模型错位
        float3 ApplyWind(float3 positionOS,float2 uv)
        {
            #ifdef _ENABLEWIND_ON
            float3 worldPos=TransformObjectToWorld(positionOS);
            float wind=SimplexNoise((worldPos+_TimeParameters.x*(_WindSpeed*5.0))*_WindWavesScale)*0.01;
            #ifdef _ANCHORTHEFOLIAGEBASE_ON
            wind*=uv.y*uv.y;
            #endif
            positionOS+=(wind*(_WindForce*30.0)).xxx;
            #endif
            return positionOS;
        }

        half4 SampleAlbedo(float2 uv)
        {
            return SAMPLE_TEXTURE2D(_Albedo,sampler_Albedo,uv*_Albedo_ST.xy+_Albedo_ST.zw);
        }

        //保留ASE第二颜色与透光计算
        half3 EvaluateFoliageColor(float3 positionWS,half3 normalWS,float3 viewDirWS,float4 shadowCoord,float2 uv,half4 albedoTex)
        {
            half4 albedo=_MainColor*albedoTex;
            #ifdef _COLOR2ENABLE_ON
            float overlay;
            #if defined(_SECONDCOLOROVERLAYTYPE_UV_BASED)
            overlay=uv.y;
            #else
            overlay=SimplexNoise(positionWS*_WorldScale)*0.5+0.5;
            #endif
            float mask=saturate((overlay+_SecondColorOffset)*(_SecondColorFade*2.0));
            albedo=lerp(albedo,_SecondColor*albedoTex,mask);
            #endif

            float3 mainLightDirection=SafeNormalize(_MainLightPosition.xyz);
            float translucencyMask=-dot(mainLightDirection,viewDirWS)-0.2;
            float normalTerm=dot(mainLightDirection,normalize(normalWS))+1.0;
            Light mainLight=GetMainLight(shadowCoord);
            float lightAttenuation=mainLight.distanceAttenuation*mainLight.shadowAttenuation;
            float lightIntensity=max(max(_MainLightColor.r,_MainLightColor.g),_MainLightColor.b);
            float4 lightColor=float4(_MainLightColor.rgb/lightIntensity,lightIntensity);
            float4 translucency=saturate(translucencyMask*((normalTerm*lightAttenuation)*lightColor*albedo*0.25)*_TranslucencyInt);
            return (albedo+translucency).rgb;
        }

        float4 ResolveShadowCoord(float3 positionWS,float4 interpolatedShadowCoord)
        {
            #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
            return interpolatedShadowCoord;
            #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
            return TransformWorldToShadowCoord(positionWS);
            #else
            return 0;
            #endif
        }

        LitVaryings LitVertex(Attributes input)
        {
            LitVaryings output=(LitVaryings)0;
            UNITY_SETUP_INSTANCE_ID(input);
            UNITY_TRANSFER_INSTANCE_ID(input,output);
            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

            input.positionOS.xyz=ApplyWind(input.positionOS.xyz,input.uv);
            VertexPositionInputs positionInputs=GetVertexPositionInputs(input.positionOS.xyz);
            VertexNormalInputs normalInputs=GetVertexNormalInputs(input.normalOS,input.tangentOS);

            output.positionCS=positionInputs.positionCS;
            output.positionWS=positionInputs.positionWS;
            output.normalWS=normalInputs.normalWS;
            output.uv=input.uv;

            #if defined(LIGHTMAP_ON)
            OUTPUT_LIGHTMAP_UV(input.lightmapUV,unity_LightmapST,output.lightmapUVOrVertexSH.xy);
            #else
            OUTPUT_SH(normalInputs.normalWS,output.lightmapUVOrVertexSH.xyz);
            #endif
            #if defined(DYNAMICLIGHTMAP_ON)
            output.dynamicLightmapUV=input.dynamicLightmapUV*unity_DynamicLightmapST.xy+unity_DynamicLightmapST.zw;
            #endif

            half3 vertexLight=VertexLighting(positionInputs.positionWS,normalInputs.normalWS);
            output.fogFactorAndVertexLight=half4(ComputeFogFactor(positionInputs.positionCS.z),vertexLight);
            #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
            output.shadowCoord=GetShadowCoord(positionInputs);
            #endif
            return output;
        }

        SimpleVaryings SimpleVertex(Attributes input)
        {
            SimpleVaryings output=(SimpleVaryings)0;
            UNITY_SETUP_INSTANCE_ID(input);
            UNITY_TRANSFER_INSTANCE_ID(input,output);
            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

            input.positionOS.xyz=ApplyWind(input.positionOS.xyz,input.uv);
            VertexPositionInputs positionInputs=GetVertexPositionInputs(input.positionOS.xyz);
            output.positionCS=positionInputs.positionCS;
            output.positionWS=positionInputs.positionWS;
            output.normalWS=TransformObjectToWorldNormal(input.normalOS);
            output.uv=input.uv;
            return output;
        }

        InputData BuildInputData(LitVaryings input)
        {
            InputData data=(InputData)0;
            data.positionWS=input.positionWS;
            data.positionCS=input.positionCS;
            data.normalWS=NormalizeNormalPerPixel(input.normalWS);
            data.viewDirectionWS=SafeNormalize(_WorldSpaceCameraPos-input.positionWS);
            data.shadowCoord=ResolveShadowCoord(input.positionWS,input.shadowCoord);
            data.fogCoord=input.fogFactorAndVertexLight.x;
            data.vertexLighting=input.fogFactorAndVertexLight.yzw;

            float3 vertexSH=input.lightmapUVOrVertexSH.xyz;
            #if defined(DYNAMICLIGHTMAP_ON)
            data.bakedGI=SAMPLE_GI(input.lightmapUVOrVertexSH.xy,input.dynamicLightmapUV,vertexSH,data.normalWS);
            #else
            data.bakedGI=SAMPLE_GI(input.lightmapUVOrVertexSH.xy,vertexSH,data.normalWS);
            #endif
            data.normalizedScreenSpaceUV=GetNormalizedScreenSpaceUV(input.positionCS);
            data.shadowMask=SAMPLE_SHADOWMASK(input.lightmapUVOrVertexSH.xy);

            #if defined(DEBUG_DISPLAY)
            #if defined(DYNAMICLIGHTMAP_ON)
            data.dynamicLightmapUV=input.dynamicLightmapUV;
            #endif
            #if defined(LIGHTMAP_ON)
            data.staticLightmapUV=input.lightmapUVOrVertexSH.xy;
            #else
            data.vertexSH=vertexSH;
            #endif
            #endif
            return data;
        }

        SurfaceData BuildSurfaceData(LitVaryings input,InputData inputData)
        {
            SurfaceData surface=(SurfaceData)0;
            half4 albedoTex=SampleAlbedo(input.uv);
            float4 shadowCoord=ResolveShadowCoord(input.positionWS,input.shadowCoord);
            surface.albedo=EvaluateFoliageColor(input.positionWS,inputData.normalWS,inputData.viewDirectionWS,shadowCoord,input.uv,albedoTex);
            surface.metallic=0;
            surface.specular=0.5;
            surface.smoothness=saturate(SAMPLE_TEXTURE2D(_SmoothnessTexture,sampler_SmoothnessTexture,input.uv*_SmoothnessTexture_ST.xy+_SmoothnessTexture_ST.zw).r*_Smoothness);
            surface.normalTS=half3(0,0,1);
            surface.occlusion=1;
            surface.emission=0;
            surface.alpha=albedoTex.a;
            surface.clearCoatMask=0;
            surface.clearCoatSmoothness=1;
            return surface;
        }

        void AlphaClip(float2 uv,float cutoff)
        {
            clip(SampleAlbedo(uv).a-cutoff);
        }
        ENDHLSL

        Pass
        {
            Name "Forward"
            Tags{"LightMode"="UniversalForward"}
            Blend One Zero,One Zero
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM
            #pragma vertex LitVertex
            #pragma fragment ForwardFragment
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF
            #pragma shader_feature_local _ENABLEWIND_ON
            #pragma shader_feature_local _ANCHORTHEFOLIAGEBASE_ON
            #pragma shader_feature_local _COLOR2ENABLE_ON
            #pragma shader_feature_local _SECONDCOLOROVERLAYTYPE_WORLD_POSITION _SECONDCOLOROVERLAYTYPE_UV_BASED
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _FORWARD_PLUS
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile _ EVALUATE_SH_MIXED EVALUATE_SH_VERTEX
            #pragma multi_compile_fragment _ DEBUG_DISPLAY
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
            #if defined(LOD_FADE_CROSSFADE)
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

            half4 ForwardFragment(LitVaryings input
            #ifdef _WRITE_RENDERING_LAYERS
            ,out float4 outRenderingLayers:SV_Target1
            #endif
            ):SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                #if defined(LOD_FADE_CROSSFADE)
                LODFadeCrossFade(input.positionCS);
                #endif

                InputData inputData=BuildInputData(input);
                SurfaceData surfaceData=BuildSurfaceData(input,inputData);
                clip(surfaceData.alpha-_AlphaCutoff);
                #ifdef _DBUFFER
                ApplyDecalToSurfaceData(input.positionCS,surfaceData,inputData);
                #endif

                half4 color=UniversalFragmentPBR(inputData,surfaceData);
                color.rgb=MixFog(color.rgb,inputData.fogCoord);
                #ifdef _WRITE_RENDERING_LAYERS
                uint renderingLayers=GetMeshRenderingLayer();
                outRenderingLayers=float4(EncodeMeshRenderingLayer(renderingLayers),0,0,0);
                #endif
                return color;
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode"="ShadowCaster"}
            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM
            #pragma vertex ShadowVertex
            #pragma fragment ShadowFragment
            #pragma shader_feature_local _ENABLEWIND_ON
            #pragma shader_feature_local _ANCHORTHEFOLIAGEBASE_ON
            #pragma multi_compile_instancing
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            #if defined(LOD_FADE_CROSSFADE)
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

            SimpleVaryings ShadowVertex(Attributes input)
            {
                SimpleVaryings output=(SimpleVaryings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input,output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                input.positionOS.xyz=ApplyWind(input.positionOS.xyz,input.uv);
                float3 positionWS=TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS=TransformObjectToWorldNormal(input.normalOS);
                #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                float3 lightDirectionWS=normalize(_LightPosition-positionWS);
                #else
                float3 lightDirectionWS=_LightDirection;
                #endif
                float4 positionCS=TransformWorldToHClip(ApplyShadowBias(positionWS,normalWS,lightDirectionWS));
                #if UNITY_REVERSED_Z
                positionCS.z=min(positionCS.z,UNITY_NEAR_CLIP_VALUE);
                #else
                positionCS.z=max(positionCS.z,UNITY_NEAR_CLIP_VALUE);
                #endif

                output.positionCS=positionCS;
                output.positionWS=positionWS;
                output.normalWS=normalWS;
                output.uv=input.uv;
                return output;
            }

            half4 ShadowFragment(SimpleVaryings input):SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                AlphaClip(input.uv,_AlphaCutoff);
                #if defined(LOD_FADE_CROSSFADE)
                LODFadeCrossFade(input.positionCS);
                #endif
                return 0;
            }
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode"="DepthOnly"}
            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            #pragma vertex SimpleVertex
            #pragma fragment DepthOnlyFragment
            #pragma shader_feature_local _ENABLEWIND_ON
            #pragma shader_feature_local _ANCHORTHEFOLIAGEBASE_ON
            #pragma multi_compile_instancing
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            #if defined(LOD_FADE_CROSSFADE)
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

            half4 DepthOnlyFragment(SimpleVaryings input):SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                AlphaClip(input.uv,_AlphaCutoff);
                #if defined(LOD_FADE_CROSSFADE)
                LODFadeCrossFade(input.positionCS);
                #endif
                return 0;
            }
            ENDHLSL
        }

        Pass
        {
            Name "Meta"
            Tags{"LightMode"="Meta"}
            Cull Off

            HLSLPROGRAM
            #pragma vertex MetaVertex
            #pragma fragment FoliageMetaFragment
            #pragma shader_feature EDITOR_VISUALIZATION
            #pragma shader_feature_local _ENABLEWIND_ON
            #pragma shader_feature_local _ANCHORTHEFOLIAGEBASE_ON
            #pragma shader_feature_local _COLOR2ENABLE_ON
            #pragma shader_feature_local _SECONDCOLOROVERLAYTYPE_WORLD_POSITION _SECONDCOLOROVERLAYTYPE_UV_BASED
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MetaInput.hlsl"

            struct MetaVaryings
            {
                float4 positionCS:SV_POSITION;
                float3 positionWS:TEXCOORD0;
                half3 normalWS:TEXCOORD1;
                float2 uv:TEXCOORD2;
                #ifdef EDITOR_VISUALIZATION
                float4 VizUV:TEXCOORD3;
                float4 LightCoord:TEXCOORD4;
                #endif
            };

            MetaVaryings MetaVertex(Attributes input)
            {
                MetaVaryings output=(MetaVaryings)0;
                input.positionOS.xyz=ApplyWind(input.positionOS.xyz,input.uv);
                output.positionWS=TransformObjectToWorld(input.positionOS.xyz);
                output.normalWS=TransformObjectToWorldNormal(input.normalOS);
                output.uv=input.uv;
                output.positionCS=MetaVertexPosition(input.positionOS,input.lightmapUV,input.lightmapUV,unity_LightmapST,unity_DynamicLightmapST);
                #ifdef EDITOR_VISUALIZATION
                float2 vizUV=0;
                float4 lightCoord=0;
                UnityEditorVizData(input.positionOS.xyz,input.uv,input.lightmapUV,input.dynamicLightmapUV,vizUV,lightCoord);
                output.VizUV=float4(vizUV,0,0);
                output.LightCoord=lightCoord;
                #endif
                return output;
            }

            half4 FoliageMetaFragment(MetaVaryings input):SV_Target
            {
                half4 albedoTex=SampleAlbedo(input.uv);
                clip(albedoTex.a-_AlphaCutoff);
                float3 viewDirWS=SafeNormalize(_WorldSpaceCameraPos-input.positionWS);
                half3 baseColor=EvaluateFoliageColor(input.positionWS,input.normalWS,viewDirWS,0,input.uv,albedoTex);

                MetaInput metaInput=(MetaInput)0;
                metaInput.Albedo=baseColor;
                metaInput.Emission=0;
                #ifdef EDITOR_VISUALIZATION
                metaInput.VizUV=input.VizUV.xy;
                metaInput.LightCoord=input.LightCoord;
                #endif
                return UnityMetaFragment(metaInput);
            }
            ENDHLSL
        }

        Pass
        {
            Name "Universal2D"
            Tags{"LightMode"="Universal2D"}
            Blend One Zero,One Zero
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM
            #pragma vertex SimpleVertex
            #pragma fragment Universal2DFragment
            #pragma shader_feature_local _ENABLEWIND_ON
            #pragma shader_feature_local _ANCHORTHEFOLIAGEBASE_ON
            #pragma shader_feature_local _COLOR2ENABLE_ON
            #pragma shader_feature_local _SECONDCOLOROVERLAYTYPE_WORLD_POSITION _SECONDCOLOROVERLAYTYPE_UV_BASED

            half4 Universal2DFragment(SimpleVaryings input):SV_Target
            {
                half4 albedoTex=SampleAlbedo(input.uv);
                clip(albedoTex.a-_AlphaCutoff);
                float3 viewDirWS=SafeNormalize(_WorldSpaceCameraPos-input.positionWS);
                half3 baseColor=EvaluateFoliageColor(input.positionWS,input.normalWS,viewDirWS,0,input.uv,albedoTex);
                return half4(baseColor,albedoTex.a);
            }
            ENDHLSL
        }

        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode"="DepthNormals"}
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM
            #pragma vertex SimpleVertex
            #pragma fragment DepthNormalsFragment
            #pragma shader_feature_local _ENABLEWIND_ON
            #pragma shader_feature_local _ANCHORTHEFOLIAGEBASE_ON
            #pragma multi_compile_instancing
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"
            #if defined(LOD_FADE_CROSSFADE)
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

            void DepthNormalsFragment(SimpleVaryings input,out half4 outNormalWS:SV_Target0
            #ifdef _WRITE_RENDERING_LAYERS
            ,out float4 outRenderingLayers:SV_Target1
            #endif
            )
            {
                UNITY_SETUP_INSTANCE_ID(input);
                AlphaClip(input.uv,_AlphaCutoff);
                #if defined(LOD_FADE_CROSSFADE)
                LODFadeCrossFade(input.positionCS);
                #endif

                float3 normalWS=NormalizeNormalPerPixel(input.normalWS);
                #if defined(_GBUFFER_NORMALS_OCT)
                float2 octNormalWS=PackNormalOctQuadEncode(normalWS);
                float2 remappedOctNormalWS=saturate(octNormalWS*0.5+0.5);
                half3 packedNormalWS=PackFloat2To888(remappedOctNormalWS);
                outNormalWS=half4(packedNormalWS,0);
                #else
                outNormalWS=half4(normalWS,0);
                #endif
                #ifdef _WRITE_RENDERING_LAYERS
                uint renderingLayers=GetMeshRenderingLayer();
                outRenderingLayers=float4(EncodeMeshRenderingLayer(renderingLayers),0,0,0);
                #endif
            }
            ENDHLSL
        }

        Pass
        {
            Name "GBuffer"
            Tags{"LightMode"="UniversalGBuffer"}
            Blend One Zero,One Zero
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM
            #pragma vertex LitVertex
            #pragma fragment GBufferFragment
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF
            #pragma shader_feature_local _ENABLEWIND_ON
            #pragma shader_feature_local _ANCHORTHEFOLIAGEBASE_ON
            #pragma shader_feature_local _COLOR2ENABLE_ON
            #pragma shader_feature_local _SECONDCOLOROVERLAYTYPE_WORLD_POSITION _SECONDCOLOROVERLAYTYPE_UV_BASED
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            #pragma multi_compile_fragment _ _RENDER_PASS_ENABLED
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fragment _ DEBUG_DISPLAY
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"
            #if defined(LOD_FADE_CROSSFADE)
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

            FragmentOutput GBufferFragment(LitVaryings input)
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                #if defined(LOD_FADE_CROSSFADE)
                LODFadeCrossFade(input.positionCS);
                #endif

                InputData inputData=BuildInputData(input);
                SurfaceData surfaceData=BuildSurfaceData(input,inputData);
                clip(surfaceData.alpha-_AlphaCutoff);
                #ifdef _DBUFFER
                ApplyDecal(input.positionCS,surfaceData.albedo,surfaceData.specular,inputData.normalWS,surfaceData.metallic,surfaceData.occlusion,surfaceData.smoothness);
                #endif

                BRDFData brdfData;
                InitializeBRDFData(surfaceData.albedo,surfaceData.metallic,surfaceData.specular,surfaceData.smoothness,surfaceData.alpha,brdfData);
                Light mainLight=GetMainLight(inputData.shadowCoord,inputData.positionWS,inputData.shadowMask);
                MixRealtimeAndBakedGI(mainLight,inputData.normalWS,inputData.bakedGI,inputData.shadowMask);
                half3 indirect=GlobalIllumination(brdfData,inputData.bakedGI,surfaceData.occlusion,inputData.positionWS,inputData.normalWS,inputData.viewDirectionWS);
                return BRDFDataToGbuffer(brdfData,inputData,surfaceData.smoothness,surfaceData.emission+indirect,surfaceData.occlusion);
            }
            ENDHLSL
        }

        Pass
        {
            Name "SceneSelectionPass"
            Tags{"LightMode"="SceneSelectionPass"}
            Cull Off

            HLSLPROGRAM
            #pragma vertex SimpleVertex
            #pragma fragment SceneSelectionFragment
            #pragma shader_feature_local _ENABLEWIND_ON
            #pragma shader_feature_local _ANCHORTHEFOLIAGEBASE_ON

            half4 SceneSelectionFragment(SimpleVaryings input):SV_Target
            {
                //ASE编辑器选择Pass固定使用0.01裁剪阈值
                AlphaClip(input.uv,0.01);
                return half4(_ObjectId,_PassValue,1,1);
            }
            ENDHLSL
        }

        Pass
        {
            Name "ScenePickingPass"
            Tags{"LightMode"="Picking"}

            HLSLPROGRAM
            #pragma vertex SimpleVertex
            #pragma fragment ScenePickingFragment
            #pragma shader_feature_local _ENABLEWIND_ON
            #pragma shader_feature_local _ANCHORTHEFOLIAGEBASE_ON

            half4 ScenePickingFragment(SimpleVaryings input):SV_Target
            {
                //ASE编辑器拾取Pass固定使用0.01裁剪阈值
                AlphaClip(input.uv,0.01);
                return _SelectionID;
            }
            ENDHLSL
        }
    }

    CustomEditor "UnityEditor.ShaderGraphLitGUI"
    FallBack "Hidden/Shader Graph/FallbackError"
}
