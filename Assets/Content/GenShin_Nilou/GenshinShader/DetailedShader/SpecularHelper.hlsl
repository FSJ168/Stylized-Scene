#ifndef CUSTOM_AVARTAR_SPECULAR_INCLUDED
#define CUSTOM_AVARTAR_SPECULAR_INCLUDED

#include "Utils.hlsl"

void metalics(float shadow,in float3 normal,float3 ndoth,float speculartex,inout float3 color){
    float shadow_transition=saturate(1.0-shadow);
    shadow_transition=saturate(shadow_transition);

    float2 sphere_uv=mul(normal,(float3x3)UNITY_MATRIX_V).xy;//将世界空间法线进行视图空间的矩阵变换，让球面映射的 UV 只和 “法线相对摄像机的朝向” 有关，而非法线相对世界的朝向
    sphere_uv.x=sphere_uv.x*_MTMapTileScale;
    sphere_uv=sphere_uv*0.5f+0.5f;

    //sample sphere map
    float sphere=_MTMap.Sample(sampler_MTMap,sphere_uv).x;
    sphere=sphere*_MTMapBrightness;
    sphere=saturate(sphere);

    //插值金属明暗色
    float3 metal_color=lerp(_MTMapDarkColor,_MTMapLightColor,sphere.xxx);
    metal_color=color*metal_color;

    ndoth=max(0.001f,ndoth);//避免ndoth==0
    ndoth=pow(ndoth,_MTShininess)*_MTSpecularScale; //高光锐利度+强度缩放
    ndoth=saturate(ndoth);

    //判断是否启用锐利高光层
    float specular_sharp=_MTSharpLayerOffset<ndoth;//布尔值

    float3 metal_specular=(float3)ndoth;
    if(specular_sharp){
        metal_specular=_MTSharpLayerColor;

    }
    else{
        if(_MTUseSpecularRamp){
            // 使用高光渐变纹理：采样Ramp纹理，叠加高光颜色和遮罩
            metal_specular=_MTSpecularRamp.Sample(sampler_MTSpecularRamp,float2(metal_specular.x,0.5f))*_MTSpecularColor;
            metal_specular=metal_specular*speculartex;
        }
        else{
            //不使用ramp，直接叠加高光颜色和遮罩
            metal_specular=metal_specular*_MTSpecularColor;
            metal_specular=metal_specular*speculartex;

        }
    }

    float3 metal_shadow=lerp(1.0f,_MTShadowMultiColor,shadow_transition);//阴影颜色衰减
    metal_specular=lerp(metal_specular,metal_specular*_MTSpecularAttenInShadow,shadow_transition); //阴影中高光衰减
    //金属最终颜色=基底色+高光色（减半）
    float3 metal=metal_color+(metal_specular*(float3)0.5);
    //叠加阴影衰减
    metal=metal*metal_shadow;

    //仅在speculartex>0.89区域启用金属效果
    float metal_area=saturate(speculartex>0.89f);//0或1
    metal=(metal_area)?metal:color;
    color.xyz=metal;
        

}

void specular_color(in float ndoth,in float3 shadow,in float lightmaparea,in float lightmapspec,in float material_id, inout float3 specular){
    float2 spec_array[5]={
        float2(_Shininess, _SpecMulti),//_shiness控制高光光泽度，_SpecMulti控制高光整体亮度
        float2(_Shininess2, _SpecMulti2),
        float2(_Shininess3, _SpecMulti3),
        float2(_Shininess4, _SpecMulti4),
        float2(_Shininess5, _SpecMulti5),       
    };

    float4 spec_color_array[5]={
        _SpecularColor, 
        _SpecularColor2, 
        _SpecularColor3, 
        _SpecularColor4, 
        _SpecularColor5, 
    };

    float term=ndoth;
    term=pow(max(ndoth,0.001f),spec_array[get_index(material_id)].x);
    float check=term>(-lightmapspec+1.015);//高光基础强度在0.015以上才显示高光
    specular=term*(spec_color_array[get_index(material_id)]*spec_array[get_index(material_id)].y)*lightmaparea;
    specular=lerp((float3)0.0f,specular,check);

}

#endif
