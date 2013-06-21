-- Database: geofoam

-- DROP DATABASE geofoam CASCADE;

/*CREATE DATABASE geofoam
  WITH OWNER = postgres
       ENCODING = 'UTF8'
       TABLESPACE = pg_default
       LC_COLLATE = 'en_AU.UTF-8'
       LC_CTYPE = 'en_AU.UTF-8'
       CONNECTION LIMIT = -1;*/
     
	   

------------------------------------------------------------------------------------------------------

-- ENUM TYPES, DOMAINS, LOOKUP TABLES

------------------------------------------------------------------------------------------------------

CREATE TYPE mount_type AS ENUM ('Wall', 'Rack', 'Unknown');
CREATE TYPE placement_type AS ENUM ('Underground', 'Underwater', 'Indoor', 'Aerial', 'DirectBuried');
CREATE TYPE horizontal_align AS ENUM ('Left', 'Center', 'Right', 'Full');
CREATE TYPE cable_core_type AS ENUM ('Metallic, NonMetallic');
CREATE TYPE au_state AS ENUM ('NSW', 'VIC', 'QLD', 'WA', 'SA', 'TAS', 'NT');
CREATE TYPE port_type AS ENUM ('Input', 'Output');

CREATE DOMAIN color
	AS character varying
	CONSTRAINT color_in CHECK (VALUE IN ('Blue', 'Orange', 'Green', 'Brown', 'Slate', 'White', 'Red', 'Black', 'Yellow', 'Violet', 'Rose', 'Aqua'));

CREATE DOMAIN building_status 
	AS character varying 
	NOT NULL
	CONSTRAINT building_status_in CHECK (VALUE IN ('Complete', 'In-Progress', 'H', 'Review'));
	
CREATE DOMAIN job_status 
	AS character varying 
	NOT NULL
	CONSTRAINT job_status_in CHECK (VALUE IN ('new', 'as-built', 'in-progress', 'design'));

CREATE DOMAIN splice_type 
	AS character varying 
	NOT NULL
	CONSTRAINT splice_type_in CHECK (VALUE IN ('Fusion', 'Mechanical', 'Rotary', 'PassThru', 'Impicit', 'Unknown'));
	
CREATE DOMAIN fibre_mode 
	AS character varying 
	NOT NULL
	CONSTRAINT fibre_mode_value_in CHECK (VALUE IN ('SingleMode', 'MultiMode', 'DispersionShiftedfibre', 'LightwaveShiftedfibre', 'Hybrid', 'Unknown'));
	
CREATE DOMAIN fibre_status 
	AS character varying 
	NOT NULL
	CONSTRAINT fibre_status_value_in CHECK (VALUE IN ('Available', 'Dark', 'Broken', 'DeadToField', 'InUse', 'Unknown'));

CREATE DOMAIN measured_length 
	AS integer
    CONSTRAINT valid_measure CHECK (VALUE > 1 OR VALUE < 10000);
	
CREATE DOMAIN number_of_tubes
	AS integer
	NOT NULL
    CONSTRAINT valid_number_of_tubes CHECK (VALUE IN (1, 2, 3, 4, 5, 6, 8, 7, 10, 12, 18, 24, 26, 52));
	
CREATE DOMAIN number_of_fibres
	AS integer
	NOT NULL
    CONSTRAINT valid_number_of_fibres CHECK (VALUE IN (6, 12, 24, 36, 48, 60, 72, 84, 96, 108, 120, 132, 144, 216, 288, 312, 624));
	
CREATE DOMAIN conduit_material
	AS character varying
	CONSTRAINT conduit_material_value_in CHECK(VALUE IN ('PVC', 'BlackIronPipe', 'BlackSteelPipe', 'CastIronPipe', 'FlexDuct', 'SteelCasing', 'Unknown', 'NotApplicable'));
	
CREATE DOMAIN cable_sheath
	AS character varying
	CONSTRAINT cable_sheath_value_in CHECK(VALUE IN ('Blue Polyethylene', 'Black Polyethylene', 'Yellow Polyethylene', 'Unknown'));
	
CREATE DOMAIN diameter
	AS integer
	CONSTRAINT diameter_value_in CHECK(VALUE IN (100, 50, 63, 110, 32));

	

-- Table: owner

-- DROP TABLE owner CASCADE;
	   
