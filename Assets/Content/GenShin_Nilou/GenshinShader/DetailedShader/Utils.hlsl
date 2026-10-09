#ifndef CUSTOM_AVARTAR_SHADERUTILS_INCLUDED
#define CUSTOM_AVARTAR_SHADERUTILS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

//索引安全函数防止GPU返回负数索引导致数组越界
float get_index(float material_id){
    return clamp((int)material_id-1,0,4);
}

float4 CombineAndTransformDualFaceUV(float2 uv1,float2 uv2,float4 mapST){
    return float4(uv1,uv2)*mapST.xyxy+mapST.zwzw;//xy缩放，zw偏移
}

void SetupDualFaceRendering(inout float3 normalWS,inout float4 uv,FRONT_FACE_TYPE isFrontFace){
    #if defined(_MODEL_GAME)
        if(IS_FRONT_VFACE(isFrontFace,1,0)){
            return;
        }
        // 游戏内的部分模型用了双面渲染
        // 渲染背面的时候需要调整一些值，这样就不需要修改之后的计算了

        //反向法线
        normalWS*=-1;

        //交换uv1和uv2
        #if defined(_BACKFACEUV2_ON)
            uv.xyzw=uv.zwxy;
        #endif
    #endif
}

//去饱和函数
float3 desaturation(float3 color){
    float3 grayXfer=float3(0.3,0.59,0.11);//Gray = R×0.3 + G×0.59 + B×0.11
    float grayf=dot(color,grayXfer);
    return float3(grayf,grayf,grayf);
}


//颜色亮度
float CharacterLuminance(float3 color){
    //Rec.709亮度权重
    return dot(max(color,0.0),float3(0.2126,0.7152,0.0722));
}

//环境亮度系数
float GetEnvironmentBrightnessFactor(float3 sh){
    //SH已经包含当前方向上的环境光信息
    float environmentLuminance=CharacterLuminance(sh);
    // 手动曝光
    environmentLuminance *=_EnvironmentExposure;
    // 限制上下界
    environmentLuminance =clamp(environmentLuminance,_EnvironmentMinBrightness,_EnvironmentMaxBrightness);

    // 0 = 不受环境影响
    // 1 = 完全跟随环境亮度
    return lerp(1.0,environmentLuminance,saturate(_EnvironmentBrightnessInfluence)

    );
}

//主光亮度系数
float GetMainLightBrightnessFactor(float3 lightColor)
{
    float luminance=CharacterLuminance(lightColor);

    //限制主光上下界
    luminance =clamp(luminance,_MainLightMinBrightness,_MainLightMaxBrightness);

    //0=角色完全不受主光强度影响
    //1=完全受主光控制
    return lerp(1.0,luminance,saturate(_MainLightBrightnessInfluence)
    );
}

//环境间接光
float3 CalculateGI(float3 baseColor,float aoFactor,float3 sh,float intensity,float baseColorUsage){

    float3 environmentColor =max(sh, 0.0);

    // 环境颜色控制
    // 0=环境光近似灰色，只影响亮度
    // 1=完整保留环境色
    environmentColor =
        lerp(desaturation(environmentColor),environmentColor,saturate(_EnvironmentColorInfluence));

    // 是否让环境光乘角色自身颜色
    // 0 = 环境光直接叠加
    // 1 = 环境光 × Albedo
    float3 indirectSurfaceColor =lerp(float3(1,1,1),baseColor,saturate(baseColorUsage));

    float ao =saturate(aoFactor);

    return indirectSurfaceColor*environmentColor*intensity*ao;
}

