using System.Collections;
using UnityEngine;

namespace Suntail
{
    [RequireComponent(typeof(Animator))]
    public class Door : MonoBehaviour
    {
        [Header("Door")]
        [Tooltip("开关门后暂时禁止再次交互的时间")]
        [SerializeField] private float interactionLockTime = 1f;

        [HideInInspector] public bool doorOpen = false;

        private Animator _doorAnimator;
        private bool _pauseInteraction;

        private void Awake()
        {
            _doorAnimator = GetComponent<Animator>();
        }

        public void PlayDoorAnimation()
        {
            if (_pauseInteraction)
            {
                return;
            }

            if (!doorOpen)
            {
                _doorAnimator.Play("OpenDoor");
                doorOpen = true;
            }
            else
            {
                _doorAnimator.Play("CloseDoor");
                doorOpen = false;
            }

            StartCoroutine(PauseInteraction());
        }

        private IEnumerator PauseInteraction()
        {
            _pauseInteraction = true;
            yield return new WaitForSeconds(interactionLockTime);
            _pauseInteraction = false;
        }
    }
}