CREATE TABLE owner
(
  name varchar(20),
  CONSTRAINT owner_pk PRIMARY KEY (name)
)
WITH (
  OIDS=FALSE
);

------------------------------------------------------------------------------------------------------

-- SPECIFICATION TABLES

------------------------------------------------------------------------------------------------------

-- Table: specification

-- DROP TABLE specification CASCADE;
	   
CREATE TABLE specification
(
  sid uuid,
  manufacturer varchar(20),
  description varchar(50),
  model_number varchar(20),
  CONSTRAINT spec_pk PRIMARY KEY (sid)
);

-- Table: cable_spec

-- DROP TABLE cable_spec CASCADE;

CREATE TABLE cable_spec (
	cable_id serial,
	mode fibre_mode,
	diameter integer,
	sheath cable_sheath,
	nb_tube number_of_tubes,
	nb_fibre number_of_fibres
) INHERITS (specification);

ALTER TABLE cable_spec ADD PRIMARY KEY (sid);

-- Table: joint_spec

-- DROP TABLE joint_spec CASCADE;

CREATE TABLE joint_spec (
	joint_id serial
) INHERITS (specification);

ALTER TABLE joint_spec ADD PRIMARY KEY (sid);

-- Table: patchpanel_spec

-- DROP TABLE patchpanel_spec CASCADE;

CREATE TABLE patchpanel_spec (
	patchpanel_id serial,
	input_port integer,
	output_port integer
) INHERITS (specification);

ALTER TABLE patchpanel_spec ADD PRIMARY KEY (sid);

-- Table: chamber_spec

-- DROP TABLE chamber_spec CASCADE;

CREATE TABLE chamber_spec (
	chamber_id serial
) INHERITS (specification);

ALTER TABLE chamber_spec ADD PRIMARY KEY (sid);

------------------------------------------------------------------------------------------------------

-- BASE TABLES

------------------------------------------------------------------------------------------------------

CREATE TABLE "object"
(
	ouid uuid NOT NULL, -- The unique identifier for the object.
	creation_user varchar(50), -- The user or designer who created the facility.
	date_created date, -- The date that the facility was created.
	date_modified date, -- The date that the facility was last modified.
	last_user varchar(50), -- The last user or designer to modify the facility.
	comments varchar(100) -- User or designer comment.
)
WITH (
  OIDS=TRUE
);

-- Table: network_object

-- DROP TABLE network_object CASCADE;

CREATE TABLE network_object
(
	reference varchar(20),
	work_order_id varchar(20), -- Utility identifier of work order
	project varchar(20), -- Utility identifier of work order
	clli varchar(20), -- Code descriptor used to identify telecommunications switches, interconnections and other network elements and their locations.
	owner varchar(20) REFERENCES owner (name), -- The owner of the facility.
	install_date date -- The date the facility was installed.
) INHERITS ("object");
	  
-- Table: network_edge_object

-- DROP TABLE network_edge_object CASCADE;

CREATE TABLE network_edge_object
(
	design_length integer, -- The design length of the segment.
	measured_length integer, -- The measured length of the segment.
	geom geometry, -- The geometry of the edge.
	CONSTRAINT enforce_dims_geom CHECK (ST_NDIMS(geom) = 2),
	CONSTRAINT enforce_geotype_geom CHECK (GeometryType(geom) = 'LINESTRING'::text OR geom IS NULL),
	CONSTRAINT enforce_srid_geom CHECK (st_srid(geom) = 3107)
) INHERITS (network_object);

-- Table: network_junction_object

-- DROP TABLE network_junction_object CASCADE;

CREATE TABLE network_junction_object
(
	gps_lat float(8), -- The latitude of the junction in degrees Lat Long.
	gps_lng float(8), -- The longitude of the junction in degrees Lat Long.
	geom geometry, -- The geometry of the junction.
	CONSTRAINT enforce_dims_geom CHECK (ST_NDIMS(geom) = 2),
	CONSTRAINT enforce_geotype_geom CHECK (GeometryType(geom) = 'POINT'::text OR geom IS NULL),
	CONSTRAINT enforce_srid_geom CHECK (st_srid(geom) = 3107)
) INHERITS (network_object);

-- Table: network_area_object

-- DROP TABLE network_area_object CASCADE;

