/* TRIGGERS DE IAE */

CREATE OR REPLACE TRIGGER T_INS_RECIBOS_IAE
BEFORE INSERT ON RECIBOS_IAE
FOR EACH ROW
BEGIN
   SELECT GENRECIBOS_IAE.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/


/********************************************************************************************/
CREATE OR REPLACE TRIGGER T_INS_CUOTAS_IAE
BEFORE INSERT ON CUOTAS_IAE
FOR EACH ROW
BEGIN
   SELECT GENCUOTAS_IAE.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/


/********************************************************************************************/
CREATE OR REPLACE TRIGGER T_INS_CALLES_IAE
BEFORE INSERT ON CALLES_IAE
FOR EACH ROW
BEGIN
   SELECT GENCALLEIAE.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/


/*******************************************************************************
MODIFICACION: 02/02/2004. Gloria Maria Calle Hernandez. 
			  Eliminada llamada a ADD_TRIBUTOS_CONTRI, pues la tabla TributosContri sobre la cual
			  insertaba pasa a rellenarse como una tabla temporal y dicho procedimiento ha sido eliminado
MODIFICACION: 04/02/2004. Gloria Maria Calle Hernandez. 
			  Eliminada llamada a ADD_DOMI_CONTRI, pues la tabla DomiContri sobre la cual
			  insertaba pasa a rellenarse como una tabla temporal y dicho procedimiento ha sido eliminado
*******************************************************************************************/
CREATE OR REPLACE TRIGGER T_ADD_IAE
BEFORE INSERT ON IAE
FOR EACH ROW
BEGIN

	SELECT GENIAE.NEXTVAL INTO :NEW.ID FROM DUAL;

	--Asignarle a esta referencia un número de recibo único
	INSERTA_REFERENCIA_BANCO(:NEW.MUNICIPIO, :NEW.YEAR, :NEW.PERIODO,
		:NEW.NIF, NULL, NULL, :NEW.REFERENCIA);
END;
/


/***************************************************************************************************
MODIFICADO: 04/02/2004. Gloria Maria Calle Hernandez. 
			Eliminada llamada a BORRADOMI, pues la tabla DomiContri sobre la cual
			borraba pasa a rellenarse como una tabla temporal y dicho procedimiento ha sido eliminado
***************************************************************************************************/
CREATE OR REPLACE TRIGGER T_DEL_IAE
BEFORE DELETE ON IAE
FOR EACH ROW
BEGIN

   DELETE FROM REFERENCIAS_BANCOS WHERE MUNICIPIO=:OLD.MUNICIPIO 
			AND YEAR=:OLD.YEAR AND PERIODO=:OLD.PERIODO 
			AND REFERENCIA_IAE=:OLD.REFERENCIA;

   DELETE FROM COTITULARES WHERE PROGRAMA='IAE' AND ID_CONCEPTO=:OLD.ID;
   
END;
/

/***************************************************************************************************
MODIFICACION: 02/02/2004. Gloria Maria Calle Hernandez. 
			  Eliminada llamada a ADD_TRIBUTOS_CONTRI y MOD_TRIBUTOS_CONTRI, pues la tabla 
			  TributosContri sobre la cual insertaba y actualizaba respectivamente, pasa a 
			  rellenarse como una tabla temporal y dicho procedimiento ha sido eliminado
MODIFICACION: 04/02/2004. Gloria Maria Calle Hernandez. 
			  Eliminada llamada a ADD_DOMI_CONTRI,MOD_DOI_CONTRI,BORRADOMI, pues la tabla DomiContri 
			  sobre la cual actuaban pasa a rellenarse como una tabla temporal y dichos procedimiento 
			  han sido eliminados
***************************************************************************************************/
-- Modificado: 01/02/2005. Lucas Fernandez Pérez. Se añade un historico de 
--	modificaciones de domiciliaciones, HISTO_DOMICILIACIONES, que suplanta
--  a los campos USR_CHG CUENTA y F_CHG_ CUENTA de la tabla de IAE.
-- Modificado: 12/06/2006 Lucas Fernández Pérez. 
-- Controla el cambio de representante para guardarlo en la tabla motivos_cambio_titularidad
--
CREATE OR REPLACE TRIGGER T_UPDATE_IAE
BEFORE UPDATE ON IAE
FOR EACH ROW
DECLARE
  xMOTIVO  VARCHAR2(512);
  xTEXTO	  VARCHAR2(512);
