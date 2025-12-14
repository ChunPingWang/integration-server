-- V1.0__create_schema.sql
-- 建立應用程式的資料庫 schema

-- 建立應用程式使用者
CREATE USER app_user IDENTIFIED BY app_password;

-- 授予必要權限
GRANT CONNECT, RESOURCE TO app_user;
GRANT CREATE SESSION TO app_user;
GRANT CREATE TABLE TO app_user;
GRANT CREATE VIEW TO app_user;
GRANT CREATE SEQUENCE TO app_user;
GRANT CREATE PROCEDURE TO app_user;

-- 配置 Quota
ALTER USER app_user QUOTA UNLIMITED ON USERS;

-- 建立預設 tablespace (可選)
-- CREATE TABLESPACE app_data DATAFILE '/opt/oracle/oradata/XE/app_data.dbf' SIZE 100M AUTOEXTEND ON;
-- ALTER USER app_user DEFAULT TABLESPACE app_data;

COMMIT;
