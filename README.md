# Canton Hard Domain Migration in One - Upgrading Protocol version

With the release of 2.9.1 PV versions 3 and 4 are no longer supported. 

The below demonstrates how to migrate from a sync domain running on a 2.3, 2.4, 2.5, 2.6, 2.7 or 2.8 release and protocol version 3 or 4 to a new sync domain running on the 2.9 release and protocol version 5. 

Specifically in this demo we will migrate from 2.3.20 pv 3 to 2.9.1 pv 5

#### _Note_ This demo assumes access to Digital Assets artifactory and enterprise images.

### Docs:

* [Upgrading To a New Release](https://docs.daml.com/canton/usermanual/upgrading.html)
* [One-Step Migration](https://docs.daml.com/canton/usermanual/upgrading.html#one-step-migration)

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

#### _Note_ Alternatively steps 2 and 3 below can be performed via a [canton script](./canton-scripts/remove-resources.canton). `docker compose run remove_resources`

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

4. Bring down the participants
```
docker compose down participanta participantb
``` 

5. Backup the databases. *Note: before migrating it is also recommended to `VACUUM` the databases.*
```
docker cp ./configs/postgres/backup.sql canton-postgres:/docker-entrypoint-initdb.d/backup.sql
docker exec -u postgres canton-postgres psql -f docker-entrypoint-initdb.d/backup.sql
```

6. Restart participants with new binaries and [migrate](https://docs.daml.com/Canton/usermanual/upgrading.html#migrating-the-database) the databases. For this demo the configuration option `Canton.participants.participant1.storage.parameters.migrate-and-start = yes` has been set within the participants config files. This allows for automatic schema migrations on startup. Therefore the nodes simply need to be restarted with the new binaries and db migrations are done automatically.

```
docker compose --profile updated-participants up -d
```

#### _Note_ Steps 7 - 8 can be performed via a [canton script](./canton-scripts/migrate.canton). `docker compose run migrate` .

7. Disconnect the participants from all domains and ensure they are disconnected by listing the connected domains. This should return an empty array. _(Within the Canton console)_
```
@ participanta.domains.disconnect_all
@ participanta.domains.list_connected() 

@ participantb.domains.disconnect_all
@ participantb.domains.list_connected() 
```

8. Migrate participants to the new domain _(Within the Canton console)_

* Set the sequencer connection configuration for the new domain 
```
@ val config = DomainConnectionConfig("newdomain", GrpcSequencerConnection.tryCreate("http://newdomain:5003"))
```

* Migrate to the new domain per participant 
```
@ participanta.repair.migrate_domain("olddomain", config) 
@ participantb.repair.migrate_domain("olddomain", config) 
```

* Connect the participants to the the new domain. This can be tested with:  `participant.domains.list_connected()` _(Within the Canton console)_
```
@ participanta.domains.connect(config) 
@ participanta.domains.list_connected() 

@ participantb.domains.connect(config)
@ participantb.domains.list_connected() 
```

#### _Note_ Steps 9 - 10 can be performed via a [canton script](./canton-scripts/migrate.canton). `docker compose run restore_and_test` .

9. Restore the resource limits on participants _(Within the Canton console)_
```
@ participanta.resources.set_resource_limits(participanta_resources)
@ participantb.resources.set_resource_limits(participantb_resources)
```

10. Check to ensure system is healthy by pinging the nodes from each other _(Within the Canton console)_

```
@ participanta.health.ping(participantb)
@ participantb.health.ping(participanta)
```

11. Remove the old existing domain

```
docker compose down olddomain
```

12. Upload additional contracts to the participants as a final test.
```
docker compose run --rm contracts
```

### Clean up 

Remove all containers and underlying volumes
```
docker compose --profile all -v down --remove-orphans 
```