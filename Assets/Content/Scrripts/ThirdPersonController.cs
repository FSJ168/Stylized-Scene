using UnityEngine;

namespace Suntail
{
    [RequireComponent(typeof(UnityEngine.CharacterController))]
    public class ThirdPersonController : MonoBehaviour
    {
        [Header("Movement")]
        [SerializeField] private float walkSpeed = 4f;
        [SerializeField] private float runMultiplier = 1.5f;
        [SerializeField] private float jumpForce = 1.5f;
        [SerializeField] private float gravity = -9.81f;
        [SerializeField] private float rotationSmoothTime = 0.12f;

        [Header("Camera")]
        [SerializeField] private Transform playerCamera;

        [Header("Animation")]
        [SerializeField] private Animator animator;
        [SerializeField] private float animationSmoothTime = 0.15f;

        [Header("Keybinds")]
        [SerializeField] private KeyCode jumpKey = KeyCode.Space;
        [SerializeField] private KeyCode runKey = KeyCode.LeftShift;

        private UnityEngine.CharacterController _characterController;
        private Vector3 _velocity;
        private float _rotationVelocity;

        private static readonly int SpeedHash = Animator.StringToHash("Speed");

        private void Awake()
        {
            _characterController = GetComponent<UnityEngine.CharacterController>();

            if(animator == null)
                animator = GetComponentInChildren<Animator>();
        }

        private void Update()
        {
            Move();
            ApplyGravity();
        }

        private void Move()
        {
            float horizontal = Input.GetAxisRaw("Horizontal");
            float vertical = Input.GetAxisRaw("Vertical");

            Vector2 input = new Vector2(horizontal, vertical);
            input = Vector2.ClampMagnitude(input, 1f);

            //获取相机水平方向
            Vector3 cameraForward = playerCamera.forward;
            Vector3 cameraRight = playerCamera.right;
            cameraForward.y = 0f;
            cameraRight.y = 0f;
            cameraForward.Normalize();
            cameraRight.Normalize();

            //根据相机朝向计算移动方向
            Vector3 moveDirection = cameraForward * input.y + cameraRight * input.x;
            moveDirection.Normalize();

            //更新动画
            float animationSpeed = input.magnitude;
            animator.SetFloat(SpeedHash, animationSpeed, animationSmoothTime, Time.deltaTime);

            if(moveDirection.sqrMagnitude <= 0.01f)
                return;

            //角色平滑朝向移动方向
            float targetAngle = Mathf.Atan2(moveDirection.x, moveDirection.z) * Mathf.Rad2Deg;
            float smoothAngle = Mathf.SmoothDampAngle(transform.eulerAngles.y, targetAngle, ref _rotationVelocity, rotationSmoothTime);
            transform.rotation = Quaternion.Euler(0f, smoothAngle, 0f);

            //角色移动
            float currentSpeed = Input.GetKey(runKey) ? walkSpeed * runMultiplier : walkSpeed;
            _characterController.Move(moveDirection * currentSpeed * Time.deltaTime);
        }

        private void ApplyGravity()
        {
            if(_characterController.isGrounded && _velocity.y < 0f)
                _velocity.y = -2f;

            if(Input.GetKeyDown(jumpKey) && _characterController.isGrounded)
                _velocity.y = Mathf.Sqrt(jumpForce * -2f * gravity);

            _velocity.y += gravity * Time.deltaTime;
            _characterController.Move(_velocity * Time.deltaTime);
        }
    }
}