Shader "MyShader/Sky/StylizedSky"
{
    Properties
    {
        // 高空区域
        [HDR]_UpSunColor("高空近太阳颜色",Color) = (0.20, 0.45, 1.00, 1)
        [HDR]_UpSkyColor("高空远太阳颜色",Color) = (0.05, 0.20, 0.55, 1)

        // 地平线区域
        [HDR]_DownSunColor("地平线近太阳颜色",Color) = (0.65, 0.75, 1.00, 1)
        [HDR]_DownSkyColor("地平线远太阳颜色",Color) = (0.25, 0.45, 0.75, 1)

        // 控制天空上下渐变
        _VerticalRange("天空垂直渐变范围",Range(0.01, 1)) = 0.45

        // 控制太阳附近颜色影响范围
        _SunGather("近太阳颜色聚集程度",Range(0, 5)) = 0.3

        // 由脚本写入
        [HideInInspector]
        _SunDirection("太阳方向",Vector) = (0, 1, 0, 0)
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Background"
            "RenderType" = "Background"
            "RenderPipeline" = "UniversalPipeline"
            "PreviewType" = "Skybox"
        }

        Cull Off
        ZWrite Off


        Pass
        {
            Name "Sky"

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag


            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // Mesh 输入
            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                // 当前天空像素所对应的方向
                float3 directionWS : TEXCOORD0;
            };

            // Material 参数
            CBUFFER_START(UnityPerMaterial)

                float4 _UpSunColor;
                float4 _UpSkyColor;

                float4 _DownSunColor;
                float4 _DownSkyColor;

                float _VerticalRange;
                float _SunGather;

                float4 _SunDirection;

            CBUFFER_END

            Varyings vert(Attributes input)
            {
                Varyings output;

                float3 positionWS =TransformObjectToWorld( input.positionOS.xyz);
                output.positionCS =TransformWorldToHClip(positionWS);
                output.directionWS =normalize(positionWS);

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                // 当前天空方向
                float3 viewDirection =normalize(input.directionWS);

                // 当前方向朝上多少
                // Y：
                // 1 = 天顶
                // 0 = 地平线
                float height = saturate(viewDirection.y);

                //调整天空上下渐变范围

                float verticalFactor =saturate(height /max(_VerticalRange, 0.001));

                verticalFactor =smoothstep(0.0,1.0,verticalFactor);

                // 计算当前方向是否靠近太阳
                // dot：
                // 1   = 正对太阳
                // 0   = 90°
                // -1  = 完全背向太阳

                float sunDot =dot(viewDirection,normalize(_SunDirection.xyz));
                float sunFactor =saturate(sunDot * 0.5 + 0.5);

                //控制太阳颜色聚集程度
                float gatherPower =lerp(1.0,8.0,saturate(_SunGather/ 5.0));
                sunFactor =pow(sunFactor,gatherPower);

                // 高空颜色
                float3 upperColor =lerp(_UpSkyColor.rgb,_UpSunColor.rgb,sunFactor);

                //地平线颜色
                float3 lowerColor =lerp(_DownSkyColor.rgb,_DownSunColor.rgb,sunFactor);

                //地平线 → 天顶

                float3 finalColor =lerp(lowerColor,upperColor,verticalFactor);

                return half4(finalColor,1);
            }

            ENDHLSL
        }
    }
}