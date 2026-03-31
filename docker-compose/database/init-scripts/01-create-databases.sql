-- Create databases for all services
CREATE DATABASE gitlabdb;
CREATE DATABASE nextcloud;
CREATE DATABASE wikijs;
CREATE DATABASE grafana;

-- Create service users
CREATE USER gitlab WITH ENCRYPTED PASSWORD 'gitlab_password';
CREATE USER nextcloud WITH ENCRYPTED PASSWORD 'nextcloud_password';
CREATE USER wikijs WITH ENCRYPTED PASSWORD 'wikijs_password';
CREATE USER grafana WITH ENCRYPTED PASSWORD 'grafana_password';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE gitlabdb TO gitlab;
GRANT ALL PRIVILEGES ON DATABASE nextcloud TO nextcloud;
GRANT ALL PRIVILEGES ON DATABASE wikijs TO wikijs;
GRANT ALL PRIVILEGES ON DATABASE grafana TO grafana;