BEGIN

	-- si ha habido algún cambio en los datos de domiciliación, indicar el usuario que 
	-- lo realiza y la fecha
	IF ((:NEW.DOMICILIADO<>:OLD.DOMICILIADO) OR (trunc(:NEW.F_DOMICILIACION,'dd')<>trunc(:OLD.F_DOMICILIACION,'dd')) OR 
   	       (:NEW.ENTIDAD<>:OLD.ENTIDAD) OR (:NEW.SUCURSAL<>:OLD.SUCURSAL) OR 
           (:NEW.DC<>:OLD.DC) OR (:NEW.CUENTA<>:OLD.CUENTA) OR 
           (:NEW.DNI_FACTURA<>:OLD.DNI_FACTURA)) THEN
		
        SELECT TEXTO2 INTO xMOTIVO FROM USUARIOSGT WHERE USUARIO=USER;
		
        INSERT INTO HISTO_DOMICILIACIONES
          (IDPROGRAMA, PROGRAMA, MOTIVO, DOMICILIADO, F_DOMICILIACION,
           NIF_TITULAR, ENTIDAD, SUCURSAL, DC, CUENTA)
        VALUES
          (:OLD.ID, 'IAE',xMOTIVO, :OLD.DOMICILIADO, :OLD.F_DOMICILIACION,
           :OLD.DNI_FACTURA, :OLD.ENTIDAD, :OLD.SUCURSAL, :OLD.DC, :OLD.CUENTA);
	END IF;

	-- cambio del representante
	IF (:NEW.REPRESENTANTE<>:OLD.REPRESENTANTE)
		OR (:NEW.REPRESENTANTE IS NULL AND :OLD.REPRESENTANTE IS NOT NULL)
		OR (:NEW.REPRESENTANTE IS NOT NULL AND :OLD.REPRESENTANTE IS NULL)
		THEN
		SELECT TEXTO INTO xTEXTO FROM USUARIOSGT WHERE USUARIO=USER;
		INSERT INTO MOTIVOS_CAMBIO_TITULARIDAD
			(IDCAMBIO,PROGRAMA,NIF,TIPO_TITULAR,MOTIVO)
		VALUES
			(:NEW.ID,'IAE',:OLD.REPRESENTANTE,'R',xTEXTO);
	END IF;

END;
/


/********************************************************************************
MODIFICACIÓN: 13/01/2003 Mª Carmen Junco Gómez. Sólo se ha de actualizar el 
			  contador del concepto si el año del padrón es igual al año de trabajo.
Modificado: 10/09/2003. Agustín Léon Robles. Cuando sean recibos del padron no hay
				que borrar en la tabla de liquidaciones
********************************************************************************/
CREATE OR REPLACE TRIGGER DEL_RECIBOS_IAE
AFTER DELETE ON RECIBOS_IAE FOR EACH ROW
DECLARE
  xCONCEP CHAR(6);
  xCONTADOR INTEGER;
  xYEARWORK CHAR(4);
BEGIN


if :OLD.PERIODO<>'00' then

   SELECT LIQUIDACION INTO xCONCEP FROM PROGRAMAS 
   WHERE PROGRAMA='IAE';
   
   SELECT YEARWORK INTO xYEARWORK FROM DATOSPER WHERE MUNICIPIO=:OLD.MUNICIPIO;   
   
   SELECT COUNT(*) INTO xCONTADOR FROM LIQUIDACIONES
   WHERE CONCEPTO=xCONCEP AND MUNICIPIO=:OLD.MUNICIPIO AND YEAR=:OLD.YEAR 
   		 AND PERIODO=:OLD.PERIODO;

   IF (xCONTADOR > 0) THEN    

      DELETE FROM LIQUIDACIONES WHERE CONCEPTO=xCONCEP AND MUNICIPIO=:OLD.MUNICIPIO AND 
 			      YEAR=:OLD.YEAR AND PERIODO=:OLD.PERIODO AND TO_NUMBER(NUMERO)=:OLD.RECIBO;
 			      
      IF xYEARWORK=:OLD.YEAR THEN   
         SELECT COUNT(*) INTO xCONTADOR FROM LIQUIDACIONES 
         WHERE CONCEPTO=xCONCEP AND MUNICIPIO=:OLD.MUNICIPIO;

         UPDATE CONTADOR_CONCEPTOS SET CONTADOR=xCONTADOR WHERE CONCEPTO=xCONCEP AND 
                MUNICIPIO=:OLD.MUNICIPIO;
      END IF;
   END IF;

end if;   
   
   DELETE FROM LOGSPADRONES 
   WHERE MUNICIPIO=:OLD.MUNICIPIO AND PROGRAMA='IAE' AND
     	 PYEAR=:OLD.YEAR AND PERIODO=:OLD.PERIODO AND 
		 HECHO='Se Genera un Padrón';			   

END;
/

/************************************************************************************/
COMMIT;
/************************************************************************************/
