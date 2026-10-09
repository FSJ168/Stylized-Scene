using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Playables;

/// <summary>
/// 云材质 Timeline Clip 的数据。
///
/// 每一个 CloudMaterialAsset 就对应 Timeline 上的一段 Clip。
/// Clip 内可以添加多个 MaterialProperty：
///
/// Float：控制浮点属性，例如 _SunMoon
/// Color：控制颜色属性，例如 _CloudColorA
///
/// MaterialProperty.cs 直接复用你之前天空 Timeline 的版本。
/// </summary>
public class CloudMaterialAsset : PlayableAsset
{
    // 需要随 Timeline 改变的 Shader 参数
    public List<MaterialProperty> properties = new List<MaterialProperty>();


    public override Playable CreatePlayable(PlayableGraph graph,GameObject owner)
    {
        // 创建Behaviour
        ScriptPlayable<CloudMaterialBehaviour> playable =
            ScriptPlayable<CloudMaterialBehaviour>.Create(graph);

        CloudMaterialBehaviour behaviour =
            playable.GetBehaviour();

        // 把 Inspector 中设置好的属性列表传给 Behaviour
        behaviour.properties = properties;

        return playable;
    }
}