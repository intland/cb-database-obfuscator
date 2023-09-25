alter table object_reference add id int PRIMARY KEY AUTO_INCREMENT;
#copy users table because obfuscating will destroy it
CREATE TABLE tmp_users like users;
INSERT INTO tmp_users select * from users;
