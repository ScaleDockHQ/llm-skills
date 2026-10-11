# Combo: KEDA and Ray Serve

> Verified against KEDA v2.21.0, 2026-10-11

Ray Serve replicas are Ray actors scaled by Serve's `autoscaling_config`, and KubeRay scales worker pods for them. A
KEDA ScaledObject on the same worker group would be a second controller changing the same count.

- Keep Serve autoscaling as the single source for replicas. Tune it in skill `ray-serve`
  (`target_ongoing_requests`, `downscale_delay_s`).
- KEDA fits **around** Ray, not inside it: scale a queue-consumer Deployment that calls the Ray endpoint, or plain vLLM
  Deployments that sit beside Ray.
- If you need Prometheus-driven decisions for a RayService, use KubeRay and Serve settings; do not point
  `scaleTargetRef` at a RayCluster worker group managed by the Ray autoscaler.