CREATE TABLE network_area_object
(
	design_area integer, -- The design area.
	measured_area integer, -- The measured area.
	geom geometry, -- The geometry of the facility.
	CONSTRAINT enforce_dims_geom CHECK (ST_NDIMS(geom) = 2),
	CONSTRAINT enforce_geotype_geom CHECK (GeometryType(geom) = 'POLYGON'::text OR geom IS NULL),
	CONSTRAINT enforce_srid_geom CHECK (st_srid(geom) = 3107)
) INHERITS (network_object);


------------------------------------------------------------------------------------------------------

-- MAIN

------------------------------------------------------------------------------------------------------


-- Table: circuit

CREATE TABLE circuit (
	a_end varchar(20),
	b_end varchar(20),
	customer varchar(20)
) INHERITS (network_object);

ALTER TABLE circuit ADD PRIMARY KEY (ouid);

-- Table: conduit

/*

A Conduit is a linear object which belongs to the structural network. It is the outermost casing. A Conduit may contain Duct(s) and Innerduct(s). Duct(s) and Innerduct(s) are modeled as non-graphic objects stored in object classes. Conduit is a concrete feature class that contains information about the position and characteristics of ducts as seen from a manhole, vault, or a cross section of a trench and duct. Users can create duct characteristic fields to represent their business processes.

*/

-- DROP TABLE conduit CASCADE;

CREATE TABLE conduit (
	material varchar(20), -- The material of the conduit
	diameter diameter -- The diameter of the conduit
) INHERITS (network_edge_object);

ALTER TABLE conduit ADD PRIMARY KEY (ouid);

-- Table: fibre_cable

/*

A fibre Optic Cable is composed of thin filaments of glass through which light beams are transmitted to carry large amounts of data. The optical fibres are surrounded by buffers, strength members, and jackets for protection, stiffness, and strength. A fibre-optic cable may be an all-fibre cable, or contain both optical fibres and metallic conductors.

*/

-- DROP TABLE fibre_cable;

CREATE TABLE fibre_cable (
	nb_tube integer NOT NULL,
	nb_fibre integer NOT NULL,
	model varchar(20),
	begin_measure integer,
	end_measure integer,
	serial_number varchar(20),
	cable_spec_uid uuid
) INHERITS (network_edge_object);

ALTER TABLE fibre_cable ADD PRIMARY KEY (ouid);
ALTER TABLE fibre_cable ADD FOREIGN KEY (cable_spec_uid) REFERENCES cable_spec(sid) ON DELETE RESTRICT;

-- Table: duct_object
-- DROP TABLE duct_object;

CREATE TABLE duct_object (
	material varchar(20), -- The material of the duct
	size varchar(20), -- The diameter of the duct
	design_length integer, -- The design length of the segment
	measured_length integer, -- The measured length of the segment
	diameter diameter -- The diameter of the duct.
) INHERITS (network_object);

ALTER TABLE duct_object ADD PRIMARY KEY (ouid);

-- Table: duct
-- DROP TABLE duct;

CREATE TABLE duct (
	conduit_uid uuid, -- The unique identifier for the conduit.
	duct_number integer --The number of duct objects in the conduit.
) INHERITS (duct_object);

ALTER TABLE duct ADD PRIMARY KEY (ouid);
ALTER TABLE duct ADD FOREIGN KEY (conduit_uid) REFERENCES conduit(ouid) ON DELETE RESTRICT;

-- Table: subduct
-- DROP TABLE subduct;

CREATE TABLE subduct (
	duct_uid uuid, -- The unique identifier for the duct.
	subduct_number integer --The number of duct objects in the conduit.
) INHERITS (duct_object);

ALTER TABLE subduct ADD PRIMARY KEY (ouid);
ALTER TABLE subduct ADD FOREIGN KEY (duct_uid) REFERENCES duct(ouid) ON DELETE RESTRICT;

-- Table: loop

-- A maintenance loop is a coil of slack fibre cable that is used to support future splicing or other maintenance activities.

-- DROP TABLE loop;

CREATE TABLE maintenance_loop (
	loop_id serial, -- The unique ID for the loop.
	begin_measure integer, -- The mark-up at the begining.
	end_measure integer, -- The mark-up at the end.
	length integer -- The length of the loop.
) INHERITS ("object");

ALTER TABLE maintenance_loop ADD PRIMARY KEY (ouid);


-- Table: buffer_tube

