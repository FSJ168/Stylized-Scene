using UnityEngine;

/// <summary>
/// 控制天空云层的整体缓慢运动。
///
/// 这个脚本只负责 CloudVisual 的旋转。
/// </summary>
[ExecuteAlways]
public class CloudMotion : MonoBehaviour
{
    [Header("云层整体旋转")]

    [Tooltip("是否开启云层旋转")]
    public bool enableRotation = true;

    [Tooltip("云层每秒旋转多少度。建议非常慢，例如 0.1 ~ 1")]
    public float rotationSpeed = 0.25f;

    [Tooltip("旋转方向。1 = 顺方向，-1 = 反方向")]
    public float rotationDirection = 1.0f;


    private void Update()
    {
        if (!enableRotation)
            return;

        // 每帧应该旋转的角度
        // 使用Time.deltaTime让旋转速度不受帧率影响
        float rotationAmount =
            rotationSpeed *
            rotationDirection *
            Time.deltaTime;

        // 只绕世界 Y 轴旋转
        // 不改变 X、Z，所以云不会发生倾斜
        transform.Rotate(
            Vector3.up,
            rotationAmount,
            Space.World
        );
    }
}