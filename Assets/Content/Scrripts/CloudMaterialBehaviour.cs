using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Playables;

/// <summary>
/// 真正负责在 Timeline 播放过程中修改云 Material。
/// 和 MySkyboxBehaviour 的区别：
/// MySkyboxBehaviour：
///     会把材质设置成 RenderSettings.skybox
/// CloudMaterialBehaviour：
///     只修改绑定进来的 Material
/// </summary>
public class CloudMaterialBehaviour : PlayableBehaviour
{
    public List<MaterialProperty> properties;

    public override void ProcessFrame(Playable playable,FrameData info,object playerData)
    {
        //Track 上绑定的对象就是 Material
        Material material =playerData as Material;
        if (material == null)
            return;
        if (properties == null)
            return;

        //获取当前 Clip 内的归一化时间
        //Clip开头：0
        //Clip末尾：1

        double duration =
            playable.GetDuration();

        float normalizedTime = 0f;

        if (duration > 0.0001)
        {
            normalizedTime =Mathf.Clamp01((float)(playable.GetTime()/duration));
        }


        // 遍历所有需要控制的 Shader 属性
        foreach (MaterialProperty property in properties)
        {
            if (property == null)
                continue;

            // Shader 属性名为空则跳过
            if (string.IsNullOrEmpty(property.propertyName))
                continue;

            // Float 类型
            if (property.type==MaterialProperty.PropertyType.Float)
            {
                if (property.curve == null)
                    continue;

                float value =property.curve.Evaluate(normalizedTime);
                material.SetFloat(property.propertyName,value);
            }

            // Color 类型
            else if (property.type==MaterialProperty.PropertyType.Color)
            {
                if (property.gradient == null)
                    continue;

                Color color =property.gradient.Evaluate(normalizedTime);

                material.SetColor(property.propertyName,color);
            }
        }
    }
}