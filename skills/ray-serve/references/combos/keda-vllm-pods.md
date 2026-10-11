# Combo: KEDA and Ray Serve

> Verified against Ray 2.59.0 and KEDA v2.21.0 (docs `scalers/prometheus`, Serve autoscaling), 2026-10-11

Do not put KEDA on the Ray worker pods of a RayService that already autoscales Serve replicas. Two controllers
resizing the same worker group fight each other; KubeRay's own cluster autoscaler already adds GPU nodes in
response to pending replicas.

Use KEDA when you run plain vLLM Deployments (not Ray Serve): see skill `keda`. If you want Prometheus-driven
decisions with Ray, keep Serve's `autoscaling_config` as the single source and tune it
(`references/scaling-and-tuning.md`); expose `ray_serve_autoscaling_desired_replicas` on a dashboard to see its decisions.
