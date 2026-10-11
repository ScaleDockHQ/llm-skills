# Vast.ai teardown: stop every billable resource

> Verified against vastai CLI 1.8.3 (destroy instance, destroy instances, delete endpoint, delete workergroup, delete volume references), docs.vast.ai guides/instances/storage/volumes, guides/serverless, 2026-10-11

Stopping is not enough: a stopped instance still bills for storage and can lose its GPU. List, confirm with the user what will be deleted and what data is lost, then destroy.

## 1. Inventory

```bash
vastai show instances            # every instance, status and hourly cost
vastai show endpoints            # Serverless endpoints
vastai show workergroups
vastai show volumes              # local volumes and the instances using them
vastai show api-keys
vastai show user                 # credit balance; do not paste the output
```

Copy anything you need out first (`vastai copy C.<ID>:/path ...` to a cloud connection or another instance, or `scp` over `vastai ssh-url`). Container storage is deleted on destroy.

## 2. Remove in this order

1. **Serverless**: workergroups and endpoints. **Destroying the endpoint is the only state that stops all billing.**

   ```bash
   vastai delete workergroup <WORKERGROUP_ID>
   vastai delete endpoint <ENDPOINT_ID>
   ```

   Then check `vastai show instances` for leftover worker instances and destroy any that remain.

2. **Instances**: destroy is irreversible and removes the container disk.

   ```bash
   vastai destroy instance <INSTANCE_ID>
   vastai destroy instances <ID> <ID>
   ```

3. **Volumes**, after the instances using them are destroyed (volumes keep billing until deleted):

   ```bash
   vastai delete volume <VOLUME_ID>
   ```

4. **Credentials**: delete API keys created for the job (`vastai delete api-key <id>`), delete SSH keys you added (`vastai delete ssh-key <id>`), remove account env vars you set (`vastai delete env-var <name>`), and remove local key files (`rm -P ~/.config/vastai/vast_api_key` on macOS, `shred -u` on Linux) if they were temporary.
5. **Gateway and clients**: remove the LiteLLM entry and any `OPENAI_BASE_URL` pointing at the old address or `openai.vast.ai/<endpoint>`.

## 3. Verify nothing accrues

```bash
vastai show instances            # expect empty
vastai show endpoints            # expect empty
vastai show volumes              # expect only volumes you intend to keep
```

Confirm in the console billing page after a few minutes that the hourly rate is zero (the CLI list can lag). Check the credit balance with `vastai show user` the next day for unexpected deductions, particularly bandwidth.

## Traps

- A `loading` or `scheduling` instance already bills storage. Destroy it, do not wait.
- If a host machine goes offline, you are not charged while offline, but billing resumes when it returns. Destroy the instance and delete the volume to stop it permanently.
- Interruptible instances that were paused still hold storage.
- Instances may be paused or exited without you noticing; always rely on `show instances`, not on memory.
- The CLI only shows resources for the account of the key you use; teams and sub-accounts have their own lists.