//单个额外灯染色
float3 EvaluateCharacterAdditionalLight(Light light,float3 normalWS,float3 baseColor,float aoFactor)
{

    #if defined(_LIGHT_LAYERS)
        if(!IsMatchingLightLayer(light.layerMask,GetMeshRenderingLayer()))
        {
            return float3(0,0,0);
        }

    #endif

    float NdotL=dot(normalize(normalWS),normalize(light.direction));
    float wrap =max(_AdditionalLightWrap,0.0);

    //增加染色宽度
    float diffuseTerm =saturate((NdotL + wrap) /(1.0 + wrap));

    //控制边缘软硬
    diffuseTerm =pow(max(diffuseTerm,0.0001),max(_AdditionalLightPower,0.0001));
    
    //灯光距离衰减
    float attenuation =light.distanceAttenuation;

    //AO
    float ao =lerp(1.0,saturate(aoFactor),saturate(_AdditionalLightAOInfluence));

    //染色方式0->1覆盖程度越高
    float3 surfaceColor =lerp(float3(1,1,1),baseColor,saturate(_AdditionalLightBaseColorBlend));

    float3 lighting =light.color *surfaceColor *diffuseTerm *attenuation *ao *_AdditionalLightIntensity;

    return lighting;
}

//遍历所有额外灯
float3 CalculateCharacterAdditionalLights(float3 positionWS,float3 normalWS,float3 baseColor,float aoFactor)
{
    float3 additionalLighting =float3(0,0,0);

    #if defined(_ADDITIONAL_LIGHTS)

        uint additionalLightsCount =GetAdditionalLightsCount();

        for(uint lightIndex = 0u;lightIndex < additionalLightsCount;++lightIndex)
        {
            Light additionalLight =GetAdditionalLight(lightIndex,positionWS);
            additionalLighting +=EvaluateCharacterAdditionalLight(additionalLight,normalWS,baseColor,aoFactor);
        }

    #endif

    return additionalLighting;
}

Light GetCharacterMainLightStruct(float4 shadowCoord,float3 positionWS){
    Light light=GetMainLight();

    #if defined(MAIN_LIGHT_CALCULATE_SHADOWS)
        ShadowSamplingData shadowSamplingData=GetMainLightShadowSamplingData();
        half4 shadowParams=GetMainLightShadowParams();

        shadowSamplingData.softShadowQuality=SOFT_SHADOW_QUALITY_LOW;
        light.shadowAttenuation=SampleShadowmap(TEXTURE2D_ARGS(_MainLightShadowmapTexture,sampler_LinearClampCompare),shadowCoord,shadowSamplingData,shadowParams,false);
        light.shadowAttenuation=lerp(light.shadowAttenuation,1,GetMainLightShadowFade(positionWS));
    #endif

    #ifdef _LIGHT_LAYERS
    if(!IsMatchingLightLayer(light.layerMask,GetMeshRenderingLayer())){
        light.distanceAttenuation=0;
        light.shadowAttenuation=0;
    }
    #endif
    return light;
}

half GetShadow(float3 normalWS, half3 lightDirection, half aoFactor, float shadowAttenuation)
{
    half NDotL = dot(normalWS, lightDirection);
    half halfLambert = smoothstep(0.0, _GreyFac, NDotL + _DarkFac);
    half shadow = saturate(2.0 * halfLambert * aoFactor) * shadowAttenuation;
    return lerp(shadow, 1.0, step(0.9, aoFactor));
}

