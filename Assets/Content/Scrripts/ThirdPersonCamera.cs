using UnityEngine;

namespace Suntail
{
    public class ThirdPersonCamera : MonoBehaviour
    {
        [Header("Target")]
        [SerializeField] private Transform target;

        [Header("Camera")]
        [SerializeField] private Camera cameraComponent;
        [SerializeField] private float defaultDistance = 4f;
        [SerializeField] private float minDistance = 2f;
        [SerializeField] private float maxDistance = 7f;
        [SerializeField] private float mouseSensitivity = 2f;
        [SerializeField] private float minPitch = -20f;
        [SerializeField] private float maxPitch = 65f;

        [Header("Rotation Smooth")]
        [SerializeField] private float rotationSmoothSpeed = 15f;

        [Header("Zoom")]
        [SerializeField] private float zoomSpeed = 2f;
        [SerializeField] private float zoomSmoothTime = 0.08f;

        [Header("Adaptive FOV")]
        [SerializeField] private float idleFOV = 55f;
        [SerializeField] private float walkFOV = 60f;
        [SerializeField] private float runFOV = 65f;
        [SerializeField] private float walkSpeed = 4f;
        [SerializeField] private float runSpeed = 6f;
        [SerializeField] private float fovSmoothSpeed = 5f;

        private UnityEngine.CharacterController _characterController;

        private float _yaw;
        private float _pitch = 15f;
        private float _targetYaw;
        private float _targetPitch = 15f;

        private float _targetDistance;
        private float _currentDistance;
        private float _zoomVelocity;

        private void Awake()
        {
            if(cameraComponent == null)
                cameraComponent = GetComponent<Camera>();

            if(target != null)
                _characterController = target.GetComponentInParent<UnityEngine.CharacterController>();
        }

        private void Start()
        {
            _yaw = target.eulerAngles.y;
            _targetYaw = _yaw;
            _pitch = 15f;
            _targetPitch = _pitch;

            _targetDistance = defaultDistance;
            _currentDistance = defaultDistance;

            if(cameraComponent != null)
                cameraComponent.fieldOfView = idleFOV;

            Cursor.lockState = CursorLockMode.Locked;
            Cursor.visible = false;
        }

        private void LateUpdate()
        {
            HandleRotation();
            HandleZoom();
            HandleAdaptiveFOV();
            FollowTarget();
        }

        private void HandleRotation()
        {
            float mouseX = Input.GetAxis("Mouse X");
            float mouseY = Input.GetAxis("Mouse Y");

            //鼠标修改目标角度
            _targetYaw += mouseX * mouseSensitivity;
            _targetPitch -= mouseY * mouseSensitivity;
            _targetPitch = Mathf.Clamp(_targetPitch, minPitch, maxPitch);

            //平滑追踪目标角度
            float rotationT = 1f - Mathf.Exp(-rotationSmoothSpeed * Time.deltaTime);
            _yaw = Mathf.LerpAngle(_yaw, _targetYaw, rotationT);
            _pitch = Mathf.Lerp(_pitch, _targetPitch, rotationT);
        }

        private void HandleZoom()
        {
            float scroll = Input.GetAxis("Mouse ScrollWheel");

            //滚轮控制相机距离
            _targetDistance -= scroll * zoomSpeed;
            _targetDistance = Mathf.Clamp(_targetDistance, minDistance, maxDistance);
            _currentDistance = Mathf.SmoothDamp(_currentDistance, _targetDistance, ref _zoomVelocity, zoomSmoothTime);
        }

        private void HandleAdaptiveFOV()
        {
            if(cameraComponent == null || _characterController == null)
                return;

            Vector3 horizontalVelocity = _characterController.velocity;
            horizontalVelocity.y = 0f;
            float speed = horizontalVelocity.magnitude;

            float targetFOV;

            //根据角色实际水平速度计算FOV
            if(speed <= walkSpeed)
            {
                float t = Mathf.InverseLerp(0f, walkSpeed, speed);
                targetFOV = Mathf.Lerp(idleFOV, walkFOV, t);
            }
            else
            {
                float t = Mathf.InverseLerp(walkSpeed, runSpeed, speed);
                targetFOV = Mathf.Lerp(walkFOV, runFOV, t);
            }

            float fovT = 1f - Mathf.Exp(-fovSmoothSpeed * Time.deltaTime);
            cameraComponent.fieldOfView = Mathf.Lerp(cameraComponent.fieldOfView, targetFOV, fovT);
        }

        private void FollowTarget()
        {
            Quaternion orbitRotation = Quaternion.Euler(_pitch, _yaw, 0f);

            //严格保持相机和CameraTarget的相对位置
            transform.position = target.position - orbitRotation * Vector3.forward * _currentDistance;

            //始终精确看向CameraTarget
            Vector3 lookDirection = target.position - transform.position;

            if(lookDirection.sqrMagnitude <= 0.001f)
                return;

            transform.rotation = Quaternion.LookRotation(lookDirection.normalized, Vector3.up);
        }
    }
}