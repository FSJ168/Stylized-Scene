using UnityEngine;
using UnityEngine.Timeline;

/// <summary>
/// Timeline 中专门控制云 Material 的 Track。
/// </summary>

// Timeline 中这条轨道允许放 CloudMaterialAsset
[TrackClipType(typeof(CloudMaterialAsset))]

// 这条 Track 可以绑定 Material
[TrackBindingType(typeof(Material))]

// Timeline 轨道左侧显示的颜色
[TrackColor(0.55f, 0.75f, 1.0f)]

public class CloudMaterialTrack : TrackAsset
{
    
}