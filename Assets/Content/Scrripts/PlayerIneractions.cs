using UnityEngine;
using UnityEngine.UI;

namespace Suntail
{
    public class PlayerInteractions : MonoBehaviour
    {
        [Header("Interaction")]
        [Tooltip("可以交互的Layer")]
        [SerializeField] private LayerMask interactionLayer;
        [Tooltip("角色与门之间允许交互的最大距离")]
        [SerializeField] private float interactionDistance = 3f;
        [Tooltip("摄像机检测最大距离")]
        [SerializeField] private float rayDistance = 100f;
        [Tooltip("门物体Tag")]
        [SerializeField] private string doorTag = "Door";
        [Tooltip("第三人称主摄像机")]
        [SerializeField] private Camera mainCamera;

        [Header("Keybinds")]
        [SerializeField] private KeyCode interactionKey = KeyCode.E;

        [Header("UI")]
        [SerializeField] private Image uiPanel;
        [SerializeField] private Text panelText;
        [SerializeField] private string doorOpenText = "按 E 开门";
        [SerializeField] private string doorCloseText = "按 E 关门";

        private Door _lookDoor;

        private void Start()
        {
            if (mainCamera == null)
            {
                mainCamera = Camera.main;
            }

            HideDoorUI();
        }

        private void Update()
        {
            CheckDoorInteraction();
        }

        private void CheckDoorInteraction()
        {
            _lookDoor = null;

            Ray ray = mainCamera.ViewportPointToRay(new Vector3(0.5f, 0.5f, 0f));

            if (Physics.Raycast(ray, out RaycastHit hit, rayDistance, interactionLayer))
            {
                if (hit.collider.CompareTag(doorTag))
                {
                    Door door = hit.collider.GetComponentInParent<Door>();

                    if (door != null && Vector3.Distance(transform.position, hit.point) <= interactionDistance)
                    {
                        _lookDoor = door;
                    }
                }
            }

            if (_lookDoor == null)
            {
                HideDoorUI();
                return;
            }

            ShowDoorUI();

            if (Input.GetKeyDown(interactionKey))
            {
                _lookDoor.PlayDoorAnimation();
            }
        }

        private void ShowDoorUI()
        {
            if (uiPanel != null)
            {
                uiPanel.gameObject.SetActive(true);
            }

            if (panelText != null)
            {
                panelText.text = _lookDoor.doorOpen ? doorCloseText : doorOpenText;
            }
        }

        private void HideDoorUI()
        {
            if (uiPanel != null)
            {
                uiPanel.gameObject.SetActive(false);
            }
        }
    }
}