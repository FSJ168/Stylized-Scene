using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Playables;

//Timeline Clip的资源模板
public class MySkyBoxAssets : PlayableAsset
{
   public List<MaterialProperty>properties;
   public override Playable CreatePlayable(PlayableGraph graph,GameObject owner)
    {
        var playable=ScriptPlayable<MySkyBoxBehaviour>.Create(graph);
        var behaviour=playable.GetBehaviour();

        behaviour.properties=properties;
        return playable;
    }
}