/*

Buffer Tubes or bundles are groups of fibres bound together, typically at the ends only, and encased in a flexible protective jacket. The inside diameter of the protective jacket of a bundle is typically larger than the minimum outside diameter of the combined fibres.This allows the fibres to move freely inside of the jacket.

*/

-- DROP TABLE buffer_tube;

CREATE TABLE buffer_tube (
	buffer_number integer, -- The number of the buffer strand.
	buffer_color integer, -- The color of the fibre. Uses the fibre_buffer_color domain.
	number_of_fibres integer, -- The mode of the fibre. Uses the fibre_mode domain.
	fibre_cable_uid uuid -- The ID of the associated cable.
) INHERITS ("object");

ALTER TABLE buffer_tube ADD PRIMARY KEY (ouid);
ALTER TABLE buffer_tube ADD FOREIGN KEY (fibre_cable_uid) REFERENCES fibre_cable(ouid) ON DELETE CASCADE;



-- Table: fibre

-- An optical fibre is a thin filament of glass that is used to transmit voice, data, or video signals in the form of light energy (typically in pulses).

-- DROP TABLE fibre;

CREATE TABLE fibre (
	fibre_number integer, -- The number of the fibre strand.
	fibre_color integer, -- The color of the fibre.
	fibre_mode integer, -- The mode of the fibre. Uses the fibre_mode domain.
	fibre_status integer, -- The condition of the fibre. Uses the fibre_status domain.
	optical_length integer, -- The optical length of the fibre.
	attenuation varchar(20), -- The attenuation of the fibre.
	buffer_tube_uid uuid, -- The ID of the associated tube.
	fibre_cable_uid uuid, -- The ID of the associated cable.
	circuit_uid uuid -- The ID of the associated circuit.
) INHERITS ("object");

ALTER TABLE fibre ADD PRIMARY KEY (ouid);
ALTER TABLE fibre ADD FOREIGN KEY (buffer_tube_uid) REFERENCES buffer_tube(ouid) ON DELETE CASCADE;
ALTER TABLE fibre ADD FOREIGN KEY (fibre_cable_uid) REFERENCES fibre_cable(ouid) ON DELETE CASCADE;
ALTER TABLE fibre ADD FOREIGN KEY (circuit_uid) REFERENCES circuit(ouid) ON DELETE RESTRICT;

-- Table: fibre_splice

-- A fibre Splice is a connection between a strand of one fibre cable and a strand of another fibre cable.

-- DROP TABLE fibre_splice

CREATE TABLE fibre_splice (
	a_fibre_uid uuid NOT NULL, -- The fibre ID of the "A" fibre in the fibre_splice.
	a_fibre_number integer NOT NULL, -- The fibre_number of the "A" strand in the fibre_splice.
	b_fibre_uid uuid NOT NULL, -- The fibre ID of the "B" fibre in the fibre_splice.
	b_fibre_number integer NOT NULL, -- The fibre_number of the "B" strand in the fibre_splice.
	fibre_loss float(8), -- The amount of signal lost at the fibre_splice
	splice_type integer -- The type of splicing. Uses the splice_type domain.
) INHERITS ("object");

ALTER TABLE fibre_splice ADD PRIMARY KEY (ouid);
ALTER TABLE fibre_splice ADD FOREIGN KEY (a_fibre_uid) REFERENCES fibre(ouid) ON DELETE RESTRICT;
ALTER TABLE fibre_splice ADD FOREIGN KEY (b_fibre_uid) REFERENCES fibre(ouid) ON DELETE RESTRICT;


-- Table: patchpanel

-- A Patch Panel is device where connections are made between incoming and outgoing fibres. fibres in cables are connected to signal ports in this equipment. Ports are not shown graphically; therefore these are modeled using a relationship to the PatchPanelPort Object (database only features).

-- DROP TABLE patchpanel

CREATE TABLE patchpanel (
	mount_type mount_type -- Type of mount. Uses the mount_type domain.
) INHERITS (network_junction_object);

ALTER TABLE patchpanel ADD PRIMARY KEY (ouid);

-- Table: joint

-- A Joint establishes a connection between two or more fibre cables.

-- DROP TABLE joint

CREATE TABLE joint (
	mount_type integer -- Type of mount. Uses the mount_type domain.
) INHERITS (network_junction_object);

ALTER TABLE joint ADD PRIMARY KEY (ouid);

CREATE TABLE chamber (
	
) INHERITS (network_junction_object);

ALTER TABLE chamber ADD PRIMARY KEY (ouid);



