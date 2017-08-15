-- 
CREATE OR REPLACE PROCEDURE DOMI_REF_CATASTRAL
AS
CURSOR CIBI IS SELECT ENTIDAD,SUCURSAL,DC,CUENTA,F_DOMICILIACION,DNI_FACTURA,
	REF_CATASTRAL, NUMERO_SECUENCIAL,PRIMER_CARACTER_CONTROL,SEGUN_CARACTER_CONTROL
	FROM IBI WHERE MUNICIPIO='176' AND YEAR='2000' AND DOMICILIADO='S';
BEGIN

	FOR v_TIbi IN CIBI LOOP
		UPDATE IBI SET
			DOMICILIADO='S',
			ENTIDAD=v_TIbi.ENTIDAD,
			SUCURSAL=v_TIbi.SUCURSAL,
			DC=v_TIbi.DC,
			CUENTA=v_TIbi.CUENTA,
			F_DOMICILIACION=v_TIbi.F_DOMICILIACION,
			DNI_FACTURA=v_TIbi.DNI_FACTURA

		where MUNICIPIO='176' 
			AND YEAR='2001'
			AND DOMICILIADO='N'
			AND REF_CATASTRAL=v_TIbi.REF_CATASTRAL
			AND NUMERO_SECUENCIAL=v_TIbi.NUMERO_SECUENCIAL
			AND PRIMER_CARACTER_CONTROL=v_TIbi.PRIMER_CARACTER_CONTROL
			AND SEGUN_CARACTER_CONTROL=v_TIbi.SEGUN_CARACTER_CONTROL;

	END LOOP;

END;
/

EXECUTE DOMI_REF_CATASTRAL;
drop PROCEDURE DOMI_REF_CATASTRAL;


*************************************************************************
**************************************************************************

alter TRIGGER ADD_HISTO_CONTRI disable;

CREATE OR REPLACE PROCEDURE modiHISTOCONTRI
AS

cursor chistorico is SELECT nif,NOMBRE,VIA,CALLE,NUMERO,ESCALERA,PLANTA,
      			PISO,POBLACION,PROVINCIA,CODIGO_POSTAL,PAIS
		 FROM HDOMICONTRI WHERE FECHA>='26/06/2001'
	order by nif,fecha desc;

BEGIN

	FOR v_TIbi IN Chistorico LOOP

			update contribuyentes set 
					NOMBRE=v_TIbi.NOMBRE,
					VIA=v_TIbi.VIA,
					CALLE=v_TIbi.CALLE,
					NUMERO=v_TIbi.NUMERO,
					ESCALERA=v_TIbi.ESCALERA,
					PLANTA=v_TIbi.PLANTA,
	      			PISO=v_TIbi.PISO,
					POBLACION=v_TIbi.POBLACION,
					PROVINCIA=v_TIbi.PROVINCIA,
					CODIGO_POSTAL=v_TIbi.CODIGO_POSTAL,
					PAIS=v_TIbi.PAIS
			where nif=v_TIbi.NIF;
	END LOOP;
END;
/

execute modiHISTOCONTRI;
delete from HDOMICONTRI WHERE FECHA>='26/06/2001';
drop PROCEDURE modiHISTOCONTRI;
alter TRIGGER ADD_HISTO_CONTRI enable;


****************************************************************************************
********** poner a la cinta del año 2001 los NIF que estan en blanco con los NIF del año 2000
****************************************************************************************
CREATE OR REPLACE PROCEDURE NIF_MAL_IBI
AS
xNIF char(10);

CURSOR CIBI IS SELECT NUM_FIJO FROM IBI WHERE MUNICIPIO='176' 
	AND YEAR='2001' AND rtrim(NIF) IS NULL
	FOR UPDATE OF NIF;

BEGIN

	FOR v_TIbi IN CIBI LOOP

		BEGIN
			select nif into xNIF
			from IBI WHERE MUNICIPIO='176' AND YEAR='2000' AND NUM_FIJO=v_TIbi.NUM_FIJO;
		exception
			when no_data_found then
				xNIF:=null;
		end;

		if xNIF is not null then
			UPDATE IBI SET NIF=xNIF	WHERE current of CIBI;
		end if;

	END LOOP;

END;
/

EXECUTE NIF_MAL_IBI;
drop PROCEDURE NIF_MAL_IBI;


*****************************************************************************************************
**** poner a la cinta de rustica del año 2002 los NIF que estan en blanco 
**** con los NIF del año 2001 buscandolo en valores por el campo clave_concepto
**** Eliminados updates sobre tablas TributosContri y DomiContri q pasan a rellenarse como temporales
*****************************************************************************************************
CREATE OR REPLACE PROCEDURE NIF_MAL_RUSTICA
AS
xNIF char(10);

CURSOR CIBI IS SELECT id,NUM_FIJO FROM rus80 WHERE MUNICIPIO='176' 
	AND YEAR='2002' AND rtrim(NIF) IS NULL;

BEGIN

	FOR v_TIbi IN CIBI LOOP

		update nada set campo1=1;
		xNIF:=null;
		BEGIN
			select nif into xNIF
			from valores WHERE ayto='176' AND padron='000070' and YEAR='2001' 
					AND substr(clave_concepto,1,7)=substr(v_TIbi.NUM_FIJO,1,7);
		exception
			when no_data_found then
				xNIF:=null;
		end;

		if xNIF is not null then
			update nada set campo2=2;

			UPDATE rus80 SET NIF=xNIF WHERE id=v_TIbi.ID;
		end if;

	END LOOP;

