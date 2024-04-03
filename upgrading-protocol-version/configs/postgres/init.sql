ALTER SYSTEM SET max_connections = 1000;
CREATE ROLE canton WITH PASSWORD 'supersafe' LOGIN;
CREATE DATABASE olddomain OWNER canton;
CREATE DATABASE newdomain OWNER canton;
CREATE DATABASE participanta OWNER canton;
CREATE DATABASE participantb OWNER canton;

