#ifndef CHARACTER_INDOOR_LIGHTING_INCLUDED
#define CHARACTER_INDOOR_LIGHTING_INCLUDED

float _IndoorLightingWeight;
float4 _IndoorMainLightDirection;
float4 _IndoorMainLightColor;

//只覆盖角色使用的主方向光，不修改场景真正的URP Main Light
Light ApplyCharacterIndoorMainLight(Light outdoorMainLight)
{
    float weight=saturate(_IndoorLightingWeight);
    float3 indoorDirection=SafeNormalize(_IndoorMainLightDirection.xyz);

    outdoorMainLight.direction=SafeNormalize(lerp(outdoorMainLight.direction,indoorDirection,weight));
    outdoorMainLight.color=lerp(outdoorMainLight.color,_IndoorMainLightColor.rgb,weight);
    outdoorMainLight.distanceAttenuation=lerp(outdoorMainLight.distanceAttenuation,1.0,weight);
    outdoorMainLight.shadowAttenuation=lerp(outdoorMainLight.shadowAttenuation,1.0,weight);

    return outdoorMainLight;
}

#endif
