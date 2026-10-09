using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Playables;

//PlayableBehaviour：TimeLine自定义片段的基类
public class MySkyBoxBehaviour : PlayableBehaviour
{
    public List<MaterialProperty> properties;

    //Timeline → CustomClip → MySkyboxBehaviour，播放时自动调用 ProcessFrame
    //Playable playable：当前这个片段的 Playable 实例，可以拿到当前时间、总时长
    //object playerData：从 Timeline 轨道绑定传递过来的数据，这里我们绑定的是 Material 对象
    public override void ProcessFrame(Playable playable,FrameData info,object playerData)
    {
        Material material=playerData as Material;
        if(material==null)return;
        RenderSettings.skybox=material;
        float t=(float)(playable.GetTime()/playable.GetDuration()); //已播放时长/总时长
        foreach(var property in properties)
        {
            if (property.type == MaterialProperty.PropertyType.Float)
            {
                float value=property.curve.Evaluate(t);
                material.SetFloat(property.propertyName,value);
            }
            else if (property.type == MaterialProperty.PropertyType.Color)
            {
                Color color=property.gradient.Evaluate(t);
                material.SetColor(property.propertyName,color);
            }
        }
    }
}
