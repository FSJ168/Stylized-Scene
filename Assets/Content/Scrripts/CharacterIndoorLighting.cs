using UnityEngine;
using UnityEngine.Rendering;

public class CharacterIndoorLighting : MonoBehaviour
{
    [Header("角色渲染器")]
    //需要做内外光照混合的Renderer
    [SerializeField] private Renderer[] characterRenderers;
    //LightProbe的采样参考Probe
    [SerializeField] private Renderer probeReferenceRenderer;

    [Header("SH采样位置")]
    [SerializeField] private Transform shSamplePoint;

    [Header("默认过渡")]
    [Min(0.01f)]
    [SerializeField] private float defaultBlendDuration = 0.6f;

    //混合权重
    private static readonly int IndoorWeightId = Shader.PropertyToID("_IndoorLightingWeight");
    //室内主光方向
    private static readonly int IndoorLightDirectionId = Shader.PropertyToID("_IndoorMainLightDirection");
    //室内主光颜色
    private static readonly int IndoorLightColorId = Shader.PropertyToID("_IndoorMainLightColor");

    private readonly SphericalHarmonicsL2[] shBuffer = new SphericalHarmonicsL2[1];//L2阶球谐，储存环境漫反射
    private MaterialPropertyBlock propertyBlock; //MaterialPropertyBlock：材质属性快，给Renderer单独覆写Shader参数，不产生材质实例克隆

    private IndoorLightingZone currentZone; //当前光照区域
    private float indoorWeight; //实时混合权重
    private float targetWeight; //目标权重
    private float currentBlendDuration; //过渡时长
    private bool clearZoneAfterBlend;

    public float IndoorWeight => indoorWeight;
    public IndoorLightingZone CurrentZone => currentZone;

    private void Awake()
    {
        if (characterRenderers == null || characterRenderers.Length == 0) characterRenderers = GetComponentsInChildren<Renderer>(true);
        if (probeReferenceRenderer == null && characterRenderers.Length > 0) probeReferenceRenderer = characterRenderers[0];
        if (shSamplePoint == null) shSamplePoint = transform;

        propertyBlock = new MaterialPropertyBlock();
        currentBlendDuration = defaultBlendDuration;

        //始终由脚本提供最终SH，避免室内外切换时LightProbeUsage突变
        for (int i = 0; i < characterRenderers.Length; i++)
        {
            Renderer targetRenderer = characterRenderers[i];
            if (targetRenderer == null) continue;
            //不自动采样LightProbe，SH球谐由代码手动提交
            targetRenderer.lightProbeUsage = LightProbeUsage.CustomProvided;
        }
    }

    private void LateUpdate()
    {
        UpdateBlendWeight();
        UpdateCharacterLighting();
    }

    public void EnterZone(IndoorLightingZone zone)
    {
        if (zone == null) return;

        currentZone = zone;
        targetWeight = 1.0f;
        currentBlendDuration = Mathf.Max(0.01f, zone.BlendDuration);
        clearZoneAfterBlend = false;
    }

    public void ExitZone(IndoorLightingZone zone)
    {
        if (zone == null || currentZone != zone) return;

        targetWeight = 0.0f;
        currentBlendDuration = Mathf.Max(0.01f, zone.BlendDuration);
        clearZoneAfterBlend = true;
    }

    private void UpdateBlendWeight()
    {
        //混合过渡速度
        float speed = 1.0f / Mathf.Max(0.01f, currentBlendDuration);
        indoorWeight = Mathf.MoveTowards(indoorWeight, targetWeight, speed * Time.deltaTime);

        if (clearZoneAfterBlend && indoorWeight <= 0.0001f)
        {
            currentZone = null;
            clearZoneAfterBlend = false;
        }
    }

    private void UpdateCharacterLighting()
    {
        //室外取ambient Probe
        SphericalHarmonicsL2 outdoorSH = RenderSettings.ambientProbe;
        SphericalHarmonicsL2 indoorSH = outdoorSH;

        //室内SH来自角色当前位置的Light Probe插值
        if (currentZone != null) LightProbes.GetInterpolatedProbe(shSamplePoint.position, probeReferenceRenderer, out indoorSH);
        
        //室内SH来自角色当前shSamplePoint位置的Light Probe插值
        SphericalHarmonicsL2 finalSH = outdoorSH * (1.0f - indoorWeight) + indoorSH * indoorWeight;
        shBuffer[0] = finalSH;

        Vector3 indoorDirection = Vector3.up;
        Color indoorColor = Color.black;
        GetIndoorMainLightData(ref indoorDirection, ref indoorColor);

        for (int i = 0; i < characterRenderers.Length; i++)
        {
            Renderer targetRenderer = characterRenderers[i];
            if (targetRenderer == null) continue;

            targetRenderer.GetPropertyBlock(propertyBlock);
            // 将混合好的SH写入MPB，提交给Renderer
            propertyBlock.CopySHCoefficientArraysFrom(shBuffer);
            // 设置三个Shader参数
            propertyBlock.SetFloat(IndoorWeightId, indoorWeight);
            propertyBlock.SetVector(IndoorLightDirectionId, new Vector4(indoorDirection.x, indoorDirection.y, indoorDirection.z, 0.0f));
            propertyBlock.SetVector(IndoorLightColorId, new Vector4(indoorColor.r, indoorColor.g, indoorColor.b, 1.0f));
            //将MBP回写到Renderer
            targetRenderer.SetPropertyBlock(propertyBlock);
        }
    }

    private void GetIndoorMainLightData(ref Vector3 direction, ref Color color)
    {
        if (currentZone == null) return;

        Light indoorLight = currentZone.IndoorKeyLight;
        if (indoorLight == null) return;

        //Directional Light的照射方向是Transform.forward，Shader需要指向光源的方向
        direction = -indoorLight.transform.forward;

        Color sourceColor = indoorLight.color;
        if (QualitySettings.activeColorSpace == ColorSpace.Linear) sourceColor = sourceColor.linear;
        color = sourceColor * indoorLight.intensity;
    }
}
