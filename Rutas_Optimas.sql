--Extensión Postgis
create extension postgis

--Extensión Pgrouting
create extension pgrouting

--Extensión Topología
create extension postgis_topology

--Creación de topología
alter table vias drop column source 
alter table vias drop column target
ALTER TABLE vias ADD COLUMN "source" integer;
ALTER TABLE vias ADD COLUMN "target" integer;
--Columna para el costo
alter table vias drop column "cost"
ALTER TABLE vias ADD COLUMN "cost" float8;
UPDATE vias SET cost = ST_Length(geom);

select topology.DropTopology('vias')
select topology.CreateTopology('vias')

select pgr_CreateTopology('vias',0.0001,'geom','gid')
select * from vias_vertices_pgr

--Eliminación de datos nulos
select * from vias where source is null
delete from vias where gid=105717

--Concatenación de la información PLACAS
create table direcciones as (
	select gid, pdocodigo, pdoangulo, pdonvial, CONCAT (p.pdonvial ||'#'||p.pdotexto||'-'||p.pdotipo) as direccion, p.geom
	from placas as p)

--Direcciones de Interes
drop table direc_ruta_opt
create table direc_ruta_opt (
	universidad char (50),
	dir character varying (100) not null);
insert into direc_ruta_opt values ('Universidad Nacional','AK 30#45 03-1'); --Universidad Nacional--
insert into direc_ruta_opt values ('Universidad Javeriana','AK 7#40B 62-1');  --Universidad Javeriana--
insert into direc_ruta_opt values ('Fundacion Universitaria de Ciencias de la Salud','KR 52#67A 72-2');  --Fundación Universitaria de Ciencias de la Salud--
insert into direc_ruta_opt values ('Univerdad El Rosario','AK 24#63C 72-1');  --Univerdad El Rosario--
insert into direc_ruta_opt values ('Fundacion Escuela de Medicina Juan N Corpas','TV 21#98 81-1');  --Fundación Escuela de Medicina Juan N Corpas--
insert into direc_ruta_opt values ('Universidad Antonio Nariño','KR 3 E#47A 15-1');  --Universidad Antonio Nariño--
insert into direc_ruta_opt values ('Universidad de los Andes','KR 1#18A 12-1');  --Universidad de los Andes--
insert into direc_ruta_opt values ('Universidad Sanitas','AK 7#173 64-1'); --Universidad Sanitas--
insert into direc_ruta_opt values ('Universidad Jorge Tadeo Lozano','KR 4#22 61-3');  --Universidad Jorge Tadeo Lozano--
insert into direc_ruta_opt values ('Universidad del Bosque','AK 9#133 30-1');  --Universidad del Bosque--
insert into direc_ruta_opt values ('Casa Estudiante','CL 168#62 66-1');  --Casa Estudiante--
select * from direc_ruta_opt

--Tabla con direcciones para la busqueda
drop table dir_bus
create table dir_bus as (
	select * from direcciones as dir, direc_ruta_opt as dro 
	where dir.direccion = dro.dir)
select * from dir_bus

--Distancia entre nodos y direcciones
drop table distancias
create table distancias as (
	select universidad ,pdoangulo, pdonvial, id, gid, pdocodigo, dir, the_geom, st_distance(vvp.the_geom, db.geom) as dist
	from vias_vertices_pgr as vvp, dir_bus as db)

--Elección de nodo más cercano
drop table min_nodo
create table min_nodo as (
	select universidad,dir, min (dist)
	from distancias
	group by universidad, dir
	order by universidad, dir)
select * from min_nodo

--Atributos de los nodos
drop table atri_nodos
create table atri_nodos as (
	select distinct d.* from distancias as d, min_nodo as mn
	where mn.min=d.dist)
select * from atri_nodos

--Algoritmo TSP-Dijkstra+
drop table ruta_optima
create table ruta_optima as (
	select seq, id1 AS node, id2 AS edge, round(cost::numeric, 2) AS cost
        from pgr_tsp 
        ('SELECT id::int, gid, st_x(the_geom) as x,st_y(the_geom) as y FROM atri_nodos
	ORDER BY id', 8799))
select * from ruta_optima

----------------------------------------------------------------------------------------------------------------------
 
--Creación tabla nodos de inicio
create table pto_ini as (  
	select seq, edge, the_geom
	from ruta_optima, atri_nodos
	where ruta_optima.edge=atri_nodos.id )
insert into pto_ini (edge,seq, the_geom) 
	select edge, 11, the_geom 
	from pto_ini 
	where edge=8799
	
select * from pto_ini


--Creación tabla nodos finales
create table pto_fin as (
	select (seq+1) seg , edge, the_geom
	from ruta_optima, atri_nodos
	WHERE  ruta_optima.edge=atri_nodos.id)
select * from pto_fin


--Creación tabla ruta trazada
create table ruta as (
	select pi.seq, pf.edge nodo_i, pi.edge, st_makeline(pi.the_geom,pf.the_geom) geom
	from pto_ini as pi, pto_fin pf where pi.seq=pf.seg )
select * from ruta