END;
/

EXECUTE NIF_MAL_RUSTICA;
drop PROCEDURE NIF_MAL_RUSTICA;



********************************************************************************************
********************************************************************************************
********************************************************************************************


CREATE OR REPLACE PROCEDURE modiHISTOCONTRI
AS
xNOMBRE 		CHAR(40);
xVIA 			CHAR(2);
xCALLE 		VARCHAR(30);
xNUMERO 		CHAR(5);
xESCALERA 		CHAR(2);
xPLANTA 		CHAR(3);
xPISO 		CHAR(2);
xPOBLACION 		VARCHAR(35);
xPROVINCIA 		VARCHAR(35);
xCODIGO_POSTAL 	CHAR(5);
xPAIS 		VARCHAR(35);

CURSOR CIBI IS SELECT NIF
	FROM IBI WHERE MUNICIPIO='176' AND YEAR='2001';

BEGIN

	FOR v_TIbi IN CIBI LOOP

		begin
			dbms_output.put_line(v_TIbi.NIF);
			SELECT NOMBRE,VIA,CALLE,NUMERO,ESCALERA,PLANTA,
      			PISO,POBLACION,PROVINCIA,CODIGO_POSTAL,PAIS
			INTO xNOMBRE,xVIA,xCALLE,xNUMERO,xESCALERA,xPLANTA,
      			xPISO,xPOBLACION,xPROVINCIA,xCODIGO_POSTAL,xPAIS
			FROM HDOMICONTRI WHERE NIF=v_TIbi.NIF
					and FECHA=
			(select min(fecha) FROM HDOMICONTRI WHERE NIF=v_TIbi.NIF
				and FECHA>='26/06/2001');
		exception
			when no_data_found then
				xNOMBRE:=null;
		end;

	/*	if xNOMBRE is not null then
			update contribuyentes set 
					NOMBRE=xNOMBRE,
					VIA=xVIA,
					CALLE=xCALLE,
					NUMERO=xNUMERO,
					ESCALERA=xESCALERA,
					PLANTA=xPLANTA,
	      			PISO=xPISO,
					POBLACION=xPOBLACION,
					PROVINCIA=xPROVINCIA,
					CODIGO_POSTAL=xCODIGO_POSTAL,
					PAIS=xPAIS
			where nif=v_TIbi.NIF;

			delete from HDOMICONTRI WHERE NIF=v_TIbi.NIF
					and FECHA>='26/06/2001';
		end if;
*/
	END LOOP;

END;
/


SELECT count(*),to_char(fecha,'dd/mm/yyyy HH24:MI:SS') FROM HDOMICONTRI WHERE FECHA=
			(select min(fecha) FROM HDOMICONTRI WHERE FECHA>='26/06/2001')
group by fecha having count(*)>1




--------------------------------------------------------------------------------------------
--
--
create or replace procedure ArreglaIBI
as
cursor cIBI is select id from ibi where nombre_via is null
	for update of TIPO_VIA,NOMBRE_VIA,PRIMER_NUMERO,BLOQUE,ESCALERA,PLANTA,PUERTA;
xTIPO_VIA			CHAR(5);
xNOMBRE_VIA			CHAR(25);
xPRIMER_NUMERO		CHAR(4);
xBLOQUE			CHAR(4);
xESCALERA			CHAR(2);
xPLANTA			CHAR(3);
xPUERTA			CHAR(3);
xIDHistorico		integer;
xRecibo			integer;
begin

	for vIBI in cIBI loop

		select min(id) into xIDHistorico
		from HIS_CARGOREAL_IBI where idibi=vIBI.ID;

		select TIPO_VIA,NOMBRE_VIA,PRIMER_NUMERO,BLOQUE,ESCALERA,PLANTA,PUERTA
		into xTIPO_VIA,xNOMBRE_VIA,xPRIMER_NUMERO,xBLOQUE,xESCALERA,xPLANTA,xPUERTA
		from HIS_CARGOREAL_IBI where id=xIDHistorico;

		--
		update ibi set TIPO_VIA=xTIPO_VIA,
			NOMBRE_VIA=xNOMBRE_VIA,
			PRIMER_NUMERO=xPRIMER_NUMERO,
			BLOQUE=xBLOQUE,
			ESCALERA=xESCALERA,
			PLANTA=xPLANTA,
			PUERTA=xPUERTA
		where current of cIBI;

		--
		update recibos_ibi set DOMI_TRIBUTARIO=xTIPO_VIA||' '|| xNOMBRE_VIA ||' '||
	   		  	      xPRIMER_NUMERO||' '||xBLOQUE||' '||
      	      	      xESCALERA||' '||xPLANTA||' '||xPUERTA
		where abonado=vIBI.ID
		return recibo into xRecibo;

		--
		update valores set dom_tributario=xTIPO_VIA||' '|| xNOMBRE_VIA ||' '||
	   		  	      xPRIMER_NUMERO||' '||xBLOQUE||' '||
      	      	      xESCALERA||' '||xPLANTA||' '||xPUERTA
		where ayto='148' and padron='000001' and year='2002' and tipo_de_objeto='R'
		and recibo=xRecibo and n_cargo='1122';

	end loop;

end;


