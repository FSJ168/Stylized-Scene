Shader "MyShader/BuildingSurface"
{
    Properties
    {
        //Metallic/普通工作流切换
        [Header(Texture Workflow)]
        [Toggle(_WORKFLOW_METALLIC)] _UseMetallicWorkflow("Use Metallic Workflow", Float) = 1

        [Header(Metallic Workflow)]
        [MainTexture] _Albedo("Albedo", 2D) = "white" {}
        _MetallicSmooth("MetallicSmooth (R = Metallic, A = Smoothness)", 2D) = "black" {}

        [Header(AlbedoSmooth Workflow)]
        _AlbedoSmooth("AlbedoSmooth (RGB = Albedo, A = Smoothness)", 2D) = "white" {}

        //公共参数
        [Header(Common)]
        [Normal] _NormalMap("Normal", 2D) = "bump" {}
        _NormalScale("Normal Strength", Range(0, 2)) = 1
        _BaseColor("Base Color Tint", Color) = (1,1,1,1)
        
        //Metallic/Smoothness/Fresnel强度控制
        [Header(Material)]
        _MetallicScale("Metallic Scale", Range(0,1)) = 1
        _SmoothnessScale("Smoothness Scale", Range(0,1)) = 1
        _FresnelRefInt("Fresnel Reference Intensity", Range(0.02,0.08)) = 0.04
        
        //Specular参数
        [Header(Specular Stability)]
        _MinRoughness("Minimum Roughness", Range(0.02,0.3)) = 0.045
        _SpecularAA("Specular AA", Range(0,1)) = 0.25
        
        //间接光参数
        [Header(Indirect Lighting)]
        _IndirectDiffuseStrength("Indirect Diffuse Strength", Range(0,1)) = 1
        _ReflectionStrength("Reflection Strength", Range(0,1)) = 1

        [Header(Emission)]
        _EmissionMap("自发光贴图",2D)="black"{}
        _EmissionIntensity("自发光强度",Range(0,2))=0
        [HDR]_EmissionTintColor("自发光色调",Color)=(1.0,1.0,1.0,1)

    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" 
                "RenderType"="Opaque" 
                "Queue"="Geometry" 
                "UniversalMaterialType"="Lit" }

        Cull Back
        ZWrite On
        ZTest LEqual

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"

        #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
        #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION

        CBUFFER_START(UnityPerMaterial)
        float4 _BaseColor;
        float4 _Albedo_ST;
        float4 _AlbedoSmooth_ST;
        float4 _MetallicSmooth_ST;
        float4 _NormalMap_ST;
        float _UseMetallicWorkflow;
        float _NormalScale;
        float _MetallicScale;
        float _SmoothnessScale;
        float _FresnelRefInt;
        float _MinRoughness;
        float _SpecularAA;
        float _IndirectDiffuseStrength;
        float _ReflectionStrength;
        float _EmissionIntensity;
        float4 _EmissionTintColor;
        CBUFFER_END

        TEXTURE2D(_Albedo); SAMPLER(sampler_Albedo);
        TEXTURE2D(_AlbedoSmooth); SAMPLER(sampler_AlbedoSmooth);
        TEXTURE2D(_MetallicSmooth); SAMPLER(sampler_MetallicSmooth);
        TEXTURE2D(_NormalMap); SAMPLER(sampler_NormalMap);
        TEXTURE2D(_EmissionMap);SAMPLER(sampler_EmissionMap);

        //数据
        struct BuildingSurfaceData
        {
            float3 baseColor;
            float metallic;
            float smoothness;
            float roughness;
        };
        
        //采样Albedo/Metallic/Smoothness
        BuildingSurfaceData SampleSurface(float2 uv)
        {
            BuildingSurfaceData surface;
            #if defined(_WORKFLOW_METALLIC)
                float2 albedoUV = uv * _Albedo_ST.xy + _Albedo_ST.zw;
                float2 metallicUV = uv * _MetallicSmooth_ST.xy + _MetallicSmooth_ST.zw;
                float4 albedoSample = SAMPLE_TEXTURE2D(_Albedo, sampler_Albedo, albedoUV);
                float4 metallicSmoothSample = SAMPLE_TEXTURE2D(_MetallicSmooth, sampler_MetallicSmooth, metallicUV);
                surface.baseColor = albedoSample.rgb * _BaseColor.rgb;
                surface.metallic = saturate(metallicSmoothSample.r * _MetallicScale);
                surface.smoothness = saturate(metallicSmoothSample.a * _SmoothnessScale);
            #else
                float2 albedoSmoothUV = uv * _AlbedoSmooth_ST.xy + _AlbedoSmooth_ST.zw;
                float4 albedoSmoothSample = SAMPLE_TEXTURE2D(_AlbedoSmooth, sampler_AlbedoSmooth, albedoSmoothUV);
                surface.baseColor = albedoSmoothSample.rgb * _BaseColor.rgb;
                surface.metallic = 0.0;
                surface.smoothness = saturate(albedoSmoothSample.a * _SmoothnessScale);
            #endif
            surface.roughness = max(1.0 - surface.smoothness, _MinRoughness);
            return surface;
        }

        //采样NormalMap
        float3 SampleNormalWS(float2 uv, float3 normalWS, float3 tangentWS, float3 bitangentWS)
        {
            float2 normalUV = uv * _NormalMap_ST.xy + _NormalMap_ST.zw;
            float4 normalSample = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, normalUV);
            float3 normalTS = UnpackNormalScale(normalSample, _NormalScale);
            return NormalizeNormalPerPixel(TransformTangentToWorld(normalTS, float3x3(tangentWS, bitangentWS, normalWS)));
        }

        float ApplySpecularAA(float roughness, float3 normalWS)
        {
            if (_SpecularAA <= 0.0001) return roughness;
            float3 normalDX = ddx(normalWS);
            float3 normalDY = ddy(normalWS);
            float variance = (dot(normalDX, normalDX) + dot(normalDY, normalDY)) * _SpecularAA;
            variance = min(variance, 0.5);
            return saturate(max(sqrt(roughness * roughness + variance), _MinRoughness));
        }

        // Cook-Torrance
            //菲涅尔
        float3 FresnelSchlick(float cosTheta, float3 F0)
        {
            return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
        }
        
            //D：法线分布函数
        float NDF_TR_GGX(float3 N, float3 H, float R)
        {
            float a = R * R;
            a = max(a, 0.02);
            float a2 = a * a;
            float NdotH = max(dot(N, H), 0.0);
            float NdotH2 = NdotH * NdotH;
            float nom = a2;
            float denom = NdotH2 * (a2 - 1.0) + 1.0;
            denom = PI * denom * denom;
            return nom / max(denom, 1e-4);
        }
        
        //G:几何遮蔽函数
        float GeometrySchlickGGXDir(float3 N, float3 Dir, float k)
        {
            float NdotDir = max(0.0, dot(N, Dir));
            float nom = NdotDir;
            float denom = NdotDir * (1.0 - k) + k;
            return nom / denom;
        }

        //同时考虑View和Light
        float GeometrySmithDir(float3 N, float3 V, float3 L, float k)
        {
            float ggx1 = GeometrySchlickGGXDir(N, V, k);
            float ggx2 = GeometrySchlickGGXDir(N, L, k);
            return ggx1 * ggx2;
        }
        
        //直接光Cook-Torrance BRDF
        half3 BRDFDrightLight(float3 N, float3 V, float3 L, half3 baseColor, float _Roughness, float _Metalic)
        {
            float3 H = normalize(V + L);
            float NDF = NDF_TR_GGX(N, H, _Roughness);
            float k = _Roughness + 1.0;
            k = k * k * 0.125;
            float G = GeometrySmithDir(N, V, L, k);
            float3 F0 = lerp(float3(_FresnelRefInt, _FresnelRefInt, _FresnelRefInt), baseColor.rgb, _Metalic);
            float3 F = FresnelSchlick(saturate(dot(H, V)), F0);
            float3 specular = (NDF * G * F) / (4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.001);
            specular /= 1.0 + specular * 0.1;
            float3 kD = (1.0 - F) * (1.0 - _Metalic);
            float3 diffuse = kD * baseColor.rgb / PI;
            return diffuse + specular;
        }
        
        //直接光漫反射+镜面反射
        float3 EvaluateCookTorrance(BuildingSurfaceData surface, float3 normalWS, float3 viewDirWS, Light light)
        {
            float3 N = normalize(normalWS);
            float3 V = normalize(viewDirWS);
            float3 L = normalize(light.direction);
            float NdotL = saturate(dot(N, L));
            float NdotV = saturate(dot(N, V));
            if (NdotL <= 0.00001 || NdotV <= 0.00001) return 0;
            float3 brdf = BRDFDrightLight(N, V, L, surface.baseColor, surface.roughness, surface.metallic);
            float3 radiance = light.color * light.distanceAttenuation * light.shadowAttenuation;
            return brdf * radiance * NdotL;
        }
        
        //环境漫反射Fresnel
        float3 FresnelSchlickRoughness(float NdotV, float3 F0, float roughness)
        {
            float factor = pow(1.0 - saturate(NdotV), 5.0);
            return F0 + (max(1.0 - roughness, F0) - F0) * factor;
        }
        
        //环境镜面反射BRDF：Cook-Torrance的近似
        float3 EnvironmentBRDFApprox(float3 F0, float roughness, float NdotV)
        {
            float4 c0 = float4(-1.0, -0.0275, -0.572, 0.022);
            float4 c1 = float4(1.0, 0.0425, 1.04, -0.04);
            float4 r = roughness * c0 + c1;
            float a004 = min(r.x * r.x, exp2(-9.28 * NdotV)) * r.x + r.y;
            float2 AB = float2(-1.04, 1.04) * a004 + r.zw;
            return F0 * AB.x + AB.y;
        }
        
        //间接光漫反射+镜面反射
        float3 EvaluateIndirectLighting(BuildingSurfaceData surface, float3 normalWS, float3 viewDirWS, float3 environmentGI,float3 positionWS,float2 screenUV)
        {
            float3 N = normalize(normalWS);
            float3 V = normalize(viewDirWS);
            float NdotV = saturate(dot(N, V));
            float3 F0 = lerp(float3(_FresnelRefInt, _FresnelRefInt, _FresnelRefInt), surface.baseColor, surface.metallic);
            float3 F = FresnelSchlickRoughness(NdotV, F0, surface.roughness);
            float3 kD = (1.0 - F) * (1.0 - surface.metallic);
            //无LightMap时来自实时Ambient Probe
            float3 indirectDiffuse = environmentGI * surface.baseColor * kD * _IndirectDiffuseStrength;

            //采样天空和Realtime Reflection probe
            float3 reflectionVector = reflect(-V, N);
            float3 prefilteredEnvironment=GlossyEnvironmentReflection(reflectionVector,positionWS,surface.roughness,1.0,screenUV);
            float3 indirectSpecular=prefilteredEnvironment*EnvironmentBRDFApprox(F0,surface.roughness,NdotV)*_ReflectionStrength;
            return indirectDiffuse + indirectSpecular;
        }
        ENDHLSL

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForwardOnly" }

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex ForwardVert
            #pragma fragment ForwardFrag
            #pragma shader_feature_local_fragment _WORKFLOW_METALLIC
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _FORWARD_PLUS
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile_fog

            struct ForwardAttributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
                float2 lightmapUV : TEXCOORD1;
            };

            struct ForwardVaryings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 tangentWS : TEXCOORD2;
                float3 bitangentWS : TEXCOORD3;
                float2 uv : TEXCOORD4;
                float3 lightmapUVOrSH : TEXCOORD5;
                float fogFactor : TEXCOORD6;
            };

            ForwardVaryings ForwardVert(ForwardAttributes IN)
            {
                ForwardVaryings OUT;
                VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                OUT.positionCS = positionInputs.positionCS;
                OUT.positionWS = positionInputs.positionWS;
                OUT.normalWS = normalInputs.normalWS;
                OUT.tangentWS = normalInputs.tangentWS;
                OUT.bitangentWS = normalInputs.bitangentWS;
                OUT.uv = IN.uv;

                //关闭LightMap时，xy 存lightmapUV，没有光照贴图：xyz 存环境球谐系数
                #if defined(LIGHTMAP_ON)
                    OUTPUT_LIGHTMAP_UV(IN.lightmapUV, unity_LightmapST, OUT.lightmapUVOrSH.xy);
                    OUT.lightmapUVOrSH.z = 0.0;
                #else
                    OUTPUT_SH(normalInputs.normalWS, OUT.lightmapUVOrSH.xyz);
                #endif
                OUT.fogFactor = ComputeFogFactor(positionInputs.positionCS.z);
                return OUT;
            }

            float4 ForwardFrag(ForwardVaryings IN) : SV_Target
            {
                BuildingSurfaceData surface = SampleSurface(IN.uv);
                float3 normalWS = SampleNormalWS(IN.uv, normalize(IN.normalWS), normalize(IN.tangentWS), normalize(IN.bitangentWS));
                surface.roughness = ApplySpecularAA(surface.roughness, normalWS);
                float3 viewDirWS = SafeNormalize(_WorldSpaceCameraPos.xyz - IN.positionWS);
                float2 screenUV=GetNormalizedScreenSpaceUV(IN.positionCS);
                float3 environmentGI=SAMPLE_GI(IN.lightmapUVOrSH.xy,IN.lightmapUVOrSH.xyz,normalWS);
                //读取ShadowMask
                //场景使用MixedLight且烘焙模式为ShadowMask时shadowMap存在烘焙静态阴影数据
                half4 shadowMask = SAMPLE_SHADOWMASK(IN.lightmapUVOrSH.xy);
                //世界坐标转级联阴影贴图采样坐标
                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                Light mainLight = GetMainLight(shadowCoord, IN.positionWS, shadowMask);
                //让URP正确处理不同Mixed Lighting模式下Realtime Direct、Baked Indirect、shadowMask之间的关系
                MixRealtimeAndBakedGI(mainLight, normalWS, environmentGI, shadowMask);
                float3 directLighting = EvaluateCookTorrance(surface, normalWS, viewDirWS, mainLight);

                #if defined(_ADDITIONAL_LIGHTS)
                    #if USE_FORWARD_PLUS
                        UNITY_LOOP
                        for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); ++lightIndex)
                        {
                            Light additionalLight = GetAdditionalLight(lightIndex, IN.positionWS, shadowMask);
                            directLighting += EvaluateCookTorrance(surface, normalWS, viewDirWS, additionalLight);
                        }
                    #endif
                    uint pixelLightCount = GetAdditionalLightsCount();
                    LIGHT_LOOP_BEGIN(pixelLightCount)
                        Light additionalLight = GetAdditionalLight(lightIndex, IN.positionWS, shadowMask);
                        directLighting += EvaluateCookTorrance(surface, normalWS, viewDirWS, additionalLight);
                    LIGHT_LOOP_END
                #endif
                
                float3 emission=SAMPLE_TEXTURE2D(_EmissionMap,sampler_EmissionMap,IN.uv).rgb;
                emission*=_EmissionIntensity*_EmissionTintColor;

                float3 finalColor = directLighting + EvaluateIndirectLighting(surface, normalWS, viewDirWS,environmentGI,IN.positionWS,screenUV)+emission;
                finalColor = MixFog(finalColor, IN.fogFactor);
                return float4(finalColor, 1.0);
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }
            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex ShadowVert
            #pragma fragment ShadowFrag
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            float3 _LightDirection;
            float3 _LightPosition;

            struct ShadowAttributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct ShadowVaryings { float4 positionCS : SV_POSITION; };

            ShadowVaryings ShadowVert(ShadowAttributes IN)
            {
                ShadowVaryings OUT;
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(IN.normalOS);
                #if defined(_CASTING_PUNCTUAL_LIGHT_SHADOW)
                    float3 lightDirectionWS = normalize(_LightPosition - positionWS);
                #else
                    float3 lightDirectionWS = _LightDirection;
                #endif
                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
                #if UNITY_REVERSED_Z
                    positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #else
                    positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #endif
                OUT.positionCS = positionCS;
                return OUT;
            }

            half4 ShadowFrag(ShadowVaryings IN) : SV_Target { return 0; }
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode"="DepthOnly" }
            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex DepthVert
            #pragma fragment DepthFrag

            struct DepthAttributes { float4 positionOS : POSITION; };
            struct DepthVaryings { float4 positionCS : SV_POSITION; };

            DepthVaryings DepthVert(DepthAttributes IN)
            {
                DepthVaryings OUT;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                return OUT;
            }

            half4 DepthFrag(DepthVaryings IN) : SV_Target { return 0; }
            ENDHLSL
        }

        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode"="DepthNormalsOnly" }
            ZWrite On

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex DepthNormalVert
            #pragma fragment DepthNormalFrag
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT

            struct DepthNormalAttributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct DepthNormalVaryings
            {
                float4 positionCS : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float3 tangentWS : TEXCOORD1;
                float3 bitangentWS : TEXCOORD2;
                float2 uv : TEXCOORD3;
            };

            DepthNormalVaryings DepthNormalVert(DepthNormalAttributes IN)
            {
                DepthNormalVaryings OUT;
                VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                OUT.positionCS = positionInputs.positionCS;
                OUT.normalWS = normalInputs.normalWS;
                OUT.tangentWS = normalInputs.tangentWS;
                OUT.bitangentWS = normalInputs.bitangentWS;
                OUT.uv = IN.uv;
                return OUT;
            }

            half4 DepthNormalFrag(DepthNormalVaryings IN) : SV_Target
            {
                float3 normalWS = SampleNormalWS(IN.uv, normalize(IN.normalWS), normalize(IN.tangentWS), normalize(IN.bitangentWS));
                #if defined(_GBUFFER_NORMALS_OCT)
                    float2 octNormalWS = PackNormalOctQuadEncode(normalWS);
                    float2 remappedOctNormalWS = saturate(octNormalWS * 0.5 + 0.5);
                    half3 packedNormalWS = PackFloat2To888(remappedOctNormalWS);
                    return half4(packedNormalWS, 0.0);
                #else
                    return half4(normalWS, 0.0);
                #endif
            }
            ENDHLSL
        }

        Pass
        {
            Name "Meta"
            Tags { "LightMode"="Meta" }
            Cull Off

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex MetaVert
            #pragma fragment MetaFrag
            #pragma shader_feature_local_fragment _WORKFLOW_METALLIC
            #pragma shader_feature EDITOR_VISUALIZATION
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/MetaPass.hlsl"

            struct MetaAttributes
            {
                float4 positionOS : POSITION;
                float2 uv0 : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                float2 uv2 : TEXCOORD2;
            };

            struct MetaVaryings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            MetaVaryings MetaVert(MetaAttributes IN)
            {
                MetaVaryings OUT;
                OUT.positionCS = UnityMetaVertexPosition(IN.positionOS.xyz, IN.uv1, IN.uv2, unity_LightmapST, unity_DynamicLightmapST);
                OUT.uv = IN.uv0;
                return OUT;
            }

            half4 MetaFrag(MetaVaryings IN) : SV_Target
            {
                BuildingSurfaceData surface = SampleSurface(IN.uv);
                float3 F0 = lerp(float3(_FresnelRefInt, _FresnelRefInt, _FresnelRefInt), surface.baseColor, surface.metallic);
                float3 diffuseReflectance = surface.baseColor * (1.0 - surface.metallic) * (1.0 - _FresnelRefInt);
                UnityMetaInput metaInput = (UnityMetaInput)0;
                metaInput.Albedo = diffuseReflectance + F0 * surface.roughness * 0.5;
                metaInput.Emission = 0.0;
                return UnityMetaFragment(metaInput);
            }
            ENDHLSL
        }
    }

    FallBack Off
}
