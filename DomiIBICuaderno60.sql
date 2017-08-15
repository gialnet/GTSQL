SELECT * FROM DOMIIBI2003C60

SELECT COUNT(*) FROM DOMIIBI2003C60

SELECT R.ABONADO,R.NIF,D.ENTIDAD,D.SUCURSAL,D.DC,D.CUENTA 
  FROM RECIBOS_IBI R, DOMIIBI2003C60 D
 WHERE MUNICIPIO='148' AND YEAR='2003' AND R.RECIBO=D.RECIBO
 
SELECT COUNT(*) FROM RECIBOS_IBI R, DOMIIBI2003C60 D
 WHERE MUNICIPIO='148' AND YEAR='2003' AND R.RECIBO=D.RECIBO

 
SELECT * FROM DOMIIBI2003C60 WHERE ENTIDAD NOT IN (SELECT CODIGO FROM ENTIDADES)
--1553880	15538	7482	0229	7000	81	0600742561	10300 

DELETE DOMIIBI2003C60 WHERE RECIBO=15538


BEGIN
   CARGA_DOMIIBI;
END;


SELECT R.ABONADO,R.NIF,D.ENTIDAD,D.SUCURSAL,D.DC,D.CUENTA 
  FROM RECIBOS_IBI R, DOMIIBI2003C60 D
 WHERE MUNICIPIO='148' AND YEAR='2003' AND R.RECIBO=D.RECIBO

SELECT COUNT(*) 
  FROM RECIBOS_IBI R, DOMIIBI2003C60 D
 WHERE MUNICIPIO='148' AND YEAR='2003' AND R.RECIBO=D.RECIBO

SELECT DISTINCT DOMICILIADO FROM IBI
 WHERE MUNICIPIO='148' AND YEAR='2003' AND ID IN (SELECT ABONADO FROM RECIBOS_IBI R, DOMIIBI2003C60 D
 	   				   	   			   	   	  	   WHERE MUNICIPIO='148' AND YEAR='2003' AND R.RECIBO=D.RECIBO)

SELECT COUNT(*),year,municipio FROM IBI WHERE DOMICILIADO='S' group by year,municipio

select count(*) from ibi where domiciliado='S' and year='2003' and municipio='148'												   




drop table DOMIIBI2003C60

drop procedure carga_domiibi
 

--CONSULTAS************************					
desc ibi

desc recibos_ibi

select i.nif,i.nombre,i.ref_catastral||i.numero_secuencial||i.primer_caracter_control||i.segun_caracter_control as ref_catastral,
	   i.num_fijo,i.valor_catastral,i.valor_suelo,i.valor_construccion,i.base_liquidable,
	   i.domiciliado,i.entidad||' '||i.sucursal||' '||i.dc||' '||i.cuenta as cuenta,
	   i.bonificacion,i.year_ini_boni,i.mes_ini_boni,i.year_boni,i.mes_boni,r.total as cuota 
  from ibi i join recibos_ibi r on r.abonado=i.id 
 where i.year='2003' and i.year=r.year and r.municipio='148' and i.municipio=r.municipio
order by nombre

select i.nif,i.nombre,i.ref_catastral||i.numero_secuencial||i.primer_caracter_control||i.segun_caracter_control as ref_catastral,
	   i.num_fijo,i.valor_catastral,i.valor_suelo,i.valor_construccion,i.base_liquidable,
	   i.domiciliado,i.entidad||' '||i.sucursal||' '||i.dc||' '||i.cuenta as cuenta,
	   i.bonificacion,i.year_ini_boni,i.mes_ini_boni,i.year_boni,i.mes_boni,r.total as cuota 
  from ibi i join recibos_ibi r on r.abonado=i.id 
 where i.year='2003' and i.year=r.year and r.municipio='148' and i.municipio=r.municipio
   and i.bonificacion<>0 and year_boni>='2003'
order by nombre

