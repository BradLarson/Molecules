#! /bin/bash
sqlite3 molecules.sql  "CREATE TABLE database_settings(version INTEGER);"
sqlite3 molecules.sql  "INSERT INTO database_settings(version) VALUES(1);"
sqlite3 molecules.sql  "CREATE TABLE molecules(id INTEGER PRIMARY KEY,filename TEXT,title TEXT,compound TEXT,format INTEGER,atom_count INTEGER,bond_count INTEGER,structure_count INTEGER, centerofmass_x REAL,centerofmass_y REAL,centerofmass_z REAL,minimumposition_x REAL,minimumposition_y REAL,minimumposition_z REAL,maximumposition_x REAL,maximumposition_y REAL,maximumposition_z REAL);"
sqlite3 molecules.sql  "CREATE TABLE metadata(id INTEGER PRIMARY KEY,molecule INTEGER,type INTEGER,value TEXT);"
#sqlite3 molecules.sql  "CREATE TABLE residues(id INTEGER PRIMARY KEY,molecule INTEGER,type INTEGER);"
sqlite3 molecules.sql  "CREATE TABLE atoms(id INTEGER PRIMARY KEY,molecule INTEGER,residue INTEGER,structure INTEGER,element INTEGER,x REAL,y REAL,z REAL);"
sqlite3 molecules.sql  "CREATE TABLE bonds(id INTEGER PRIMARY KEY,molecule INTEGER,residue INTEGER,structure INTEGER,bond_type INTEGER,start_x REAL,start_y REAL,start_z REAL,end_x REAL,end_y REAL,end_z REAL);"