float3 GetShadowRampColor(float halfLambert,float4 lightmap,float sunMoon){
    float brightMask=step(_BrightFac,halfLambert);//亮面
    //判断白天与夜晚
    float rampSampling=0.0;
    if(sunMoon==1){rampSampling=0.5;}
    //计算ramp采样条数
    float ramp0 = _RampIndex0 * -0.1 + 1.05 - rampSampling;  //0.95
    float ramp1 = _RampIndex1 * -0.1 + 1.05 - rampSampling;  //0.65
    float ramp2 = _RampIndex2 * -0.1 + 1.05 - rampSampling;  //0.75
    float ramp3 = _RampIndex3 * -0.1 + 1.05 - rampSampling;  //0.55
    float ramp4 = _RampIndex4 * -0.1 + 1.05 - rampSampling;  //0.85
    //分离lightmap.a各材质
    float lightmapA1=step(0.0,lightmap.a);//0.0
    float lightmapA2=step(0.25,lightmap.a);//0.3
    float lightmapA3=step(0.45,lightmap.a);//0.5
    float lightmapA4 = step(0.65, lightmap.a);  //0.7
    float lightmapA5 = step(0.95, lightmap.a);  //1.0
    //重组lightmap.a
    float rampV=0;
    rampV=lerp(rampV,ramp0,lightmapA1); //0.0
    rampV = lerp(rampV, ramp1, lightmapA2);  //0.3
    rampV = lerp(rampV, ramp2, lightmapA3);  //0.5
    rampV = lerp(rampV, ramp3, lightmapA4);  //0.7
    rampV = lerp(rampV, ramp4, lightmapA5);  //1.0
    //采样ramp
    float3 rampCol=SAMPLE_TEXTURE2D(_RampTex,sampler_RampTex,float2(halfLambert,rampV));
    float3 shadowRamp=lerp(rampCol,halfLambert,brightMask); //遮罩亮面
    return shadowRamp;
}

//边缘光计算函数
float3 GetRimLight(float4 positionCS,float3 normalWS,float3 LightColor,float material_id){
    //获取当前片源深度
    float linearEyeDepth=LinearEyeDepth(positionCS.z,_ZBufferParams);//将裁剪空间的非线性深度值转换为摄像机视角下的线性深度值
    //根据视线空间的法线采样左边或者右边的深度图
    float3 normalVS=mul((float3x3)UNITY_MATRIX_V,normalWS);//内置视图矩阵为4x4,此处不需要偏移
    float2 uvOffset=float2(sign(normalVS.x),0)*_RimLightWidth/(1+linearEyeDepth)/100;//计算屏幕空间偏移量，近大远小，左边往左偏，右边往右偏
    int2 loadTexPos=positionCS.xy+uvOffset*_ScaledScreenParams.xy;//X屏幕实际分辨率
    //限制左右，不采样到边界
    loadTexPos=min(max(loadTexPos,0),_ScaledScreenParams.xy-1);
    //偏移后的片源深度
    float offsetSceneDepth=LoadSceneDepth(loadTexPos);
    //转化为LinearEyeDepth
    float offsetLinearEyeDepth=LinearEyeDepth(offsetSceneDepth,_ZBufferParams);
    //深度差超过阈值，表示是边界
    float rimLight=saturate(offsetLinearEyeDepth-(linearEyeDepth+_RimLightThreshold))/_RimLightFadeout; //计算边缘光强度
    rimLight=rimLight>0.9?rimLight:0;
    float4 rim_colors[5]={
        _RimColor1,_RimColor2,_RimColor3,_RimColor4,_RimColor5
    };

    //get rim light color
    float3 rimLightColor=saturate(rim_colors[get_index(material_id)].rgb*rimLight*_RimLightTintColor);
    rimLightColor*=saturate(LightColor.rgb);
    rimLightColor*=_RimLightBrightness;

    return rimLightColor;
}

float materialID(float alpha){
    float region=alpha;
    float material=1.0f;

    material=((region>=0.8f))?2.0f:1.0f;
    material = ((region >= 0.4f && region <= 0.6f)) ? 3.0f : material;
    material = ((region >= 0.2f && region <= 0.4f)) ? 4.0f : material;
    material = ((region >= 0.6f && region <= 0.8f)) ? 5.0f : material;

    return material;
}

void DoClipTestToTargetAlphaValue(float alpha,float alphaTestThreshold){
    clip(alpha-alphaTestThreshold);
}

float4 TransformViewToHClip(float3 positionVS){
    return mul(UNITY_MATRIX_P,float4(positionVS,1));
}

float3 DecodeNormalOct(float2 enc)
{
    float3 n = float3(enc.x, enc.y, 1.0 - abs(enc.x) - abs(enc.y));
    float t = max(-n.z, 0.0);
    n.x += (n.x > 0) ? -t : t;
    n.y += (n.y > 0) ? -t : t;
    return normalize(n);
}

#endif