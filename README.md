# Canton Hard Domain Migration - Upgrading Protocol versions

How to perform a Hard domain migration typically used in upgrading protocol versions. 

This demo shows 2 possible ways of performing this. 
- Using a canton console and manually running the commands 
- Using canton scripts to automate the process 

#### _Note_ This demo assumes access to Digital Assets artifactory and enterprise images.

### Docs:

* [Upgrading Protocol Version](https://docs.daml.com/Canton/usermanual/upgrading.html#change-the-Canton-protocol-version)

## Steps

### Setup:
1. Build the required dar
```
daml build
```
2. Start the domain and participants 
```
docker compose --profile startup up -d
```
3. Upload contracts to the participants once startup has completed
```
docker compose run --rm contracts
```

### Upgrade Process:
1. Start a new domain with new protocol version. Note this domain must be completely independent of the old domain.
```
docker compose --profile new-domain up -d
```

#### _Note_ Alternatively steps 2 and 3 below can be performed via a [canton script](./configs/remote/remove-resources.canton). `docker compose run remove_resources`

2. Enter a Canton console from a new terminal connected to both domains as well as the participants. Note the flag `features.enable-repair-commands=yes` must be enabled within the remote config.
```
docker compose run --rm  console
```

3. Save the resource limits of the participants for restoring after the upgrade process and then set the limits to 0. _(Within the Canton console)_

```
@ val participanta_resources = participanta.resources.resource_limits()
@ utils.write_to_file(participanta_resources.toProtoV0, "/canton/host/configs/participanta_resources.pb")
@ participanta.resources.set_resource_limits(ResourceLimits(Some(0), Some(0)))

@ val participantb_resource = participantb.resources.resource_limits()
@ utils.write_to_file(participantb_resource.toProtoV0, "/canton/host/configs/participantb_resource.pb")
@ participantb.resources.set_resource_limits(ResourceLimits(Some(0), Some(0)))
```

4. In a production environment now would be a good time to backup the participant databases to allow for a role back in case of failure.

#### _Note_ Steps 5 - 9 can be performed via a [canton script](./configs/remote/migrate.canton). `docker compose run migrate` .

5. Disconnect the participants from the domain and ensure they are disconnected by listing the connected domains. This should return an empty array. _(Within the Canton console)_
```
@ participanta.domains.disconnect("olddomain")
@ participanta.domains.list_connected() 

@ participantb.domains.disconnect("olddomain")
@ participantb.domains.list_connected() 
```

6. Migrate participants to the new domain _(Within the Canton console)_

* Set the sequencer connection configuration for the new domain 
```
@ val config = DomainConnectionConfig("newdomain", GrpcSequencerConnection.tryCreate("http://newdomain:5003"))
```

* Migrate to the new domain per participant 
```
@ participanta.repair.migrate_domain("olddomain", config) 
@ participantb.repair.migrate_domain("olddomain", config) 
```

7. Reconnect the participants. Note that if the migration has been succesful the only domain the participants should connect to is the new domain. This can be tested with:  `participant.domains.list_connected()` _(Within the Canton console)_
```
@ participanta.domains.reconnect_all() 
@ participanta.domains.list_connected() 

@ participantb.domains.reconnect_all() 
@ participantb.domains.list_connected() 
```

8. Restore the resource limits on participants _(Within the Canton console)_
```
@ participanta.resources.set_resource_limits(participanta_resources)
@ participantb.resources.set_resource_limits(participantb_resources)
```

9. Check to ensure system is healthy by pinging the nodes from each other _(Within the Canton console)_

```
@ participanta.health.ping(participantb)
@ participantb.health.ping(participanta)
```

10. Remove the old existing domain

```
docker compose down olddomain
```

11. Upload additional contracts to the participants as a final test.
```
docker compose run --rm contracts
```

### Clean up 

Remove all containers and underlying volumes
```
docker compose --profile all -v down
```