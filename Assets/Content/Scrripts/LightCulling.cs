using UnityEngine;

/*
 * 根据玩家相机与灯光之间的距离，
 * 自动关闭远处阴影和灯光。
 */
namespace Suntail
{
    [RequireComponent(typeof(Light))]
    public class LightCulling : MonoBehaviour
    {
        [Header("距离设置")]

        [Tooltip("超过这个距离后关闭阴影")]
        [SerializeField]
        private float shadowCullingDistance = 15f;

        [Tooltip("超过这个距离后关闭整个灯光")]
        [SerializeField]
        private float lightCullingDistance = 30f;


        [Header("阴影设置")]

        [Tooltip("是否允许这盏灯开启阴影")]
        [SerializeField]
        private bool enableShadows = false;


        private Light _light;

        // 缓存相机 Transform
        private Transform _cameraTransform;

        // 保存灯光原本使用的阴影类型
        private LightShadows _originalShadowMode;


        private void Awake()
        {
            // 获取当前物体上的 Light
            _light = GetComponent<Light>();

            // 保存原来的阴影类型
            _originalShadowMode = _light.shadows;

            // 自动寻找 Main Camera
            if (Camera.main != null)
            {
                _cameraTransform = Camera.main.transform;
            }
        }


        private void Update()
        {
            // 防止场景中没有 Main Camera 时报错
            if (_cameraTransform == null)
            {
                return;
            }

            // 计算相机与灯光之间的平方距离
            // 不使用 Vector3.Distance，
            // 可以避免每帧进行一次开平方计算。

            float sqrDistance =
                (_cameraTransform.position - transform.position).sqrMagnitude;


            float shadowDistanceSqr =
                shadowCullingDistance * shadowCullingDistance;

            float lightDistanceSqr =
                lightCullingDistance * lightCullingDistance;


            bool shouldEnableShadow =
                enableShadows &&
                sqrDistance <= shadowDistanceSqr;

            if (shouldEnableShadow)
            {
                // 恢复灯光原来的阴影模式
                if (_light.shadows != _originalShadowMode)
                {
                    _light.shadows = _originalShadowMode;
                }
            }
            else
            {
                if (_light.shadows != LightShadows.None)
                {
                    _light.shadows = LightShadows.None;
                }
            }



            bool shouldEnableLight =
                sqrDistance <= lightDistanceSqr;

            if (_light.enabled != shouldEnableLight)
            {
                _light.enabled = shouldEnableLight;
            }
        }

        private void OnValidate()
        {
            shadowCullingDistance =
                Mathf.Max(0f, shadowCullingDistance);

            lightCullingDistance =
                Mathf.Max(shadowCullingDistance, lightCullingDistance);
        }
    }
}