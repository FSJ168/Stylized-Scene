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
        _IrradianceMap("Irradiance Map",2D)="black"{}
        _IrradianceMapRRange("天空主色垂直变化范围",Range(0.01,1))=0.45

        //太阳圆盘
        [HDR]_SunColor("太阳圆盘颜色",Color)=(1.0,0.85,0.55,1)
        _SunIntensity("太阳圆盘强度",Range(0,10))=2.0
        _SunAngularRadius("太阳圆盘半径",Range(0.1,10))=1.2
        _SunEdgeSoftness("太阳圆盘边缘柔和度",Range(0.01,5))=0.25

        //太阳外围Glow
        [HDR]_SunGlowColor("太阳外围散射颜色",Color)=(1.0,0.55,0.20,1)
        _SunGlowIntensity("太阳外围散射强度",Range(0,5))=0.6
        _SunGlowPower("太阳外围散射聚集程度",Range(1,128))=16

        // 控制太阳附近颜色影响范围
        _SunGather("近太阳颜色聚集程度",Range(0, 5)) = 0.3

        //太阳追加色
        [HDR]_SunAdditionColor("太阳追加天空颜色",Color)=(1.0,0.55,0.18,1)
        _SunAdditionIntensity("太阳追加颜色强度",Range(0,3))=0.8
        _IrradianceMapGRange("太阳追加色垂直变化范围",Range(0.01,1))=0.7

        //日出日落地平线散射
        [HDR]_SunsetScatterColor("日出日落散射颜色",Color)=(1.0,0.22,0.06,1)
        _SunsetScatterIntensity("日出日落散射强度",Range(0,5))=1.0
        _SunsetScatterPower("日出日落太阳聚集程度",Range(1,32))=5.0
        _HorizonScatterWidth("地平线散射宽度",Range(0.01,1))=0.35

        //月亮
        _MoonTex("Moon Map",2D)="white"{}
        [HDR]_MoonColor("月亮颜色",Color)=(0.85,0.9,1.0,1)
        _MoonIntensity("月亮强度",Range(0,10))=1.2
        _MoonAngularRadius("月亮盘半径",Range(0.1,10))=1.2
        _MoonEdgeSoftness("月亮边缘柔和度",Range(0.01,5))=0.15
        _MoonGlowIntensity("月亮辉光强度",Range(0,5))=0.15
        [HDR]_MoonGlowColor("月亮辉光颜色",Color)=(0.5,0.65,1.0,1)
        _MoonGlowPower("月亮辉光聚集程度",Range(1,128))=48
        _MoonVisibility("月亮可见度",Range(0,1))=1

        //星空
        _StarDotMap("Star Dot Map",2D)="black"{}
        _NoiseMap("Star Noise Map",2D)="gray"{}
        _StarColorLut("Star Color LUT",2D)="white"{}
        [HDR]_StarColorIntensity("星星颜色强度",Color)=(4,4,4,1)
        _StarIntensityLinearDamping("星星出现阈值",Range(0,0.99))=0.8
        _StarNoiseSpeed("星星闪烁速度",Range(0,1))=0.15
        _StarVisibility("星星可见度",Range(0,1))=1

        //银河
        _GalaxyTex("银河贴图",2D)="black"{}
        [HDR]_GalaxyColor("银河颜色",Color)=(1.0,1.0,1.0,1)
        _GalaxyIntensity("银河强度",Range(0,5))=1.0
        _GalaxyVisibility("银河可见度",Range(0,1))=1
        _GalaxyAlphaPower("银河边缘锐化",Range(1,20))=8.0
        _GalaxyHorizonFade("银河地平线淡出范围",Range(0.01,1))=0.25
        _GalaxyRotation("银河水平旋转速度",Range(0,360))=0

        // 由脚本写入
        [HideInInspector]
        _SunDirection("太阳方向",Vector) = (0, 1, 0, 0)
        [HideInInspector]
        _MoonDirection("月亮方向",Vector)=(0,1,0,0)
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
            #define INV_HALF_PI 0.63661977236



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

            TEXTURE2D(_IrradianceMap);
            SAMPLER(sampler_IrradianceMap);
            
            TEXTURE2D(_MoonTex);
            SAMPLER(sampler_MoonTex);

            TEXTURE2D(_StarDotMap);
            SAMPLER(sampler_StarDotMap);

            TEXTURE2D(_NoiseMap);
            SAMPLER(sampler_NoiseMap);

            TEXTURE2D(_StarColorLut);
            SAMPLER(sampler_StarColorLut);

            TEXTURE2D(_GalaxyTex);
            SAMPLER(sampler_GalaxyTex);

            CBUFFER_START(UnityPerMaterial)

                float4 _UpSunColor;
                float4 _UpSkyColor;

                float4 _DownSunColor;
                float4 _DownSkyColor;
                
                float4 _SunColor;
                float _SunIntensity;
                float _SunAngularRadius;
                float _SunEdgeSoftness;

                float4 _SunGlowColor;
                float _SunGlowIntensity;
                float _SunGlowPower;

                float _SunGather;
                float _IrradianceMapRRange;

                float4 _SunDirection;

                float4 _SunAdditionColor;
                float _SunAdditionIntensity;

                float4 _SunsetScatterColor;

                float _SunsetScatterIntensity;
                float _SunsetScatterPower;
                float _HorizonScatterWidth;
                float _IrradianceMapGRange;

                float4 _MoonColor;
                //月亮
                float _MoonIntensity;
                float _MoonAngularRadius;
                float _MoonEdgeSoftness;

                float4 _MoonGlowColor;
                float _MoonGlowIntensity;
                float _MoonGlowPower;

                float _MoonVisibility;
                float4 _MoonDirection;

                //星星
                float4 _StarColorIntensity;

                float _StarIntensityLinearDamping;
                float _StarNoiseSpeed;
                float _StarVisibility;

                float4 _StarDotMap_ST;
                float4 _NoiseMap_ST;

                //银河
                float4 _GalaxyColor;

                float _GalaxyIntensity;
                float _GalaxyVisibility;
                float _GalaxyAlphaPower;
                float _GalaxyHorizonFade;
                float _GalaxyRotation;

                float4 _GalaxyTex_ST;

            CBUFFER_END
            
            float2 DirectionToLatLongUV(float3 direction)
            {
                direction=normalize(direction);
                float u=atan2(direction.x,direction.z)*0.15915494309+0.5;
                float v=asin(clamp(direction.y,-1.0,1.0))*0.31830988618+0.5;
                return float2(u,v);
            }

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
                //当前天空观察方向
                float3 viewDirection=normalize(input.directionWS);

                //太阳方向
                float3 sunDirection =normalize(_SunDirection.xyz);
                //月亮方向
                float3 moonDirection=normalize(_MoonDirection.xyz);
                
                //太阳的距离关系
                float sunDot =dot(viewDirection,sunDirection);
                float sunRemap =saturate(sunDot * 0.5 + 0.5);
                //月亮的距离关系
                float moonDot=dot(viewDirection,moonDirection);
                float moonRemap01=saturate(moonDot);

                //计算天空高度
                float skyY=viewDirection.y;
                float skyHeight =saturate(skyY);

                //地平线上方Mask
                float aboverHorizonMask=smoothstep(-0.01,0.02,skyY);
                //月亮地平线判断
                float moonAboverHorizon=smoothstep(-0.02,0.03,moonDirection.y);
                //太阳地平线判断
                float sunAboverHorizon=smoothstep(-0.02,0.03,sunDirection.y);

                //太阳圆盘大小
                float sunRadiusCos=cos(radians(_SunAngularRadius));
                float sunSoftCos=cos(radians(_SunAngularRadius+_SunEdgeSoftness));
                //月亮圆盘大小
                float moonRadiusCos=cos(radians(_MoonAngularRadius));
                float moonSoftCos=cos(radians(_MoonAngularRadius+_MoonEdgeSoftness));
                
                //太阳圆盘
                float sunDiskMask=smoothstep(sunSoftCos,sunRadiusCos,sunDot);
                float3 sunDiskColor=_SunColor.rgb*_SunIntensity*sunDiskMask*aboverHorizonMask;
                //月亮圆盘
                float moonDiskMask=smoothstep(moonSoftCos,moonRadiusCos,moonDot);
                moonDiskMask*=aboverHorizonMask*_MoonVisibility;
                
                //建立moonRight/Up
                float3 worldUp=float3(0,1,0);
                float3 fallbackUp=abs(dot(moonDirection,worldUp))>0.99?float3(0,0,1):worldUp;
                float3 moonRight=normalize(cross(fallbackUp,moonDirection));
                float3 moonUp=normalize(cross(moonDirection,moonRight));
                
                //将天空方向投影到月亮平面
                float moonPlaneX=dot(viewDirection,moonRight);
                float moonPlaneY=dot(viewDirection,moonUp);
                //将投影映射成月亮UV
                float moonScale=max(sin(radians(_MoonAngularRadius)),0.0001);
                float2 moonUV=float2(moonPlaneX,moonPlaneY)/(moonScale*2.0)+0.5;
                
                //采样月亮贴图
                float4 moonTex=SAMPLE_TEXTURE2D(_MoonTex,sampler_MoonTex,moonUV);
                float moonTexAlpha=moonTex.a;
                float3 moonDiskColor=moonTex.rgb*_MoonColor.rgb*_MoonIntensity*moonDiskMask*moonTexAlpha;
                
                //月亮边缘辉光
                float safeMoonGlowPower=max(_MoonGlowPower,1.0);
                float moonGlowMask=pow(moonRemap01,safeMoonGlowPower);
                moonGlowMask*=aboverHorizonMask*_MoonVisibility;
                float3 moonGlowColor=_MoonGlowColor.rgb*_MoonGlowIntensity*moonGlowMask;

                //太阳边缘
                float sunGlowMask=pow(sunRemap,_SunGlowPower);
                float3 sunGlowColor=_SunGlowColor*_SunGlowIntensity*sunGlowMask*aboverHorizonMask;

                //天空高度转换为“角度”
                float verticalAngle =asin(skyHeight)* INV_HALF_PI;

                //星空UV
                float2 skyUV=DirectionToLatLongUV(viewDirection);
                //采样星点分布图_StarDotMap
                float2 starUV=skyUV*_StarDotMap_ST.xy+_StarDotMap_ST.zw;
                float starSample=SAMPLE_TEXTURE2D(_StarDotMap,sampler_StarDotMap,starUV).r;
                
                //星空闪烁噪声
                float2 starNoiseUV1=skyUV*_NoiseMap_ST.xy+_NoiseMap_ST.zw;
                starNoiseUV1+=_Time.y*_StarNoiseSpeed*float2(0.04,0.02);
                float starNoise1=SAMPLE_TEXTURE2D(_NoiseMap,sampler_NoiseMap,starNoiseUV1).r;
                
                float2 starNoiseUV2=skyUV*_NoiseMap_ST.xy*2+_NoiseMap_ST.zw;
                starNoiseUV2+=_Time.x*_StarNoiseSpeed*float2(0.01,0.05);
                float starNoise2=SAMPLE_TEXTURE2D(_NoiseMap,sampler_NoiseMap,starNoiseUV2).r;
                
                float starExist=starSample*starNoise1*starNoise2;
                //星星强弱噪声
                float2 starColorNoiseUV=skyUV*20.0;
                starColorNoiseUV+=_Time.y*_StarNoiseSpeed*0.01;
                float starColorNoise=SAMPLE_TEXTURE2D(_NoiseMap,sampler_NoiseMap,starColorNoiseUV);
                
                //星星亮度筛选
                float starDamping=(starColorNoise-_StarIntensityLinearDamping)/(max(1.0-_StarIntensityLinearDamping,0.01));
                starDamping=saturate(starDamping);

                //星空高度Mask
                float starHeightMask=saturate(verticalAngle*1.5);
                starHeightMask*=aboverHorizonMask;

                //采样StarColorLUT
                float2 starLutUV=float2(saturate(starColorNoise),0.5);
                float3 starColorLut=SAMPLE_TEXTURE2D(_StarColorLut,sampler_StarColorLut,starLutUV).rgb;
                
                //月亮附近星光遮罩
                //月亮核心附近
                float moonStarInnerCos=cos(radians(_MoonAngularRadius*1.5));
                //月亮外围
                float moonStarOuterCos=cos(radians(_MoonAngularRadius*4.0));
                float moonStarProximity=smoothstep(moonStarOuterCos,moonStarInnerCos,moonRemap01);
                float moonStarExclusion=1.0-moonStarProximity*moonAboverHorizon*_MoonVisibility;

                //最终星星颜色
                float starIntensity=starExist*starDamping*starHeightMask*3.0*_StarVisibility;
                float3 finalStarColor=starColorLut*_StarColorIntensity.rgb*starIntensity*moonStarExclusion;

                //银河UV
                float galaxyRotationOffset=_GalaxyRotation/360.0;
                float2 galaxyUV=skyUV;
                galaxyUV.x+=galaxyRotationOffset*_Time.x;
                galaxyUV=galaxyUV*_GalaxyTex_ST.xy+_GalaxyTex_ST.zw;

                //采样银河贴图
                float4 galaxyTex=SAMPLE_TEXTURE2D(_GalaxyTex,sampler_GalaxyTex,galaxyUV);

                //银河边缘软硬
                float galaxyAlpha=pow(saturate(galaxyTex.a),max(_GalaxyAlphaPower,1.0));
                
                //银河高度Mask
                float galaxyHeightMask=smoothstep(0.0,max(_GalaxyHorizonFade,0.001),skyHeight);
                galaxyHeightMask*=aboverHorizonMask;

                //月亮附近银河Mask
                float moonGalaxyInnerCos=cos(radians(_MoonAngularRadius*2.0));
                float moonGalaxyOuterCos=cos(radians(_MoonAngularRadius*6.0));
                float moonGalaxyProximity=smoothstep(moonGalaxyOuterCos,moonGalaxyInnerCos,moonRemap01);
                float moonGalaxyExclusion=1.0-moonGalaxyProximity*moonAboverHorizon*_MoonVisibility;

                //最终银河颜色
                float3 galaxyColor=galaxyTex.rgb*_GalaxyColor*_GalaxyIntensity*galaxyAlpha*galaxyHeightMask*moonGalaxyExclusion*_GalaxyVisibility;


                //SunSet:天空像素距离太阳远近
                // Power 越大：暖色越集中在太阳附近
                float sunsetSunFactor=pow(sunRemap,_SunsetScatterPower);
                
                //地平线Mask
                //width越大地平线高度范围越小
                float horizonFactor=1-smoothstep(0.0,_HorizonScatterWidth,skyHeight);
                horizonFactor=smoothstep(1.0-_HorizonScatterWidth,1.0,horizonFactor)*aboverHorizonMask;
                float sunsetScatterMask=sunsetSunFactor*horizonFactor*aboverHorizonMask;
                sunsetScatterMask=smoothstep(0.02,0.6,sunsetScatterMask);
                float3 sunsetScatterColor=_SunsetScatterColor.rgb*_SunsetScatterIntensity*sunsetScatterMask;


                //IrradianceMap R 通道
                //控制天空主颜色的上下过渡
                float irradianceR_U =verticalAngle/max(_IrradianceMapRRange,0.001);

                float irradianceR =
                    SAMPLE_TEXTURE2D(
                        _IrradianceMap,
                        sampler_IrradianceMap,
                        float2(
                            irradianceR_U,
                            0.5
                        )
                    ).r;

                // 7. 控制近太阳颜色覆盖范围

                float gatherPower =
                    lerp(
                        1.0,
                        8.0,
                        saturate(
                            _SunGather / 5.0
                        )
                    );


                float sunColorFactor =
                    pow(
                        sunRemap,
                        gatherPower
                    );


                // 8. 计算高空颜色
                //
                // 远太阳 → 近太阳

                float3 upperColor =
                    lerp(
                        _UpSkyColor.rgb,
                        _UpSunColor.rgb,
                        sunColorFactor
                    );


                // 9. 计算地平线颜色

                float3 lowerColor =
                    lerp(
                        _DownSkyColor.rgb,
                        _DownSunColor.rgb,
                        sunColorFactor
                    );


                // 10. IrradianceMap.R 决定上下天空混合
                //
                // 注意：
                //
                // 原作者逻辑基本是：
                //
                // R = 0 → 高空颜色
                // R = 1 → 地平线颜色

                float3 mainSkyColor =
                    lerp(
                        upperColor,
                        lowerColor,
                        irradianceR
                    );


                // 11. IrradianceMap G
                //
                // 用来控制太阳追加颜色的垂直分布。

                float irradianceG_U =
                    verticalAngle /
                    max(
                        _IrradianceMapGRange,
                        0.001
                    );


                float irradianceG =
                    SAMPLE_TEXTURE2D(
                        _IrradianceMap,
                        sampler_IrradianceMap,
                        float2(
                            irradianceG_U,
                            0.5
                        )
                    ).g;


                // 12. 判断太阳当前高度
                //
                // sunDirection.y 接近 0：
                // 太阳接近地平线
                //
                // abs(y) 越大：
                // 太阳越靠近天空顶部 / 底部

                float sunHeightFactor =
                    saturate(
                        (
                            abs(sunDirection.y)
                            - 0.2
                        )
                        * (10.0 / 3.0)
                    );


                sunHeightFactor =
                    smoothstep(
                        0.0,
                        1.0,
                        sunHeightFactor
                    );


                // 13. 当太阳靠近地平线时，
                // 追加颜色更多集中在太阳附近。

                float sunDirectionFactor =
                    smoothstep(
                        0.0,
                        1.0,
                        (
                            sunRemap - 0.3
                        )
                        / 0.7
                    );


                // 14. 太阳高度控制“追加颜色”分布方式
                //
                // 太阳低：
                // 主要集中在太阳方向
                //
                // 太阳高：
                // 更多依赖 IrradianceMap 的高度分布

                float additionFactor =
                    lerp(
                        sunDirectionFactor,
                        1.0,
                        sunHeightFactor
                    );


                // 15. 最终太阳追加颜色

                float3 sunAddition =
                    irradianceG
                    * _SunAdditionColor.rgb
                    * _SunAdditionIntensity
                    * additionFactor;


                // 16. 最终天空

                float3 finalColor =
                    mainSkyColor
                    + sunAddition
                    + sunGlowColor
                    + sunsetScatterColor
                    + sunDiskColor
                    +finalStarColor
                    +galaxyColor
                    + moonGlowColor
                    + moonDiskColor;

                return half4(
                    finalColor,
                    1
                );
            }

            ENDHLSL
        }
    }
}