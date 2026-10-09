using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Collider))]
public class IndoorLightingZone : MonoBehaviour
{
    [Header("室内主方向光")]
    [SerializeField] private Light indoorKeyLight;

    [Header("室内外过渡")]
    [Min(0.01f)]
    [SerializeField] private float blendDuration = 0.6f;
    
    //进入室内的Collider的数量，当Count0->1时触发一次，Count=0时出发Exit
    private readonly Dictionary<CharacterIndoorLighting, int> overlapCounts = new Dictionary<CharacterIndoorLighting, int>();

    //只读属性
    public Light IndoorKeyLight => indoorKeyLight;
    public float BlendDuration => blendDuration;

    private void Reset()
    {
        //只在挂载脚本时调用
        Collider zoneCollider = GetComponent<Collider>();
        zoneCollider.isTrigger = true;
    }

    private void OnValidate()
    {
        Collider zoneCollider = GetComponent<Collider>();
        if (zoneCollider != null) zoneCollider.isTrigger = true;
    }

    private void OnTriggerEnter(Collider other)
    {
        CharacterIndoorLighting controller = other.GetComponentInParent<CharacterIndoorLighting>();
        if (controller == null) return;

        overlapCounts.TryGetValue(controller, out int count);
        count++;
        overlapCounts[controller] = count;

        //角色第一次进入该区域时开始切换
        if (count == 1) controller.EnterZone(this);
    }

    private void OnTriggerExit(Collider other)
    {
        CharacterIndoorLighting controller = other.GetComponentInParent<CharacterIndoorLighting>();
        if (controller == null) return;
        if (!overlapCounts.TryGetValue(controller, out int count)) return;

        count--;
        if (count > 0)
        {
            overlapCounts[controller] = count;
            return;
        }

        overlapCounts.Remove(controller);
        controller.ExitZone(this);
    }
}
