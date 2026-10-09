#ifndef CUSTOM_AVATAR_GENSHIN_PASS_INCLUDED
#define CUSTOM_AVATAR_GENSHIN_PASS_INCLUDED

#define CHARACTER_DISSOLVE_DISTANCE 500.0    // 溶解生效的最大距离
#define EDGE_BLUR_AMOUNT 0.05               // 溶解边缘模糊程度
#define UV_SCALE 1.0                        // 屏幕UV缩放比例

#include "InputShader.hlsl"
#include "SpecularHelper.hlsl"
#include "Utils.hlsl"
#include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

struct CoreAttributes{
    float4 positionOS:POSITION;
    float3 normalOS:NORMAL;
    float4 tangentOS:TANGENT;
    float4 vertexColor:COLOR;
    float2 uv1:TEXCOORD0;
    float2 uv2:TEXCOORD1;

};

struct CoreVaryings{
    float4 positionCS:SV_POSITION;
    float3 positionWS:TEXCOORD0;
    float3 normalWS:TEXCOORD1;
    float4 uv:TEXCOORD2;
    float3 tangentWS:TEXCOORD3;
    float3 bitangentWS:TEXCOORD4;
    float3 SH:TEXCOORD5;
    real fogFactor:TEXCOORD6;
    float4 vertexColor:COLOR;
};

struct FCharacterDissolveInput
{
    float3 CameraPositionWS;      // 世界空间相机位置
    float3 ObjectPositionWS;      // 世界空间角色/物体中心位置
    float4 ScreenPosition;        // 屏幕位置（用于生成屏幕UV）
    float4x4 ViewProjectionMatrix;// 视投影矩阵（可选，用于验证）
};

struct FCharacterDissolveOutput
{
    float DissolveAlpha;          // 最终溶解Alpha值（0=完全溶解，1=不溶解）
    float CurveTime;              // 归一化的距离值（0-1）
    float EdgeBlurFactor;         // 边缘模糊因子
};


//顶点着色器
CoreVaryings GenshinStyleVertex(CoreAttributes input){
    CoreVaryings output=(CoreVaryings)0;

    //获取顶点位置和法线输入
    VertexPositionInputs vertexPositionInputs=GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs vertexNormalInputs=GetVertexNormalInputs(input.normalOS.xyz,input.tangentOS);

    //填充世界空间和裁剪空间数据
    output.positionWS=vertexPositionInputs.positionWS;
    output.positionCS=vertexPositionInputs.positionCS;
    output.tangentWS=vertexNormalInputs.tangentWS;
    output.bitangentWS=vertexNormalInputs.bitangentWS;
    output.normalWS=vertexNormalInputs.normalWS;
    output.uv=CombineAndTransformDualFaceUV(input.uv1,input.uv2,1);//todo 换成0会怎样
    output.vertexColor=input.vertexColor;

    //球谐函数采样（间接光照）
    //获得低频环境光        
    output.SH=SampleSH(lerp(vertexNormalInputs.normalWS,float3(0,1,0),_IndirectLightFlattenNormal));//_INdirectLightFlattenNormal值越大法线越扁平

    //雾效计算
    output.fogFactor=ComputeFogFactor(vertexPositionInputs.positionCS.z);

    return output;
}

