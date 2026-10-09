using UnityEngine;

/// <summary>
/// 让整个天空云层跟随相机移动。
///
/// 核心目的：
/// 玩家无论在大世界里移动多远，
/// 都始终位于 CloudDome 的中心附近。
///
/// 注意：
/// 只改变位置，不改变旋转，
/// 所以玩家转动相机时天空云不会跟着一起转。
/// </summary>
public class CloudDomeFollow : MonoBehaviour
{
    [Header("跟随目标")]
    [Tooltip("通常拖入Main Camera")]
    public Transform target;

    [Header("跟随设置")]

    [Tooltip("是否跟随目标的 X 轴")]
    public bool followX = true;

    [Tooltip("是否跟随目标的 Y 轴")]
    public bool followY = false;

    [Tooltip("是否跟随目标的 Z 轴")]
    public bool followZ = true;

    // 天空云开始时的位置。
    // 当某个轴不需要跟随时，就保持这个初始值。
    private Vector3 startPosition;

    private void Start()
    {
        // 记录天空云最开始的位置
        startPosition = transform.position;
    }


    private void LateUpdate()
    {
        if (target == null)
            return;

        // 获取 CloudDome 当前应该处于的位置
        Vector3 newPosition = transform.position;


        // X 轴
        if (followX)
        {
            newPosition.x = target.position.x;
        }
        else
        {
            newPosition.x = startPosition.x;
        }


        // Y 轴
        if (followY)
        {
            newPosition.y = target.position.y;
        }
        else
        {
            newPosition.y = startPosition.y;
        }


        // Z 轴
        if (followZ)
        {
            newPosition.z = target.position.z;
        }
        else
        {
            newPosition.z = startPosition.z;
        }


        // 最后修改 CloudDome 世界坐标
        transform.position = newPosition;
    }
}