-- Table: building

-- DROP TABLE building;

CREATE TABLE building (
	user_reference varchar(20), -- The user reference of the building.
	status building_status, -- The status of the building.
	address varchar(100), -- The generic address of the building.
	is_pop boolean -- Is this building a POP.
) INHERITS (network_area_object);

ALTER TABLE building ADD PRIMARY KEY (ouid);


------------------------------------------------------------------------------------------------------

-- LOCATION TABLE

------------------------------------------------------------------------------------------------------

-- Table: location
-- DROP TABLE location;
-- A location is typically where a customer address or other facility item of plant physically exists.

CREATE TABLE location (
	address_number varchar(10), -- The Street Address Number.
	number_first smallint, -- The first number (if multiple number).
	number_last smallint, -- The last number (if multiple number).
	street_name varchar(50), -- The street name of the address.
	prefix varchar(10), -- The prefix for the street of the address.
	suffix varchar(10), -- The suffix for the street of the address.
	city varchar(20), -- The city of the address.
	state  au_state, -- The state of the address.
	postcode integer, -- The postcode of the address.
	floor_number smallint, -- The floor number in the address.
	unit_number smallint, -- The unit number of the address.
	place_name varchar(10) -- The place name of the address.
) INHERITS (network_object);
 
ALTER TABLE location ADD PRIMARY KEY (ouid);


------------------------------------------------------------------------------------------------------

-- MANY-MANY TABLES

------------------------------------------------------------------------------------------------------



-- Table ManyToMany: duct_fibre_cable

CREATE TABLE duct_fibre_cable (
	duct_uid uuid,
	fibre_cable_uid uuid,
	CONSTRAINT duct_fibre_cable_pkey PRIMARY KEY (duct_uid, fibre_cable_uid)
);

ALTER TABLE duct_fibre_cable ADD FOREIGN KEY (duct_uid) REFERENCES duct (ouid) ON UPDATE CASCADE ON DELETE CASCADE;
ALTER TABLE duct_fibre_cable ADD FOREIGN KEY (fibre_cable_uid) REFERENCES fibre_cable (ouid) ON UPDATE CASCADE ON DELETE CASCADE;


-- Table ManyToMany: subduct_fibre_cable

CREATE TABLE subduct_fibre_cable (
	subduct_uid uuid,
	fibre_cable_uid uuid,
	CONSTRAINT subduct_fibre_cable_pkey PRIMARY KEY (subduct_uid, fibre_cable_uid)
);

ALTER TABLE subduct_fibre_cable ADD FOREIGN KEY (subduct_uid) REFERENCES subduct (ouid) ON UPDATE CASCADE ON DELETE CASCADE;
ALTER TABLE subduct_fibre_cable ADD FOREIGN KEY (fibre_cable_uid) REFERENCES fibre_cable (ouid) ON UPDATE CASCADE ON DELETE CASCADE;


-- Table ManyToMany: conduit_chamber

CREATE TABLE conduit_chamber (
	conduit_uid uuid,
	chamber_uid uuid,
	CONSTRAINT conduit_chamber_pkey PRIMARY KEY (conduit_uid, chamber_uid)
);

ALTER TABLE conduit_chamber ADD FOREIGN KEY (conduit_uid) REFERENCES conduit (ouid) ON UPDATE CASCADE ON DELETE CASCADE;
ALTER TABLE conduit_chamber ADD FOREIGN KEY (chamber_uid) REFERENCES chamber (ouid) ON UPDATE CASCADE ON DELETE CASCADE;


-- Table ManyToMany: conduit_fibre_cable

CREATE TABLE conduit_fibre_cable (
	conduit_uid uuid,
	fibre_cable_uid uuid,
	CONSTRAINT conduit_fibre_cable_pkey PRIMARY KEY (conduit_uid, fibre_cable_uid)
);

ALTER TABLE conduit_fibre_cable ADD FOREIGN KEY (conduit_uid) REFERENCES conduit (ouid) ON UPDATE CASCADE ON DELETE CASCADE;
ALTER TABLE conduit_fibre_cable ADD FOREIGN KEY (fibre_cable_uid) REFERENCES fibre_cable (ouid) ON UPDATE CASCADE ON DELETE CASCADE;



------------------------------------------------------------------------------------------------------

-- TRIGGER FUNCTIONS

------------------------------------------------------------------------------------------------------

