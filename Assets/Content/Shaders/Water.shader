Shader "MyShader/Water"
{
    Properties
    {
        [NoScaleOffset][Normal]_WavesNormal("Waves Normal", 2D) = "white" {}
        _Color1("Color 1", Color) = (0,0,0,0)
        _Color2("Color 2", Color) = (0,0,0,0)
        _Opacity("Opacity", Range(0,1)) = 0
        _Smoothness("Smoothness", Range(0,1)) = 0
        _Metallic("Metallic", Range(0,1)) = 0
        _WavesTile("Waves Tile", Float) = 1
        _WavesSpeed("Waves Speed", Range(0,1)) = 0
        _WavesNormalIntensity("Waves Normal Intensity", Range(0,2)) = 1
        _FoamContrast("Foam Contrast", Range(0,1)) = 0
        _FoamDistance("Foam Distance", Range(0,5)) = 0
        _FoamDensity("Foam Density", Range(0.1,1)) = 0.5
        _DepthDistance("Depth Distance", Float) = 0
        _RefractionScale("Refraction Scale", Range(0,1)) = 0.2
        _CoastOpacity("Coast Opacity", Range(0,1)) = 0
        [HideInInspector][ToggleOff]_ReceiveShadows("Receive Shadows", Float) = 1
    }

    SubShader
    {
        LOD 0
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent" "UniversalMaterialType"="Lit" }
        Cull Back
        ZWrite On
        ZTest LEqual

        HLSLINCLUDE
        #define _SURFACE_TYPE_TRANSPARENT 1
        #define _NORMALMAP 1
        #define _NORMAL_DROPOFF_TS 1
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

        TEXTURE2D(_WavesNormal);
        SAMPLER(sampler_WavesNormal);

        CBUFFER_START(UnityPerMaterial)
        float4 _Color1;
        float4 _Color2;
        float _Opacity;
        float _Smoothness;
        float _Metallic;
        float _WavesTile;
        float _WavesSpeed;
        float _WavesNormalIntensity;
        float _FoamContrast;
        float _FoamDistance;
        float _FoamDensity;
        float _DepthDistance;
        float _RefractionScale;
        float _CoastOpacity;
        float _ReceiveShadows;
        CBUFFER_END

        struct WaterAttributes
        {
            float4 positionOS : POSITION;
            float3 normalOS : NORMAL;
            float4 tangentOS : TANGENT;
            float2 lightmapUV : TEXCOORD1;
            float2 dynamicLightmapUV : TEXCOORD2;
            UNITY_VERTEX_INPUT_INSTANCE_ID
        };

        struct WaterVaryings
        {
            float4 positionCS : SV_POSITION;
            float4 clipPos : TEXCOORD0;
            float3 positionWS : TEXCOORD1;
            half3 normalWS : TEXCOORD2;
            half3 tangentWS : TEXCOORD3;
            half3 bitangentWS : TEXCOORD4;
            float4 lightmapUVOrVertexSH : TEXCOORD5;
            half4 fogFactorAndVertexLight : TEXCOORD6;
            #if defined(DYNAMICLIGHTMAP_ON)
            float2 dynamicLightmapUV : TEXCOORD7;
            #endif
            #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
            float4 shadowCoord : TEXCOORD8;
            #endif
            UNITY_VERTEX_INPUT_INSTANCE_ID
            UNITY_VERTEX_OUTPUT_STEREO
        };

        struct WaterSurface
        {
            float3 baseColor;
            float3 normalTS;
            float alpha;
        };

        struct SimpleAttributes
        {
            float4 positionOS : POSITION;
            UNITY_VERTEX_INPUT_INSTANCE_ID
        };

        struct SimpleVaryings
        {
            float4 positionCS : SV_POSITION;
            UNITY_VERTEX_INPUT_INSTANCE_ID
            UNITY_VERTEX_OUTPUT_STEREO
        };

        //保持ASE原本的屏幕纹理Y方向处理
        float4 GetWaterGrabScreenPos(float4 pos)
        {
            #if UNITY_UV_STARTS_AT_TOP
            float scale = -1.0;
            #else
            float scale = 1.0;
            #endif
            float4 result = pos;
            result.y = pos.w * 0.5;
            result.y = (pos.y - result.y) * _ProjectionParams.x * scale + result.y;
            return result;
        }

        float2 WaterVoronoiHash(float2 p)
        {
            p = float2(dot(p,float2(127.1,311.7)),dot(p,float2(269.5,183.3)));
            return frac(sin(p) * 43758.5453);
        }

        //只保留泡沫实际使用的平滑Voronoi距离
        float WaterVoronoi(float2 v,float time,float smoothness)
        {
            float2 cell = floor(v);
            float2 local = frac(v);
            float nearest = 8.0;
            for(int y=-1;y<=1;y++)
            {
                for(int x=-1;x<=1;x++)
                {
                    float2 offset = float2(x,y);
                    float2 cellPoint = WaterVoronoiHash(cell + offset);
                    cellPoint = sin(time + cellPoint * 6.2831) * 0.5 + 0.5;
                    float2 delta = local - offset - cellPoint;
                    float distanceValue = 0.5 * dot(delta,delta);
                    float blend = smoothstep(0.0,1.0,0.5 + 0.5 * (nearest - distanceValue) / smoothness);
                    nearest = lerp(nearest,distanceValue,blend) - smoothness * blend * (1.0 - blend);
                }
            }
            return nearest;
        }

        float3 SampleWaterNormalTS(float3 positionWS)
        {
            float waveTime = _TimeParameters.x * (_WavesSpeed * 0.1);
            float2 worldUV = positionWS.xz * _WavesTile;
            float2 direction = float2(1.0,1.0);
            float3 normalA = UnpackNormalScale(SAMPLE_TEXTURE2D(_WavesNormal,sampler_WavesNormal,worldUV + waveTime * direction),_WavesNormalIntensity);
            normalA.z = lerp(1.0,normalA.z,saturate(_WavesNormalIntensity));
            float3 normalB = UnpackNormalScale(SAMPLE_TEXTURE2D(_WavesNormal,sampler_WavesNormal,worldUV + (1.0 - waveTime) * direction),_WavesNormalIntensity);
            normalB.z = lerp(1.0,normalB.z,saturate(_WavesNormalIntensity));
            return normalA + normalB;
        }

        //统一计算水色、折射、泡沫和岸边透明度
        WaterSurface EvaluateWaterSurface(float3 positionWS,float4 clipPos)
        {
            WaterSurface water;
            float4 screenPos = ComputeScreenPos(clipPos);
            float4 screenPosNorm = screenPos / screenPos.w;
            screenPosNorm.z = UNITY_NEAR_CLIP_VALUE >= 0 ? screenPosNorm.z : screenPosNorm.z * 0.5 + 0.5;
            float sceneEyeDepth = LinearEyeDepth(SampleSceneDepth(screenPosNorm.xy),_ZBufferParams);
            float surfaceEyeDepth = LinearEyeDepth(screenPosNorm.z,_ZBufferParams);
            float depthDelta = abs(sceneEyeDepth - surfaceEyeDepth);

            float depthFactor = saturate(depthDelta / clamp(_DepthDistance,0.1,100.0));
            float4 depthColor = saturate(saturate(_Color2 * depthFactor) + saturate(_Color1 * (1.0 - depthFactor)));

            water.normalTS = SampleWaterNormalTS(positionWS);
            float4 grabScreenPos = GetWaterGrabScreenPos(screenPos);
            float4 grabScreenPosNorm = grabScreenPos / grabScreenPos.w;
            float4 sceneColor = float4(SampleSceneColor(grabScreenPosNorm.xy),1.0);
            float4 refractedUV = grabScreenPosNorm + float4(water.normalTS * (_RefractionScale * 0.1),0.0);
            float4 refractedColor = float4(SampleSceneColor(refractedUV.xy),1.0);
            float refractedEyeDepth = LinearEyeDepth(SampleSceneDepth(refractedUV.xy),_ZBufferParams);
            float waterEyeDepth = -TransformWorldToView(positionWS).z;
            float useRefraction = refractedEyeDepth > waterEyeDepth ? 1.0 : 0.0;
            float4 refraction = saturate(lerp(sceneColor,refractedColor,useRefraction));
            float4 waterColor = lerp(depthColor,refraction,depthColor);

            float2 foamUV = positionWS.xz * _WavesTile * 50.0;
            float foamTime = _TimeParameters.x * ((_WavesSpeed * 0.1) * 100.0);
            float foamVoronoi = WaterVoronoi(foamUV,foamTime,1.0 - _FoamDensity);
            float foamContrast = clamp(_FoamContrast,0.0,0.95);
            float foamDepth = depthDelta / _FoamDistance;
            float foam = saturate(pow(saturate(foamVoronoi),1.0 - foamContrast) + (1.0 - foamDepth));

            float coastDepth = depthDelta / _CoastOpacity;
            water.baseColor = (waterColor + foam).rgb;
            water.alpha = _Opacity * saturate(coastDepth);
            return water;
        }

        WaterVaryings WaterVertex(WaterAttributes IN)
        {
            WaterVaryings OUT = (WaterVaryings)0;
            UNITY_SETUP_INSTANCE_ID(IN);
            UNITY_TRANSFER_INSTANCE_ID(IN,OUT);
            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);
            VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
            VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS,IN.tangentOS);
            OUT.positionCS = positionInputs.positionCS;
            OUT.clipPos = positionInputs.positionCS;
            OUT.positionWS = positionInputs.positionWS;
            OUT.normalWS = normalInputs.normalWS;
            OUT.tangentWS = normalInputs.tangentWS;
            OUT.bitangentWS = normalInputs.bitangentWS;

            #if defined(LIGHTMAP_ON)
            OUTPUT_LIGHTMAP_UV(IN.lightmapUV,unity_LightmapST,OUT.lightmapUVOrVertexSH.xy);
            #else
            OUTPUT_SH(normalInputs.normalWS,OUT.lightmapUVOrVertexSH.xyz);
            #endif
            #if defined(DYNAMICLIGHTMAP_ON)
            OUT.dynamicLightmapUV = IN.dynamicLightmapUV * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
            #endif

            half fogFactor = ComputeFogFactor(positionInputs.positionCS.z);
            half3 vertexLight = VertexLighting(positionInputs.positionWS,normalInputs.normalWS);
            OUT.fogFactorAndVertexLight = half4(fogFactor,vertexLight);

            #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
            OUT.shadowCoord = GetShadowCoord(positionInputs);
            #endif
            return OUT;
        }

        SimpleVaryings SimpleVertex(SimpleAttributes IN)
        {
            SimpleVaryings OUT = (SimpleVaryings)0;
            UNITY_SETUP_INSTANCE_ID(IN);
            UNITY_TRANSFER_INSTANCE_ID(IN,OUT);
            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);
            OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
            return OUT;
        }

        float3 GetWaterNormalWS(WaterVaryings IN,float3 normalTS)
        {
            return NormalizeNormalPerPixel(TransformTangentToWorld(normalTS,half3x3(IN.tangentWS,IN.bitangentWS,IN.normalWS)));
        }

        InputData BuildWaterInputData(WaterVaryings IN,float3 normalTS)
        {
            InputData inputData = (InputData)0;
            inputData.positionWS = IN.positionWS;
            inputData.positionCS = IN.positionCS;
            inputData.viewDirectionWS = SafeNormalize(_WorldSpaceCameraPos.xyz - IN.positionWS);
            inputData.normalWS = GetWaterNormalWS(IN,normalTS);

            #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
            inputData.shadowCoord = IN.shadowCoord;
            #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
            inputData.shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
            #else
            inputData.shadowCoord = float4(0,0,0,0);
            #endif

            inputData.fogCoord = IN.fogFactorAndVertexLight.x;
            inputData.vertexLighting = IN.fogFactorAndVertexLight.yzw;
            float3 vertexSH = IN.lightmapUVOrVertexSH.xyz;
            #if defined(DYNAMICLIGHTMAP_ON)
            inputData.bakedGI = SAMPLE_GI(IN.lightmapUVOrVertexSH.xy,IN.dynamicLightmapUV,vertexSH,inputData.normalWS);
            #else
            inputData.bakedGI = SAMPLE_GI(IN.lightmapUVOrVertexSH.xy,vertexSH,inputData.normalWS);
            #endif
            inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.positionCS);
            inputData.shadowMask = SAMPLE_SHADOWMASK(IN.lightmapUVOrVertexSH.xy);
            return inputData;
        }

        SurfaceData BuildWaterSurfaceData(WaterSurface water)
        {
            SurfaceData surfaceData = (SurfaceData)0;
            surfaceData.albedo = water.baseColor;
            surfaceData.metallic = saturate(_Metallic);
            surfaceData.specular = half3(0.5,0.5,0.5);
            surfaceData.smoothness = saturate(_Smoothness);
            surfaceData.normalTS = water.normalTS;
            surfaceData.occlusion = 1.0;
            surfaceData.emission = 0.0;
            surfaceData.alpha = saturate(water.alpha);
            surfaceData.clearCoatMask = 0.0;
            surfaceData.clearCoatSmoothness = 1.0;
            return surfaceData;
        }
        ENDHLSL

        Pass
        {
            Name "Forward"
            Tags { "LightMode"="UniversalForward" }
            Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
            ZWrite On
            ZTest LEqual
            ColorMask RGBA

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex WaterVertex
            #pragma fragment ForwardFragment
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ EVALUATE_SH_MIXED EVALUATE_SH_VERTEX
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
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
            #define SHADERPASS SHADERPASS_FORWARD
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"

            half4 ForwardFragment(WaterVaryings IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);
                WaterSurface water = EvaluateWaterSurface(IN.positionWS,IN.clipPos);
                InputData inputData = BuildWaterInputData(IN,water.normalTS);
                SurfaceData surfaceData = BuildWaterSurfaceData(water);
                #ifdef _DBUFFER
                ApplyDecalToSurfaceData(IN.positionCS,surfaceData,inputData);
                #endif
                half4 color = UniversalFragmentPBR(inputData,surfaceData);
                color.rgb = MixFog(color.rgb,inputData.fogCoord);
                return color;
            }
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode"="DepthOnly" }
            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex SimpleVertex
            #pragma fragment DepthOnlyFragment

            half4 DepthOnlyFragment(SimpleVaryings IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);
                return 0;
            }
            ENDHLSL
        }

        Pass
        {
            Name "Universal2D"
            Tags { "LightMode"="Universal2D" }
            Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
            ZWrite On
            ZTest LEqual
            ColorMask RGBA

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex WaterVertex
            #pragma fragment Universal2DFragment

            half4 Universal2DFragment(WaterVaryings IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);
                WaterSurface water = EvaluateWaterSurface(IN.positionWS,IN.clipPos);
                return half4(water.baseColor,saturate(water.alpha));
            }
            ENDHLSL
        }

        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode"="DepthNormals" }
            ZWrite On
            ZTest LEqual
            Blend One Zero

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex WaterVertex
            #pragma fragment DepthNormalsFragment
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT

            half4 DepthNormalsFragment(WaterVaryings IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);
                float3 normalTS = SampleWaterNormalTS(IN.positionWS);
                float3 normalWS = GetWaterNormalWS(IN,normalTS);
                #if defined(_GBUFFER_NORMALS_OCT)
                float2 octNormalWS = PackNormalOctQuadEncode(normalize(IN.normalWS));
                float2 remappedOctNormalWS = saturate(octNormalWS * 0.5 + 0.5);
                half3 packedNormalWS = PackFloat2To888(remappedOctNormalWS);
                return half4(packedNormalWS,0.0);
                #else
                return half4(normalWS,0.0);
                #endif
            }
            ENDHLSL
        }

        Pass
        {
            Name "GBuffer"
            Tags { "LightMode"="UniversalGBuffer" }
            Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
            ZWrite On
            ZTest LEqual
            ColorMask RGBA

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex WaterVertex
            #pragma fragment GBufferFragment
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF
            #pragma multi_compile_fog
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
            #define SHADERPASS SHADERPASS_GBUFFER
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"

            FragmentOutput GBufferFragment(WaterVaryings IN)
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);
                WaterSurface water = EvaluateWaterSurface(IN.positionWS,IN.clipPos);
                InputData inputData = BuildWaterInputData(IN,water.normalTS);
                float3 baseColor = water.baseColor;
                float3 specular = float3(0.5,0.5,0.5);
                float metallic = saturate(_Metallic);
                float smoothness = saturate(_Smoothness);
                float occlusion = 1.0;
                half alpha = saturate(water.alpha);

                #ifdef _DBUFFER
                ApplyDecal(IN.positionCS,baseColor,specular,inputData.normalWS,metallic,occlusion,smoothness);
                #endif

                BRDFData brdfData;
                InitializeBRDFData(baseColor,metallic,specular,smoothness,alpha,brdfData);
                Light mainLight = GetMainLight(inputData.shadowCoord,inputData.positionWS,inputData.shadowMask);
                MixRealtimeAndBakedGI(mainLight,inputData.normalWS,inputData.bakedGI,inputData.shadowMask);
                half3 gi = GlobalIllumination(brdfData,inputData.bakedGI,occlusion,inputData.positionWS,inputData.normalWS,inputData.viewDirectionWS);
                return BRDFDataToGbuffer(brdfData,inputData,smoothness,gi,occlusion);
            }
            ENDHLSL
        }

        Pass
        {
            Name "SceneSelectionPass"
            Tags { "LightMode"="SceneSelectionPass" }
            Cull Off

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex SimpleVertex
            #pragma fragment SceneSelectionFragment
            int _ObjectId;
            int _PassValue;

            half4 SceneSelectionFragment(SimpleVaryings IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);
                return half4(_ObjectId,_PassValue,1.0,1.0);
            }
            ENDHLSL
        }

        Pass
        {
            Name "ScenePickingPass"
            Tags { "LightMode"="Picking" }

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex SimpleVertex
            #pragma fragment ScenePickingFragment
            float4 _SelectionID;

            half4 ScenePickingFragment(SimpleVaryings IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);
                return _SelectionID;
            }
            ENDHLSL
        }
    }

    Fallback Off
}
