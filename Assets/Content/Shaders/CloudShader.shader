Shader "MyShader/Sky/StylizedCloud"
{
    Properties
    {
        [HDR]_CloudColorA("远太阳暗部颜色", Color) = (0.45, 0.55, 0.8, 1)
        [HDR]_CloudColorB("近太阳暗部颜色", Color) = (0.8, 0.85, 1, 1)

        [HDR]_CloudColorC("远太阳亮部颜色", Color) = (0.8, 0.85, 1, 1)
        [HDR]_CloudColorD("近太阳亮部颜色", Color) = (1, 1, 1, 1)

        [HDR]_EdgeColor("太阳边缘光颜色", Color) = (1, 0.8, 0.5, 1)

        _CloudMap("Cloud Map", 2D) = "white" {}
        _NoiseMap("Noise Map", 2D) = "gray" {}

        _CloudThreshold("云形状", Range(0.003, 1.5)) = 0.5
        _NoiseStrength("扰动强度", Range(0, 0.1)) = 0.03
        _NoiseSpeed("扰动速度", Range(-1, 1)) = 0.05
        _NoiseDirection("扰动方向",Vector)=(1,1,0,0)

        // _SunDirection("太阳方向", Vector) = (0,1,0,0)
        // _MoonDirection("月亮方向", Vector) = (0,-1,0,0)

        _SunMoon("太阳/月亮切换", Range(0,1)) = 0
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }

        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite On
        Cull Off

        Pass
        {
            Name "Cloud"

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float2 uv : TEXCOORD1;
            };

            TEXTURE2D(_CloudMap);
            SAMPLER(sampler_CloudMap);

            TEXTURE2D(_NoiseMap);
            SAMPLER(sampler_NoiseMap);

            CBUFFER_START(UnityPerMaterial)

                float4 _CloudColorA;
                float4 _CloudColorB;
                float4 _CloudColorC;
                float4 _CloudColorD;

                float4 _EdgeColor;

                float4 _CloudMap_ST;
                float4 _NoiseMap_ST;

                float _CloudThreshold;
                float _NoiseStrength;
                float _NoiseSpeed;
                float4 _NoiseDirection;

                float _SunMoon;
                float4 _SunDirection;
                float4 _MoonDirection;

            CBUFFER_END

            Varyings vert(Attributes input)
            {
                Varyings output;

                output.positionWS =TransformObjectToWorld(input.positionOS.xyz);
                output.positionCS =TransformWorldToHClip(output.positionWS);
                output.uv = input.uv;

                return output;
            }


            half4 frag(Varyings input) : SV_Target
            {
                
                // 相机看向云片的方向
                float3 cloudDirection =normalize(input.positionWS -_WorldSpaceCameraPos.xyz);
                
                //太阳月亮切换
                    //获取太阳方向
                    float3 sunDirection=normalize(_SunDirection.xyz);
                    //获取月亮方向
                    float3 moonDirection=normalize(_MoonDirection.xyz);
                    //太阳影响
                    float sunLightArea=saturate(dot(sunDirection,cloudDirection));
                    sunLightArea=pow(sunLightArea,2);
                    //月亮影响
                    float moonLightArea=saturate(dot(moonDirection,cloudDirection));
                    moonLightArea=pow(moonLightArea,2);

                float lightArea=lerp(sunLightArea,moonLightArea,_SunMoon);

                //Noise UV
                float2 noiseUV =input.uv * _NoiseMap_ST.xy+ _NoiseMap_ST.zw;
                noiseUV +=_Time.x * _NoiseSpeed*_NoiseDirection;

                float4 noiseTex =SAMPLE_TEXTURE2D(_NoiseMap,sampler_NoiseMap,noiseUV);

                //使用 Noise B 通道轻微扰动 CloudMap
                float disturbance =noiseTex.b * _NoiseStrength;
                float2 cloudUV =input.uv * _CloudMap_ST.xy+ _CloudMap_ST.zw;
                cloudUV += disturbance;
                float4 cloudMap =SAMPLE_TEXTURE2D(_CloudMap,sampler_CloudMap,cloudUV);

                //通道 = SDF
                float cloudShape =smoothstep(max(_CloudThreshold - 0.08, 0),_CloudThreshold,cloudMap.b);

                //根据太阳距离选择颜色
                float3 darkColor =lerp(_CloudColorA.rgb,_CloudColorB.rgb,lightArea);
                float3 lightColor =lerp(_CloudColorC.rgb,_CloudColorD.rgb,lightArea);
                // R = 云内部明暗（云层厚度）
                float3 cloudColor =lerp(darkColor,lightColor,cloudMap.r);
                // G = 边缘光
                float3 edgeLight =_EdgeColor.rgb* cloudMap.g* lightArea;
                cloudColor += edgeLight;

                // A = 云有效区域
                float alpha =cloudShape *cloudMap.a;

                return half4(cloudColor,alpha);
            }
            ENDHLSL
        }
    }
}