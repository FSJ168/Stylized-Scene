using UnityEngine;

[ExecuteAlways]
public class DirectionToSkyBox : MonoBehaviour
{
    public GameObject sun;
    public GameObject moon;
    public Material targetMaterial; //修改的SkyBox材质
    public Material targetMaterialCloudTA;
    public Material targetMaterialCloudTB;
    public string sunDirectionPropertyName="_SunDirection";
    public string moonDirectionPropertyName="_MoonDirection";
    void Start()
    {
        if(targetMaterial == null)
        {
            Debug.LogError("请添加targetMaterial");
            return;
        }
        if(targetMaterialCloudTA == null)
        {
            Debug.LogError("请添加targetMaterialCloudTA");
            return;
        }
        if(targetMaterialCloudTB == null)
        {
            Debug.LogError("请添加targetMaterialCloudTB");
            return;
        }
        if(sun == null)
        {
            Debug.LogError("请添加物体sun");
            return;
        }
        if(moon == null)
        {
            Debug.LogError("请添加物体moon");
            return;
        }
    }

    // Update is called once per frame
    void Update()
    {
        Matrix4x4 LToW=moon.transform.localToWorldMatrix;
        targetMaterial.SetMatrix("LToW",LToW);

        if (sun)
        {
            Vector3 sunDirection=-sun.transform.forward.normalized;
            targetMaterial.SetVector(sunDirectionPropertyName,sunDirection);
            targetMaterialCloudTA.SetVector(sunDirectionPropertyName,sunDirection);
            targetMaterialCloudTB.SetVector(sunDirectionPropertyName,sunDirection);

        }
        if (moon)
        {
            Vector3 moonDirection=-moon.transform.forward.normalized;
            targetMaterial.SetVector(moonDirectionPropertyName,moonDirection);
            targetMaterialCloudTA.SetVector(moonDirectionPropertyName,moonDirection);
            targetMaterialCloudTB.SetVector(moonDirectionPropertyName,moonDirection);
            
        }
    }
}
