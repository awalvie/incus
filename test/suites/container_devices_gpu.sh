test_container_devices_gpu() {
  ensure_import_testimage
  ensure_has_localhost_remote "${INCUS_ADDR}"

  if [ ! -c /dev/dri/card0 ]; then
    echo "==> SKIP: No /dev/dri/card0 device found"
    return
  fi

  ctName="ct$$"
  inc launch testimage "${ctName}"

  # Check adding all cards creates the correct device mounts and cleans up on removal.
  startMountCount=$(inc exec "${ctName}" -- mount | wc -l)
  startDevCount=$(find "${INCUS_DIR}"/devices/"${ctName}" -type c | wc -l)
  inc config device add "${ctName}" gpu-basic gpu mode=0600 id=0
  inc exec "${ctName}" -- mount | grep "/dev/dri/card0"
  inc exec "${ctName}" -- stat -c '%a' /dev/dri/card0 | grep 600
  stat -c '%a' "${INCUS_DIR}"/devices/"${ctName}"/unix.gpu--basic.dev-dri-card0 | grep 600
  inc config device remove "${ctName}" gpu-basic
  endMountCount=$(inc exec "${ctName}" -- mount | wc -l)
  endDevCount=$(find "${INCUS_DIR}"/devices/"${ctName}" -type c | wc -l)

  if [ "$startMountCount" != "$endMountCount" ]; then
    echo "leftover container mounts detected"
    false
  fi

  if [ "$startDevCount" != "$endDevCount" ]; then
    echo "leftover host devices detected"
    false
  fi

  # Check adding non-existent card fails.
  ! inc config device add "${ctName}" gpu-missing gpu id=9999

  # Check default create mode is 0660.
  inc config device add "${ctName}" gpu-default gpu
  inc exec "${ctName}" -- stat -c '%a' /dev/dri/card0 | grep 660
  inc config device remove "${ctName}" gpu-default

  # Check if nvidia GPU exists.
  if [ ! -c /dev/nvidia0  ]; then
    echo "==> SKIP: /dev/nvidia0 does not exist, skipping nvidia tests"
    inc delete -f "${ctName}"
    return
  fi

  # Check /usr/bin/nvidia-container-cli exists (requires libnvidia-container-tools be installed).
  if [ ! -f /usr/bin/nvidia-container-cli ]; then
    echo "==> SKIP: /usr/bin/nvidia-container-cli not available (please install libnvidia-container-tools)"
    inc delete -f "${ctName}"
    return
  fi

  # Check the Nvidia specific devices are mounted correctly.
  inc config device add "${ctName}" gpu-nvidia gpu mode=0600

  inc exec "${ctName}" -- mount | grep /dev/nvidia0
  stat -c '%a' "${INCUS_DIR}"/devices/"${ctName}"/unix.gpu--nvidia.dev-dri-card0 | grep 600

  inc exec "${ctName}" -- mount | grep /dev/nvidia-modeset
  stat -c '%a' "${INCUS_DIR}"/devices/"${ctName}"/unix.gpu--nvidia.dev-nvidia--modeset | grep 600

  inc exec "${ctName}" -- mount | grep /dev/nvidia-uvm
  stat -c '%a' "${INCUS_DIR}"/devices/"${ctName}"/unix.gpu--nvidia.dev-nvidia--uvm | grep 600

  inc exec "${ctName}" -- mount | grep /dev/nvidia-uvm-tools
  stat -c '%a' "${INCUS_DIR}"/devices/"${ctName}"/unix.gpu--nvidia.dev-nvidia--uvm--tools | grep 600

  inc exec "${ctName}" -- mount | grep /dev/nvidiactl
  stat -c '%a' "${INCUS_DIR}"/devices/"${ctName}"/unix.gpu--nvidia.dev-nvidiactl | grep 600

  inc config device remove "${ctName}" gpu-nvidia

  # Check support for nvidia runtime
  inc stop -f "${ctName}"
  inc config set "${ctName}" nvidia.runtime true
  inc start "${ctName}"
  nvidiaMountCount=$(inc exec "${ctName}" -- mount | grep -c nvidia)
  if [ "$nvidiaMountCount" != "16" ]; then
    echo "nvidia runtime mounts invalid"
    false
  fi

  inc delete -f "${ctName}"
}
