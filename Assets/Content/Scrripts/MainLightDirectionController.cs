using UnityEngine;

/// <summary>
/// 控制场景唯一的 Main Directional Light。
/// 白天：方向跟随 SunDir
/// 夜晚：方向跟随 MoonDir
/// </summary>
[ExecuteAlways]
public class MainLightDirectionController : MonoBehaviour
{
    [Header("方向来源")]

    [Tooltip("太阳方向物体SunDir")]
    public Transform sunDir;

    [Tooltip("月亮方向物体MoonDir")]
    public Transform moonDir;

    [Header("昼夜切换")]

    [Tooltip(
        "0 = 使用太阳方向\n" +
        "1 = 使用月亮方向\n" +
        "这个参数以后由 Timeline 控制"
    )]
    [Range(0f, 1f)]
    public float moonBlend = 0f;

    [Tooltip("moonBlend 超过这个值时切换到月亮方向")]
    [Range(0f, 1f)]
    public float switchPoint = 0.5f;

    private void LateUpdate()
    {
        ApplyLightDirection();
    }


    private void OnValidate()
    {
        ApplyLightDirection();
    }


    /// <summary>
    /// 根据 moonBlend 选择太阳或者月亮方向。
    /// </summary>
    private void ApplyLightDirection()
    {
        if (sunDir == null)
            return;

        if (moonDir == null)
            return;


        // -------------------------------------------------
        // moonBlend < 0.5
        // 使用太阳方向
        // moonBlend >= 0.5
        // 使用月亮方向

        Transform targetDirection =moonBlend < switchPoint? sunDir: moonDir;

        Shader.SetGlobalFloat("_EnvironmentNeightWeight",moonBlend);

        // MainLight 和方向物体保持完全相同的旋转。
        transform.rotation =targetDirection.rotation;
    }
}