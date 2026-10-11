# Teardown

> Verified against AWS CLI v2 EC2 reference (describe-instance-types, terminate-instances, cancel-capacity-reservation) and Neuron SDK 2.32.0 DLAMI guide, 2026-10-11

Ask before deleting anything the user did not create in this session. Termination is permanent.

## 1. Find what exists

```bash
aws ec2 describe-instances --filters "Name=instance-type,Values=inf2.*,trn1*.*,trn2*.*,trn3*.*" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,Tags[?Key==`Name`]|[0].Value]' --output text
aws ec2 describe-volumes --filters Name=status,Values=available --query 'Volumes[].[VolumeId,Size]' --output text
aws ec2 describe-capacity-reservations --query 'CapacityReservations[?State==`active`].[CapacityReservationId,InstanceType,AvailableInstanceCount]' --output text
```

Repeat for each region used (`--region`).

## 2. Stop serving

Stop the `vllm serve` process or container. Save compiled artifacts (`NEURON_COMPILED_ARTIFACTS` directory) to durable storage first if you will redeploy, because recompiling costs minutes of billed time.

## 3. Remove compute and storage

| Resource                 | Command                                                              | Notes                                                  |
| ------------------------ | -------------------------------------------------------------------- | ------------------------------------------------------ |
| Instance                 | `aws ec2 terminate-instances --instance-ids <id>`                    | A stopped instance still keeps its EBS volumes billing |
| Unattached EBS volumes   | `aws ec2 delete-volume --volume-id <id>`                             | Check contents first                                   |
| Capacity reservation     | `aws ec2 cancel-capacity-reservation --capacity-reservation-id <id>` | Reservations bill while active, used or not            |
| Security group, key pair | Delete only if created for this run                                  |                                                        |

## 4. Verify

Re-run the discovery commands: no Neuron instances, volumes or reservations should remain. Check Cost Explorer over the next day for Neuron instance and EBS charges.
