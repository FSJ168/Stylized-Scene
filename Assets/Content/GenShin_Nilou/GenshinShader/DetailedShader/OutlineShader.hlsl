#ifndef CUSTOM_AVATAR_GENSHIN_OUTLINE_PASS_INCLUDED
#define CUSTOM_AVATAR_GENSHIN_OUTLINE_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Utils.hlsl"
#include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

struct CharOutlineAttributes{
    float4 positionOS:POSITION;
    float3 normalOS:NORMAL;
    float2 smoothNormal:TEXCOORD7;
    float2 uv1:TEXCOORD0;
    float2 uv2:TEXCOORD1;
    float4 tangentOS:TANGENT;
    float4 color:COLOR;
    float2 packSmoothNormal:TEXCOORD2;
};

struct CharOutlineVaryings{
    float4 positionCS:SV_POSITION;
    float4 color:COLOR;
    float2 baseUV:TEXCOORD0;
    float3 normalWS:TEXCOORD1;
    float3 positionWS:TEXCOORD2;
    real fogFactor:TEXCOORD3;
};

float3 GetSmoothNormalWS(CharOutlineAttributes input,VertexNormalInputs vertexNormalInput){
    float3 smoothNormalOS=input.normalOS;
    //允许在编译时选择不同的法线来源
    #ifdef _OUTLINENORMALCHANNEL_NORMAL
    //直接使用顶点法线
    smoothNormalOS=input.normalOS;
    #elif _OUTLINENORMALCHANNEL_TANGENT
    //使用切线向量作为法线
    smoothNormalOS=input.tangentOS.xyz;
    #elif _OUTLINENORMALCHANNEL_UV2
        float3 normalOS=normalize(input.normalOS);
        float3 tangentOS=normalize(input.tangentOS.xyz);
        float3 bitangentOS=normalize(cross(normalOS,tangentOS)*(input.tangentOS.w*GetOddNegativeScale()));
        float3 smoothNormalTS=UnpackNormalOctQuadEncode(input.packSmoothNormal);//八面体法线编码
        smoothNormalOS=mul(smoothNormalTS,float3x3(tangentOS,bitangentOS,normalOS));//TBN矩阵变换将切线空间中存储的法线，变换回物体空间。
    
    #endif
    #if _OUTLINE_USE_SMOOTHNORMAL_ON
        float3 smoothNormal = DecodeNormalOct(input.smoothNormal); // 解码UV7的2D法线
        float3 tangentWS=vertexNormalInput.tangentWS;
        float3 normalWS=vertexNormalInput.normalWS;
        float3 bitangentWS=vertexNormalInput.bitangentWS;

        float3x3 tangentToWorld=half3x3(tangentWS.xyz,bitangentWS.xyz,normalWS.xyz);
        float3 smoothNormalWS=NormalizeNormalPerPixel(TransformTangentToWorld(smoothNormal,tangentToWorld));
        return smoothNormalWS;
    #endif

    return TransformObjectToWorldNormal(smoothNormalOS);

}

float GetOutlineWidth(float positionVS_Z)
{
    //FOV补偿因子计算（fovY=垂直视场角）
    float fovFactor = 2.414 / UNITY_MATRIX_P[1].y;//即fy(FOV=45度时的fy值)
    float z = abs(positionVS_Z * fovFactor);

    //参数化宽度曲线
    float4 params = _OutlineWidthParams;
    // params.x = zNear  (深度范围起点)                                         │
    // params.y = zFar   (深度范围终点)                                         │
    // params.z = wNear  (近处宽度系数)                                         │
    // params.w = wFar   (远处宽度系数)  

    // 步骤1: 计算归一化深度因子 k
    float k = saturate((z - params.x) / (params.y - params.x));
    //步骤2: 线性插值宽度系数
    float width = lerp(params.z, params.w, k);

    return 0.01 * _OutlineWidth * _OutlineScale * width;// 0.01 用于将世界单位转换为合适的轮廓宽度
}

float4 GetOutlinePosition(VertexPositionInputs vertexInput,float3 normalWS,float4 vertexColor){
    float z=vertexInput.positionVS.z;
    float width=GetOutlineWidth(z)*vertexColor.a;//顶点色a通道存放描边遮罩

    //法线空间变换
    half3 normalVS=TransformWorldToViewNormal(normalWS);
    normalVS=SafeNormalize(half3(normalVS.xy,0.0));//只保留XY方向，轮廓沿屏幕平面扩展，不沿深度方向，SafeNormalize避免零向量导致NaN

    //顶点位置偏移
    float3 positionVS=vertexInput.positionVS;
    //一.深度偏移(轮廓向外—+向后偏移，解决深度值接近导致的闪烁问题)
    positionVS+=0.01*_OutlineZOffset*SafeNormalize(positionVS);
    //二.法相方向偏移(外扩距离深度相关 + Alpha控制)
    positionVS+=width*normalVS;
    //裁剪空间转换
    float4 positionCS=TransformViewToHClip(positionVS);
    positionCS.xy+=_ScreenOffset.zw*positionCS.w;//XY视图空间到裁剪空间会除以深度值w，正确偏移需乘w

    return positionCS;



}

CharOutlineVaryings BackFaceOutlineVertex(CharOutlineAttributes input){
    CharOutlineVaryings output;
    //获取顶点及法线输入
    VertexPositionInputs vertexPositionInput=GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs vertexNormalInput=GetVertexNormalInputs(input.normalOS);

    //平滑法线计算
    float3 smoothNormalWS=GetSmoothNormalWS(input,vertexNormalInput);
    //轮廓位置计算
    float4 positionCS=GetOutlinePosition(vertexPositionInput,smoothNormalWS,input.color);

    //uv处理
    output.baseUV=CombineAndTransformDualFaceUV(input.uv1,input.uv2,1);

    output.color=input.color;
    output.positionWS=vertexPositionInput.positionWS;
    output.normalWS=vertexNormalInput.normalWS;
    output.positionCS=positionCS;

    output.fogFactor=ComputeFogFactor(vertexPositionInput.positionCS.z);

    return output;

}

half4 BackFaceOutlineFragment(CharOutlineVaryings input,FRONT_FACE_TYPE isFrontFace:FRONT_FACE_SEMANTIC):SV_TARGET{
    //材质ID提取
    half outlineColorMask=SAMPLE_TEXTURE2D(_ilmTex,sampler_ilmTex,input.baseUV.xy).a;//ilm图的alpha通道存储0-1的值，映射到1——5的材质ID
    float material_id=materialID(outlineColorMask);//floor(colormask*5.0)+1

    //多颜色轮廓系统
    float4 outline_colors[5]={
        _OutlineColor1,_OutlineColor2,_OutlineColor3,_OutlineColor4,_OutlineColor5
    };

    half3 finalOutlineColor=0;

    #if _OUTLINE_CUSTOM_COLOR_ON
        finalOutlineColor=_OutlineCol.rgb;
    #else
        finalOutlineColor=outline_colors[material_id-1].xyz;
    #endif

    //Alpha裁剪测试
    float alpha=_Alpha;
    float4 FinalColor=float4(finalOutlineColor,alpha);
    DoClipTestToTargetAlphaValue(FinalColor.a,_AlphaClip);//小于_AlphaClip值则丢弃像素
    

    

    return float4(FinalColor.rgb,1.0);

}

#endif