select count(*) from ibi where year='2003' and municipio='148' and bonificacion<>0 and year_boni>='2003'

select tipo_gravamen,bonificacion,valor_catastral,base_imponible,total from recibos_ibi where year='2003' and municipio='148' and bonificacion between 1 and 99

select nif,nombre,ref_catastral||numero_secuencial||primer_caracter_control||segun_caracter_control as ref_catastral,num_fijo,
	   valor_catastral,valor_suelo,valor_construccion,base_liquidable,domiciliado,entidad||' '||sucursal||' '||dc||' '||cuenta as cuenta,
	   bonificacion,year_ini_boni,mes_ini_boni,year_boni,mes_boni from ibi 
 where year='2003' and municipio='148' and domiciliado='S' 
order by nombre 
 
select count(*) from ibi where year='2003' and municipio='148' and domiciliado='S'

--EXENTOS 
select count(*) from ibi 
 where year='2003' and municipio='148' 
   and id not in (select abonado from recibos_ibi where year='2003' and municipio='148')



--DOMICILIACIONES NUEVAS CARGADAS 
SELECT R.NIF,R.nombre,r.recibo,r.ref_catastral,r.total as importe,d.entidad,d.sucursal,d.dc,d.cuenta as cuenta 
  FROM RECIBOS_IBI R, DOMIIBI2003C60 D
 WHERE MUNICIPIO='148' AND YEAR='2003' AND R.RECIBO=D.RECIBO and d.recibo<>15538

 
 
/**************************CARGAR DOMICILIACIONES****************************/

CREATE OR REPLACE PROCEDURE CARGA_DOMIIBI
AS
  CURSOR CRECIBI IS SELECT R.ABONADO,R.NIF,D.ENTIDAD,D.SUCURSAL,D.DC,D.CUENTA 
  		 		 	  FROM RECIBOS_IBI R, DOMIIBI2003C60 D
 					 WHERE MUNICIPIO='148' AND YEAR='2003' AND R.RECIBO=D.RECIBO;

BEGIN
   FOR vRECIBI IN cRECIBI
   LOOP
      IBI_BANCOS(vRECIBI.ABONADO,vRECIBI.ENTIDAD,vRECIBI.SUCURSAL,vRECIBI.DC,vRECIBI.CUENTA,SYSDATE,vRECIBI.NIF,'S','');
   END LOOP;
END;
/


CREATE OR REPLACE PROCEDURE AGUSTIN_ibi
AS
	
	xCODPOSTAL 	    	CHAR(5);
	xPoblacion 	    	VARCHAR2(35);
	xPROVINCIA	    	VARCHAR2(35);
	xDOMICILIO           VARCHAR2(50);

	CURSOR cCHANGE IS
      	SELECT * FROM RECIBOS_IBI WHERE NIF is null
      	for update of Domicilio,Poblacion,Provincia,Codigo_Postal;
BEGIN

	FOR vCHANGE IN cCHANGE 
	LOOP
	   
		xDomicilio:='';
		xPoblacion:='';
		xProvincia:='';
		xCodPostal:='';
	
		SELECT TIPO_VIA_FISCAL||' '|| NOMBRE_VIA_FISCAL
			||' '|| PRIMER_NUMERO_FISCAL||' '|| PRIMERA_LETRA_FISCAL
			||' '|| ESCALERA_FISCAL||' '|| PLANTA_FISCAL
			||' '|| PUERTA_FISCAL,Municipio_Fiscal,Provincia,Cod_Postal_Fiscal
		into xDomicilio,xPoblacion,xProvincia,xCodPostal
		FROM ibi WHERE ID=vCHANGE.Abonado;

		UPDATE RECIBOS_IBI SET Domicilio=xDomicilio,Poblacion=xPoblacion,Provincia=xProvincia,Codigo_Postal=xCodPostal
		WHERE current of cChange;
 
	END LOOP;
END;
/