-- ON OBJECT INSERT

CREATE OR REPLACE FUNCTION obj_insert_stamp() RETURNS trigger AS $obj_insert_stamp$
    BEGIN
		-- Check the ouid
        IF NEW.ouid IS NULL THEN
            NEW.ouid = uuid_generate_v1mc();
        END IF;
	
        -- Check the creation_user name
        IF NEW.creation_user IS NULL THEN
            NEW.creation_user = current_user;
        END IF;

        -- asign date
        NEW.date_created := current_timestamp;
        RETURN NEW;
    END;
$obj_insert_stamp$ LANGUAGE plpgsql;



-- ON OBJECT UPDATE

CREATE OR REPLACE FUNCTION obj_update_stamp() RETURNS trigger AS $obj_update_stamp$
    BEGIN
        -- Check the creation_user name
        IF NEW.last_user IS NULL THEN
            NEW.last_user = current_user;
        END IF;

        -- asign date
        NEW.date_modified := current_timestamp;
        RETURN NEW;
    END;
$obj_update_stamp$ LANGUAGE plpgsql;



-- ON FIBRE_CABLE INSERT

CREATE OR REPLACE FUNCTION buffer_tube_insert() RETURNS trigger AS $buffer_tube_insert$
    DECLARE
		nb_tube integer;
		nb_fibre integer;
		i integer;
	BEGIN
		nb_tube = NEW.nb_tube;
		nb_fibre = NEW.nb_fibre / nb_tube;
		i = 1;
		LOOP
			INSERT INTO buffer_tube (buffer_number, buffer_color, number_of_fibres, fibre_cable_uid) VALUES (i, i, nb_fibre, NEW.ouid);
			i = i + 1;
			IF i > nb_tube THEN
				EXIT; -- exit loop
			END iF;
		END LOOP;
        RETURN NEW;
    END;
$buffer_tube_insert$ LANGUAGE plpgsql;


-- ON FIBER_CABLE CUT...

CREATE OR REPLACE FUNCTION cable_insert_stamp() RETURNS trigger AS $cable_insert_stamp$
	DECLARE
		valid integer;
    BEGIN
		-- Check the ouid
        IF NEW.ouid IS NULL THEN
            NEW.ouid = uuid_generate_v1mc();
        END IF;
		
		------------ TRICKY PART ---------------------------------------
		
		valid = select 1 from "object" where ouid = NEW.ouid limit 1;
		
		-- Check the ouid
        IF valid = 1 THEN
            NEW.ouid = uuid_generate_v1mc();
        END IF;
		
		----------------------------------------------------------------
	
        -- Check the creation_user name
        IF NEW.creation_user IS NULL THEN
            NEW.creation_user = current_user;
        END IF;

        -- asign date
        NEW.date_created := current_timestamp;
        RETURN NEW;
    END;
$cable_insert_stamp$ LANGUAGE plpgsql;


-- ON BUFFER_TUBE INSERT

CREATE OR REPLACE FUNCTION fibre_insert() RETURNS trigger AS $fibre_insert$
    DECLARE
		nb_fibre integer;
		tube_nb integer;
		i integer;
		j integer;
	BEGIN
		nb_fibre = NEW.number_of_fibres;
		tube_nb = NEW.buffer_number;
		i = 1;
		j = tube_nb * nb_fibre - 11;
		LOOP
			INSERT INTO fibre (fibre_number, fibre_color, buffer_tube_uid, fibre_cable_uid) VALUES (j, i, NEW.ouid, NEW.fibre_cable_uid);
			i = i + 1;
			j = j + 1;
			IF i > nb_fibre THEN
				EXIT; -- exit loop
			END iF;
		END LOOP;
        RETURN NEW;
    END;
$fibre_insert$ LANGUAGE plpgsql;

------------------------------------------------------------------------------------------------------

-- CREATE TRIGGER

------------------------------------------------------------------------------------------------------

CREATE TRIGGER obj_insert_stamp BEFORE INSERT ON conduit
    FOR EACH ROW EXECUTE PROCEDURE obj_insert_stamp();
	
CREATE TRIGGER obj_update_stamp BEFORE UPDATE ON conduit
    FOR EACH ROW EXECUTE PROCEDURE obj_update_stamp();
	
------------------------------------------------------------------------------------------------------

