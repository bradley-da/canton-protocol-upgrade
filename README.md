# Demo

How to upgrade a set of Canton nodes to new _binaries_ and a new _protocol version_.

### Docs:

* [Upgrading Canton Binary](https://docs.daml.com/Canton/usermanual/upgrading.html#upgrade-Canton-binary)

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

### Upgrade Process:
1. Start a new domain with new binaries and protocol version. Note this domain must be completely independent of the old domain.
```
docker compose --profile new-domain up -d
```

2. Bring down the participants
```
docker compose down investor originator
``` 

3. Backup the participant databases to allow to roll back in case of failure.
```
docker cp ./configs/postgres/backup.sql canton-postgres:/docker-entrypoint-initdb.d/backup.sql
docker exec -u postgres canton-postgres psql -f docker-entrypoint-initdb.d/backup.sql
```
4. Restart participants with new binaries and [migrate](https://docs.daml.com/Canton/usermanual/upgrading.html#migrating-the-database) the databases. For this demo the configuration option `Canton.participants.participant1.storage.parameters.migrate-and-start = yes` has been set within the participants config files. This allows for automatic schema migrations on startup. Therefore the nodes simply need to be restarted with the new binaries and db migrations are done automatically.

```
docker compose --profile updated-participants up -d
```

#### Note: Steps 5 - 11 can be run via canton script with the command ...

5. Enter a Canton console from a new terminal connected to both domains as well as the participants. Note the flag `features.enable-repair-commands=yes` must be enabled within the remote config.
```
docker compose run --rm  console
```

6. Save the resource limits of the participants for restoring after the upgrade process and then set the limits to 0. _(Within the Canton console)_
```
@ val participantA_resources = participantA.resources.resource_limits()
@ participantA.resources.set_resource_limits(ResourceLimits(Some(0), Some(0))) 

@ val participantB_resources = participantB.resources.resource_limits()
@ participantB.resources.set_resource_limits(ResourceLimits(Some(0), Some(0)))
```

7. Disconnect the participants from the domain and ensure they are disconnected by listing the connected domains. This should return an empty array. _(Within the Canton console)_
```
@ participantA.domains.disconnect("olddomain")
@ participantA.domains.list_connected() 

@ participantB.domains.disconnect("olddomain")
@ participantB.domains.list_connected() 
```

8. Migrate participants to the new domain _(Within the Canton console)_

* Set the sequencer connection configuration for the new domain 
```
@ val config = DomainConnectionConfig("newdomain", GrpcSequencerConnection.tryCreate("http://newdomain:5003"))
```

* Migrate to the new domain per participant 
```
@ participantA.repair.migrate_domain("olddomain", config) 
@ participantB.repair.migrate_domain("olddomain", config) 
```

9. Reconnect the participants. Note that if the migration has been succesful the only domain the participants should connect to is the new domain. This can be tested with:  `participant.domains.list_connected()` _(Within the Canton console)_
```
@ participantA.domains.reconnect_all() 
@ participantA.domains.list_connected() 

@ participantB.domains.reconnect_all() 
@ participantB.domains.list_connected() 
```

10. Remove the resource limits on participants _(Within the Canton console)_
```
@ participantA.resources.set_resource_limits(participantA_resources)
@ participantB.resources.set_resource_limits(participantB_resources)
```

11. Check to ensure system is healthy by pinging the nodes from each other _(Within the Canton console)_

```
@ participantA.health.ping(participantB)
@ participantB.health.ping(participantA)
```

12. Remove the old existing domain

```
docker compose down olddomain
```


### Clean up 

Remove all containers and underlying volumes
```
docker compose --profile all -v down 
```