half4 GenshinStyleFragment(CoreVaryings input,FRONT_FACE_TYPE isFrontFace:FRONT_FACE_SEMANTIC):SV_Target{
    //双面渲染设置
    SetupDualFaceRendering(input.normalWS,input.uv,isFrontFace);

    half4 mainTexCol = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv.xy);
    //给背面填充颜色，对眼睛，丝袜很有用
    mainTexCol.rgb*=IS_FRONT_VFACE(isFrontFace,_FrontFaceTintColor.rgb,_BackFaceTintColor.rgb);//根据正反面返回不同颜色

    //ILM纹理多通道使用
    half4 ilmTexCol=SAMPLE_TEXTURE2D(_ilmTex,sampler_ilmTex,input.uv.xy);

    //阴影坐标
    float4 shadowCoord=TransformWorldToShadowCoord(input.positionWS);
    Light mainLight=GetCharacterMainLightStruct(shadowCoord,input.positionWS);
    mainLight=ApplyCharacterIndoorMainLight(mainLight);
    float4 LightColor=float4(mainLight.color.rgb,1);
    #if _MAINLIGHT_SHADOWATTENUATION_ON
        float shadowAttenuation=mainLight.shadowAttenuation;
    #else
        float shadowAttenuation=1;
    #endif

    //主光源方向
    float3 lightDirectionWS=normalize(mainLight.direction.xyz);
    float3 viewDirectionWS=normalize(GetWorldSpaceViewDir(input.positionWS));
    //material Index
    float material_id=materialID(ilmTexCol.w);//ilm.w储存着材质ID
    float sunMoon=step(0.5,_EnvironmentNeightWeight);

    //获取世界空间法线，如果需要采样normalMap，需要使用TBN矩阵变换
    #if _NORMAL_MAP_ON
        float3x3 tangentToWorld=float3x3(input.tangentWS,input.bitangentWS,input.normalWS);
        float3 normalTS=UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,input.uv.xy));
        float3 normalFactor=float3(_BumpFactor,_BumpFactor,1);//_bumpFactor控制法线强弱
        float3 normal=normalize(normalTS*normalFactor);
        float3 normalWS=TransformTangentToWorld(normal,tangentToWorld,true);
        input.normalWS=normalWS;
    #else
        float3 normalWS=normalize(input.normalWS);
    #endif

    float NoV=dot(normalize(input.normalWS),normalize(GetWorldSpaceViewDir(input.positionWS)));
    half aoFactor=ilmTexCol.g*input.vertexColor.r;//ilm.g储存了环境光遮蔽,vertexColor.r对不同区域Ao强度进行局部微调
    float shadow = GetShadow(normalWS, lightDirectionWS, aoFactor, shadowAttenuation);

    //环境亮度
    float environmentBrightness=GetEnvironmentBrightnessFactor(input.SH);
    //主光亮度
    float mainLightBrightness=GetMainLightBrightnessFactor(mainLight.color);
    //主光真实亮度
    float rawMainLightBrightness=max(max(mainLight.color.r,mainLight.color.g),mainLight.color.b);
    //主光阴影影响权重
    float mainLightShadowWeight=smoothstep(0.05,0.2,rawMainLightBrightness);
    //最终光照亮度
    float directLightBrightness=environmentBrightness*mainLightBrightness;
    
    float emissionFactor=1.0;
    //判断emission是否开启
    #if _EMISSION_ON
        #if defined(_MAINTEXALPHAUSE_EMISSION)
            emissionFactor=_EmissionScaler*mainTexCol.a;
        #elif defined(_MAINTEXALPHAUSE_FLICKER)
            emissionFactor=_EmissionScaler*mainTexCol.a*(0.5*sin(_Time.y)+0.5);
        #elif defined(_MAINTEXALPHAUSE_ALPHATEST)
            DoClipTestToTargetAlphaValue(mainTexCol.a,_MainTexCutOff);
            emissionFactor=0;
        #else
            emissionFactor=0;
        #endif
    #else
        emissionFactor=0;
    #endif


    //区分面部和身体的渲染
    #if defined(_RENDERTYPE_BODY)
        //Diffuse
        half3 diffuseColor=0;
        float bodyShadow=lerp(0.0,shadow,mainLightShadowWeight);
        half3 rampTexCol=GetShadowRampColor(bodyShadow,ilmTexCol,sunMoon);//shadow是亮暗分界线的源头
        half3 brightAreaColor=rampTexCol*_LightAreaColorTint.rgb;//亮部区域颜色
        half3 darkShadowColor=rampTexCol*lerp(_DarkShadowColor.rgb,_CoolDarkShadowColor.rgb,_EnvironmentNeightWeight);//为1应用冷色暗部阴影
        half3 ShadowColorTint=lerp(darkShadowColor.rgb,brightAreaColor.rgb,_BrightAreaShadowFac*mainLightShadowWeight);
        
        //高光与金属
        half3 specular=(float3)0.0f;
        #if _SPECULAR_ON
            float3 half_vector=normalize(viewDirectionWS+mainLight.direction);//计算半程向量H=normalize(L+V)
            float ndoth=dot(normalWS,half_vector);//=1高光最强(法线与半程向量对齐) 

            //SPECULAR
            if(_SpecularHighlights) specular_color(ndoth,ShadowColorTint,ilmTexCol.x,ilmTexCol.z,material_id,specular);
            if(ilmTexCol.x>0.90f) specular=0.0f;//金属区域不高光

            //METALIC
            if(_MetalMaterial){
                half3 originalMetalColor=mainTexCol.rgb;
                half3 metalColor=mainTexCol.rgb;
                metalics(shadow,normalWS,ndoth,ilmTexCol.x,metalColor);
                mainTexCol.rgb=lerp(originalMetalColor,metalColor,mainLightShadowWeight);
            }
            
            specular*=mainLightBrightness*mainLightShadowWeight;

        #endif
        diffuseColor = ShadowColorTint * mainTexCol.rgb;    
        diffuseColor*=directLightBrightness;

        //Environment GI
        float3 indirectLightColor=CalculateGI(mainTexCol.rgb,aoFactor,input.SH.rgb,_IndirectLightIntensity,_IndirectLightUsage);

        //Additional Light
        float3 additionalLightColor=CalculateCharacterAdditionalLights(input.positionWS,normalWS,mainTexCol.rgb,aoFactor);

        //边缘光
        half3 rimLightColor=0.0;
        #if _RIM_LIGHTING_ON
            if(IS_FRONT_VFACE(isFrontFace,1,0))//背面不渲染边缘光
            {
                rimLightColor=GetRimLight(input.positionCS,normalWS,LightColor.rgb,material_id);
            }
        #endif

        half3 emissionColor=lerp(_EmissionTintColor.rgb,mainTexCol.rgb,_EmissionMixBaseColorFac)*emissionFactor;

        //最终的合成
        float3 FinalDiffuse=0;
        FinalDiffuse+=indirectLightColor;
        FinalDiffuse+=diffuseColor;
        FinalDiffuse+=additionalLightColor;
        FinalDiffuse+=specular;
        FinalDiffuse+=rimLightColor;
        FinalDiffuse+=emissionColor;

        float alpha = _Alpha;
        alpha=alpha;//*Output.DissolveAlpha;
        float4 FinalColor = float4(FinalDiffuse, alpha);
        DoClipTestToTargetAlphaValue(FinalColor.a, _AlphaClip);
        
        //Mix Fog
        real fogFactor=InitializeInputDataFog(float4(input.positionWS,1),input.fogFactor);
        FinalColor.rgb=MixFog(FinalColor.rgb,fogFactor);

        return FinalColor;
    #elif defined(_RENDERTYPE_FACE)
        // 游戏模型的头骨骼是旋转过的，需要取反校正 
        float3 headDirWSUp = normalize(-UNITY_MATRIX_M._m00_m10_m20);
        float3 headDirWSRight = normalize(-UNITY_MATRIX_M._m02_m12_m22);
        float3 headDirWSForward = normalize(UNITY_MATRIX_M._m01_m11_m21);

        //SDF阴影系统
        float3 lightDirProj=normalize(lightDirectionWS-dot(lightDirectionWS,headDirWSUp)*headDirWSUp);//减去光照向量在上下方向的分量，得到水平平面的投影
        bool isRight=dot(lightDirProj,headDirWSRight)>0;//SDF图从左到右值递增，光照在右侧时需反转uv.x
        float sdfUVx=lerp(input.uv.x,1-input.uv.x,isRight);
        float2 sdfUV=float2(sdfUVx,input.uv.y);

        float sdfValue=0.0;
        //使用uv采样面部贴图的a通道
        #if defined(_USEFACELIGHTMAPCHANNEL_R)
            sdfValue=SAMPLE_TEXTURE2D(_FaceShadowMap,sampler_FaceShadowMap,sdfUV).r;
        #else
            sdfValue = SAMPLE_TEXTURE2D(_FaceShadowMap, sampler_FaceShadowMap, sdfUV).a;
        #endif

        sdfValue+=_FaceShadowOffset;//阴影整体偏移
        //SDF阴影判定（平滑过渡）
        float FoL01=dot(headDirWSForward,lightDirProj)*0.5+0.5;//FoL01值越大，说明光源越朝向面部前方，面部应该越亮；值越小，光源越在面部后方，面部应该越暗。
        float sdfShadow=smoothstep(FoL01-_FaceShadowTransitionSoftness,FoL01+_FaceShadowTransitionSoftness,1-sdfValue);//sdfvalue储存亮部信息，但我们需要阴影信息，要进行反转，
        float brightAreaMask=(1-sdfShadow)*shadowAttenuation*mainLightShadowWeight;//全局阴影衰减

        half3 rampTexCol=GetShadowRampColor(shadow,ilmTexCol,sunMoon);
        half3 diffuseColor = 0;
        half3 brightAreaColor = rampTexCol * _LightAreaColorTint.rgb;
        half3 darkShadowColor = rampTexCol * lerp(_DarkShadowColor.rgb, _CoolDarkShadowColor.rgb, _EnvironmentNeightWeight);
        half3 ShadowColorTint = lerp(darkShadowColor, brightAreaColor, brightAreaMask);

        diffuseColor = ShadowColorTint * mainTexCol.rgb;
        diffuseColor*=directLightBrightness;
        //遮罩贴图的rg通道区分受光照影响的区域和不受影响的区域
        half3 faceDiffuseColor=lerp(mainTexCol.rgb*directLightBrightness,diffuseColor,ilmTexCol.r);

        // Face Environment GI

        float3 indirectLightColor =CalculateGI(mainTexCol.rgb,aoFactor,input.SH.rgb,_IndirectLightIntensity,_IndirectLightUsage);
        float3 additionalLightColor =CalculateCharacterAdditionalLights(input.positionWS,normalWS,mainTexCol.rgb,aoFactor);
        //边缘光部分
        half3 rimLightColor=0;
        #if _RIM_LIGHTING_ON
            if(IS_FRONT_VFACE(isFrontFace,1,0)){
                rimLightColor=GetRimLight(input.positionCS,normalWS,LightColor.rgb,material_id);
            }
        #endif

        half3 emissionColor=lerp(_EmissionTintColor.rgb,mainTexCol.rgb,_EmissionMixBaseColorFac)*emissionFactor;
        float3 FinalDiffuse=0;
        FinalDiffuse+=indirectLightColor;
        FinalDiffuse+=faceDiffuseColor;
        FinalDiffuse+=additionalLightColor;
        FinalDiffuse+=rimLightColor;
        FinalDiffuse+=emissionColor;

        float alpha=_Alpha;
        alpha=alpha;//*Output.DissolveAlpha;
        float4 FinalColor=float4(FinalDiffuse,alpha);
        DoClipTestToTargetAlphaValue(FinalColor.a,_AlphaClip);

        //Mix Fog
        real fogFactor=InitializeInputDataFog(float4(input.positionWS,1.0),input.fogFactor);
        FinalColor.rgb=MixFog(FinalColor,fogFactor);

        return FinalColor;
    
    #endif

    return float4(1,1,1,1);
}
#endif