CREATE TRIGGER obj_insert_stamp BEFORE INSERT ON fibre_cable
    FOR EACH ROW EXECUTE PROCEDURE obj_insert_stamp();
	
CREATE TRIGGER obj_update_stamp BEFORE UPDATE ON fibre_cable
    FOR EACH ROW EXECUTE PROCEDURE obj_update_stamp();
	
CREATE TRIGGER buffer_tube_insert AFTER INSERT ON fibre_cable
    FOR EACH ROW EXECUTE PROCEDURE buffer_tube_insert();
	
------------------------------------------------------------------------------------------------------

CREATE TRIGGER obj_insert_stamp BEFORE INSERT ON buffer_tube
    FOR EACH ROW EXECUTE PROCEDURE obj_insert_stamp();
	
CREATE TRIGGER obj_update_stamp BEFORE UPDATE ON buffer_tube
    FOR EACH ROW EXECUTE PROCEDURE obj_update_stamp();
	
CREATE TRIGGER fibre_insert AFTER INSERT ON buffer_tube
    FOR EACH ROW EXECUTE PROCEDURE fibre_insert();
	
------------------------------------------------------------------------------------------------------

CREATE TRIGGER obj_insert_stamp BEFORE INSERT ON fibre
    FOR EACH ROW EXECUTE PROCEDURE obj_insert_stamp();
	
CREATE TRIGGER obj_update_stamp BEFORE UPDATE ON fibre
    FOR EACH ROW EXECUTE PROCEDURE obj_update_stamp();
	
------------------------------------------------------------------------------------------------------
	
CREATE TRIGGER obj_insert_stamp BEFORE INSERT ON building
    FOR EACH ROW EXECUTE PROCEDURE obj_insert_stamp();
	
CREATE TRIGGER obj_update_stamp BEFORE UPDATE ON building
    FOR EACH ROW EXECUTE PROCEDURE obj_update_stamp();
	
------------------------------------------------------------------------------------------------------
	
CREATE TRIGGER obj_insert_stamp BEFORE INSERT ON duct
    FOR EACH ROW EXECUTE PROCEDURE obj_insert_stamp();
	
CREATE TRIGGER obj_update_stamp BEFORE UPDATE ON duct
    FOR EACH ROW EXECUTE PROCEDURE obj_update_stamp();
	
------------------------------------------------------------------------------------------------------
	
CREATE TRIGGER obj_insert_stamp BEFORE INSERT ON subduct
    FOR EACH ROW EXECUTE PROCEDURE obj_insert_stamp();
	
CREATE TRIGGER obj_update_stamp BEFORE UPDATE ON subduct
    FOR EACH ROW EXECUTE PROCEDURE obj_update_stamp();
	
------------------------------------------------------------------------------------------------------
	
CREATE TRIGGER obj_insert_stamp BEFORE INSERT ON maintenance_loop
    FOR EACH ROW EXECUTE PROCEDURE obj_insert_stamp();
	
CREATE TRIGGER obj_update_stamp BEFORE UPDATE ON maintenance_loop
    FOR EACH ROW EXECUTE PROCEDURE obj_update_stamp();

------------------------------------------------------------------------------------------------------
	
CREATE TRIGGER obj_insert_stamp BEFORE INSERT ON location
    FOR EACH ROW EXECUTE PROCEDURE obj_insert_stamp();
	
CREATE TRIGGER obj_update_stamp BEFORE UPDATE ON location
    FOR EACH ROW EXECUTE PROCEDURE obj_update_stamp();

------------------------------------------------------------------------------------------------------
	
CREATE TRIGGER obj_insert_stamp BEFORE INSERT ON patchpanel
    FOR EACH ROW EXECUTE PROCEDURE obj_insert_stamp();
	
CREATE TRIGGER obj_update_stamp BEFORE UPDATE ON patchpanel
    FOR EACH ROW EXECUTE PROCEDURE obj_update_stamp();
	
------------------------------------------------------------------------------------------------------
	
CREATE TRIGGER obj_insert_stamp BEFORE INSERT ON chamber
    FOR EACH ROW EXECUTE PROCEDURE obj_insert_stamp();
	
CREATE TRIGGER obj_update_stamp BEFORE UPDATE ON chamber
    FOR EACH ROW EXECUTE PROCEDURE obj_update_stamp();


------------------------------------------------------------------------------------------------------

-- Populate geometry columns
	   
SELECT Populate_Geometry_Columns();
